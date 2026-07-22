{
	Tests whether it's possible to wrap perl and pascal object to be used
	natively in both languages
}
unit WrapperTests;

{$mode objfpc}{$H+}{$J-}

interface

uses TAPSuite, TAP, PerlEmbed, PerlObjectLayer, ObjectWrappers;

type
	TWrapperSuite = class(TTAPSuite)
		constructor Create(); override;

		procedure PerlWrapperTest();
		procedure PerlWrapperFromPerlTest();
		procedure PascalWrapperTest();
		procedure PascalWrapperBadMethodTest();
	end;

implementation

constructor TWrapperSuite.Create();
begin
	inherited;
	Scenario(@self.PerlWrapperTest, 'Wrapped Perl object tests');
	Scenario(@self.PerlWrapperFromPerlTest, 'Wrapped Perl object obtained from Perl tests');
	Scenario(@self.PascalWrapperTest, 'Wrapped Pascal object tests');
	Scenario(@self.PascalWrapperBadMethodTest, 'Wrapped Pascal bad method call tests');
end;

const
	CSmallPrecision = 1E-8;

procedure TWrapperSuite.PerlWrapperTest();
var
	Obj: TPerlCalculator;
begin
	ObjectWrappersPerl := TDynaLoaderPerl.Create(['-It/lib', '-MCalculator', '-e0'], true);

	try
		Obj := TPerlCalculator.Create;
		Obj.Add(15.3);
		Obj.Divide(3);
		Obj.Multiply(2.5);
		Obj.Subtract(5);

		TestWithin(Obj.GetValue, 7.75, CSmallPrecision, 'result ok');
	finally
		Obj.Free;
		ObjectWrappersPerl.Free;
	end;
end;

procedure TWrapperSuite.PerlWrapperFromPerlTest();
var
	Obj: TPerlCalculator;
begin
	ObjectWrappersPerl := TDynaLoaderPerl.Create(['-Isite/blib/lib', '-Isite/blib/arch', '-It/lib', 't/lib/test_calculator.pl'], true);

	try
		Obj := TPerlCalculator.CreateFromSV(ObjectWrappersPerl.CallSub('get_perl_calculator', []));

		TestWithin(Obj.GetValue, 20, CSmallPrecision, 'result ok');
	finally
		Obj.Free;
		ObjectWrappersPerl.Free;
	end;
end;

procedure TWrapperSuite.PascalWrapperTest();
var
	TestResult: TPerlSV;
begin
	ObjectWrappersPerl := TDynaLoaderPerl.Create(['-Isite/blib/lib', '-Isite/blib/arch', '-It/lib', 't/lib/test_calculator.pl'], true);

	try
		TestResult := ObjectWrappersPerl.CallSub('run_calculation', []);

		TestWithin(ObjectWrappersPerl.ScalarToFloat(TestResult), 7.75, CSmallPrecision, 'result ok');
	finally
		ObjectWrappersPerl.Free;
	end;
end;

procedure TWrapperSuite.PascalWrapperBadMethodTest();
begin
	ObjectWrappersPerl := TDynaLoaderPerl.Create(['-Isite/blib/lib', '-Isite/blib/arch', '-It/lib', 't/lib/test_calculator.pl'], true);

	try try
		ObjectWrappersPerl.CallSub('run_exception', []);
		TestFail('calling function which causes exception succeeded');
	except
		on E: EPerlCallFailed do
			TestIs(
				E.Message,
				'calling run_exception failed: Failed to call pascal method UNKNOWN: No such method'
					+ ' at site/blib/lib/PascalObject.pm line 18.' + sLineBreak,
				'exception ok'
			);
	end;
	finally
		ObjectWrappersPerl.Free;
	end;
end;

end.

