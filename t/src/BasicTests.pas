{
	Tests basic behavior of the perl interpreter
}
unit BasicTests;

{$mode objfpc}{$H+}{$J-}

interface

uses TAPSuite, TAP, PerlEmbed;

type
	TBasicSuite = class(TTAPSuite, ITAPSuiteEssential)
		constructor Create(); override;

		procedure EvalTest();
		procedure CallErrorTest();
		procedure CallTest();
	end;

implementation

constructor TBasicSuite.Create();
begin
	inherited;
	Scenario(@self.EvalTest, 'Perl code evaluation tests');
	Scenario(@self.CallErrorTest, 'Calling Perl sub with exception tests');
	Scenario(@self.CallTest, 'Calling Perl sub from Pascal tests');
end;

procedure TBasicSuite.EvalTest();
var
	Perl: TPerlContext;
	EvalResult: TPerlSV;
begin
	Perl := TPerlContext.Create;

	try
		TestIs(Perl.EvalSuccess, true, 'no eval error with clean interpreter ok');
		if not Perl.EvalSuccess then
			Diag('eval error with clean interpreter: ' + Perl.ScalarToString(Perl.EvalError));

		EvalResult := Perl.RunCode('2 + 2');
		TestIs(Perl.ScalarToInt(EvalResult), 4, 'very basic eval ok');

		EvalResult := Perl.RunCode('die "bailing out\n"');
		TestIs(Perl.ScalarDefined(EvalResult), false, 'exception returning undef ok');
		TestIs(Perl.EvalSuccess, false, 'exception defined ok');
		TestIs(Perl.ScalarToString(Perl.EvalError), 'bailing out' + sLineBreak, 'exception text ok');

		// TODO: check refcounting and memory state (avoid leaks)
	finally
		Perl.Free;
	end;
end;

procedure TBasicSuite.CallTest();
const
	CSmallPrecision = 1E-8;
var
	Perl: TPerlContext;
	SubResult: TPerlSV;
begin
	Perl := TPerlContext.Create;

	try
		Perl.RunCode('sub test_int { return shift() + 1 }');
		SubResult := Perl.CallSub('test_int', [Perl.IntToScalar(41)]);
		TestIs(Perl.ScalarToInt(SubResult), 42, 'integer test ok');

		Perl.RunCode('sub test_float { return shift() / 2 }');
		SubResult := Perl.CallSub('test_float', [Perl.FloatToScalar(7)]);
		TestWithin(Perl.ScalarToFloat(SubResult), 3.5, CSmallPrecision, 'float test ok');

		Perl.RunCode('sub test_string { return ucfirst(shift() . "!") }');
		SubResult := Perl.CallSub('test_string', [Perl.StringToScalar('perl rocks')]);
		TestIs(Perl.ScalarToString(SubResult), 'Perl rocks!', 'string test ok');
	finally
		Perl.Free;
	end;
end;

procedure TBasicSuite.CallErrorTest();
var
	Perl: TPerlContext;
	SubResult: TPerlSV;
begin
	Perl := TPerlContext.Create;

	try
		Perl.RunCode('sub test_exception { die "ex\n" }');

		SubResult := Perl.EvalSub('test_exception', []);
		TestIs(Perl.ScalarDefined(SubResult), false, 'result undefined ok');
		TestIs(Perl.EvalSuccess, false, 'got exception ok');
		TestIs(Perl.ScalarToString(Perl.EvalError), 'ex' + sLineBreak, 'perl exception text ok');

		try
			Perl.CallSub('test_exception', []);
			TestFail('called sub with perl exception and no pascal exception was raised');
		except
			on E: EPerlCallFailed do
				TestIs(E.Message, 'calling test_exception failed: ex' + sLineBreak, 'pascal exception text ok');
		end;
	finally
		Perl.Free;
	end;
end;

end.

