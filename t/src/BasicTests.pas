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

		procedure AllocationTest();
		procedure EvalTest();
		procedure CallErrorTest();
		procedure CallTest();
		procedure ContextUseTest();
		procedure ContextFreeTest();
	end;

implementation

constructor TBasicSuite.Create();
begin
	inherited;
	Scenario(@self.AllocationTest, 'Perl interpreter creation tests');
	Scenario(@self.EvalTest, 'Perl code evaluation tests');
	Scenario(@self.CallErrorTest, 'Calling Perl sub with exception tests');
	Scenario(@self.CallTest, 'Calling Perl sub from Pascal tests');
	Scenario(@self.ContextUseTest, 'Perl context using tests');
	Scenario(@self.ContextFreeTest, 'Perl scalar freeing tests');
end;

procedure TBasicSuite.AllocationTest();
var
	Perl1, Perl2: TPerlHandle;
begin
	Perl1 := TPerlHandle.Create;
	TestPass('Perl interpreter created ok');

	try
		Perl2 := TPerlHandle.Create;
		TestFail('Second perl interpreter created even though this is an error');
		Perl2.Free;
	except
		on E: EPerl do
			TestIs(E.Message, 'Only one perl interpreter can be allocated at once', 'second interpreter error ok');
	end;

	Perl1.Free;
	Perl2 := TPerlHandle.Create;
	TestPass('Second perl interpreter created after first one is freed ok');
	Perl2.Free;
end;

procedure TBasicSuite.EvalTest();
var
	Perl: TPerlHandle;
	EvalResult: TPerlSV;
begin
	Perl := TPerlHandle.Create;

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
	finally
		Perl.Free;
	end;
end;

procedure TBasicSuite.CallTest();
const
	CSmallPrecision = 1E-8;
var
	Perl: TPerlHandle;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create;

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
	Perl: TPerlHandle;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create;

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

procedure TBasicSuite.ContextUseTest();
var
	Perl: TPerlHandle;
	I: Integer;
begin
	Perl := TPerlHandle.Create;

	try
		try
			Perl.LeaveContext;
			TestFail('bare context leave did not raise an exception');
		except
			on E: EPerlContext do
				TestIs(E.Message, 'Attempt to leave Perl context without entering it first', 'exception ok');
		end;

		try
			for I := 0 to CMaxPerlContextDepth do
				Perl.EnterContext;

			TestFail('deep context enter did not raise an exception');
		except
			on E: EPerlContext do
				TestIs(E.Message, 'Perl max context pool is depleted', 'exception ok');
		end;

		{ try leaving the context now - an exception will bailout the test }
		Perl.LeaveContext;
	finally
		Perl.Free;
	end;
end;

procedure TBasicSuite.ContextFreeTest();
var
	Perl: TPerlHandle;
	Value1, Value2, Value3: TPerlSv;
begin
	Perl := TPerlHandle.Create;

	try
		Value1 := Perl.IntToScalar(42);
		TestIs(Perl.ScalarDefined(Value1), true, 'value before context ok');

		{ context 1 begin }
		Perl.EnterContext;

		Value2 := Perl.IntToScalar(42);
		TestIs(Perl.ScalarDefined(Value2), true, 'value in context 1 ok');

		{ context 2 begin }
		Perl.EnterContext;

		Value3 := Perl.IntToScalar(42);
		TestIs(Perl.ScalarDefined(Value3), true, 'value in context 2 ok');

		{ context 2 end }
		Perl.LeaveContext;

		TestIs(Perl.ScalarDefined(Value2), true, 'value in context 1 not freed ok');
		TestIs(Perl.ScalarDefined(Value3), false, 'value in context 2 freed ok');

		{ context 1 end }
		Perl.LeaveContext;

		TestIs(Perl.ScalarDefined(Value1), true, 'value before context not freed ok');
		TestIs(Perl.ScalarDefined(Value2), false, 'value in context 1 freed ok');
	finally
		Perl.Free;
	end;
end;

end.

