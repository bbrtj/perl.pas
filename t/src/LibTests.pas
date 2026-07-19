{
	Tests whether the interpreter can read the source from the lib directory
}
unit LibTests;

{$mode objfpc}{$H+}{$J-}

interface

uses TAPSuite, TAP, PerlEmbed, ObjectWrapper;

type
	TLibSuite = class(TTAPSuite)
		constructor Create(); override;

		procedure BadLibTest();
		procedure MultiplierTest();
		procedure StringManipulatorTest();
		procedure StringUtilTest();
		procedure StringUtilWrappedTest();
	end;

implementation

constructor TLibSuite.Create();
begin
	inherited;
	Scenario(@self.BadLibTest, 'Incorrect library usage tests');
	Scenario(@self.MultiplierTest, 'multiplier script tests');
	Scenario(@self.StringManipulatorTest, 'StringManipulator library tests');
	Scenario(@self.StringUtilTest, 'StringUtil library tests');
	Scenario(@self.StringUtilWrappedTest, 'StringUtil wrapped library tests');
end;

procedure TLibSuite.BadLibTest();
var
	Perl: TPerlHandle;
begin
	Perl := TPerlHandle.Create(true);

	try
		try
			Perl.RunCode('use NoSuchLibrary;');
			TestFail('Library used with no @INC entry paths');
		except
			on E: EPerlEvalFailed do
				TestPass('Library use failed ok');
		end;
	finally
		Perl.Free;
	end;
end;

procedure TLibSuite.MultiplierTest();
const
	CSmallPrecision = 1E-8;
var
	Perl: TPerlHandle;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create(['t/lib/multiplier.pl'], true);

	try
		SubResult := Perl.CallSub('multiply', [Perl.FloatToScalar(2.6), Perl.FloatToScalar(4)]);
		TestWithin(Perl.ScalarToFloat(SubResult), 10.4, CSmallPrecision, 'multiply ok');
	finally
		Perl.Free;
	end;
end;

procedure TLibSuite.StringManipulatorTest();
var
	Perl: TPerlHandle;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create(['-It/lib', '-e0'], true);

	try
		Perl.RunCode('use StringManipulator;');

		Perl.CallSub('StringManipulator::start', []);
		SubResult := Perl.CallSub('StringManipulator::append', [Perl.StringToScalar('123456abc789def0')]);
		TestIs(Perl.ScalarToString(SubResult), '123456abc789def0', 'append ok');

		SubResult := Perl.CallSub('StringManipulator::replace', [Perl.StringToScalar('\d'), Perl.StringToScalar('N')]);
		TestIs(Perl.ScalarToString(SubResult), 'NNNNNNabcNNNdefN', 'replace ok');

		SubResult := Perl.CallSub('StringManipulator::append', [Perl.StringToScalar('?')]);
		TestIs(Perl.ScalarToString(SubResult), 'NNNNNNabcNNNdefN?', 'append ok');

		Perl.CallSub('StringManipulator::start', []);
		SubResult := Perl.CallSub('StringManipulator::append', [Perl.StringToScalar('??')]);
		TestIs(Perl.ScalarToString(SubResult), '??', 'restart ok');
	finally
		Perl.Free;
	end;
end;

procedure TLibSuite.StringUtilTest();
var
	Perl: TPerlHandle;
	Obj: TPerlSv;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create(['-It/lib', '-MStringManipulator::StringUtil', '-e0'], true);

	try
		Obj := Perl.CallMethod(Perl.StringToScalar('StringManipulator::StringUtil'), 'new', []);
		Perl.CallMethod(Obj, 'append', [Perl.StringToScalar('123456abc789def0')]);
		Perl.CallMethod(Obj, 'replace', [Perl.StringToScalar('\d'), Perl.StringToScalar('N')]);
		Perl.CallMethod(Obj, 'append', [Perl.StringToScalar('?')]);

		SubResult := Perl.CallMethod(Obj, 'get', []);
		TestIs(Perl.ScalarToString(SubResult), 'NNNNNNabcNNNdefN?', 'result ok');
	finally
		Perl.Free;
	end;
end;

procedure TLibSuite.StringUtilWrappedTest();
var
	Obj: TStringUtil;
begin
	ObjectWrapperPerl := TPerlHandle.Create(['-It/lib', '-MStringManipulator::StringUtil', '-e0'], true);

	try
		Obj := TStringUtil.Create;
		Obj.AppendString('123456abc789def0');
		Obj.ReplaceString('\d', 'N');
		Obj.AppendString('?');

		TestIs(Obj.GetString, 'NNNNNNabcNNNdefN?', 'result ok');
	finally
		Obj.Free;
		ObjectWrapperPerl.Free;
	end;
end;

end.

