{
	Tests whether the interpreter can read the source from the lib directory
}
unit LibTests;

{$mode objfpc}{$H+}{$J-}

interface

uses TAPSuite, TAP, PerlEmbed;

type
	TLibSuite = class(TTAPSuite)
		constructor Create(); override;

		procedure BadLibTest();
		procedure StringManipulatorTest();
	end;

implementation

constructor TLibSuite.Create();
begin
	inherited;
	Scenario(@self.BadLibTest, 'Incorrect library usage tests');
	Scenario(@self.StringManipulatorTest, 'StringUtil example tests');
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

procedure TLibSuite.StringManipulatorTest();
var
	Perl: TPerlHandle;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create(true);

	try
		Perl.RunCode('use lib ''t/lib''; use StringManipulator;');

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

end.

