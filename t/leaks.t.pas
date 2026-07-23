program Leaks;

{$mode objfpc}{$H+}{$J-}

uses TAP, PerlEmbed, PerlObjectLayer, ObjectWrappers;

{ This sets up non-cleaning perl interpreter, which allows valgrind leak check
  and other software to see leaked scalars. It also serves as a nice test for a
  sub with three arguments }

{ TODO: make checking for leaked memory automatic (avoid needing valgrind) }

var
	Obj: TPerlCalculator;
begin
	WrappersPerl := TDynaLoaderPerl.Create(['-Isite/blib/lib', '-Isite/blib/arch', '-It/lib', '-MCalculator', 't/lib/test_calculator.pl']);

	try
		Obj := TPerlCalculator.Create;
		Obj.Add(0.01);

		TestWithin(Obj.GetValue, 0.01, 1E-4, 'perl result ok');
		TestWithin(
			WrappersPerl.ScalarToFloat(WrappersPerl.CallSub('run_calculation', [])),
			7.75,
			1E-4,
			'pascal result ok'
		);
	finally
		Obj.Free;
		WrappersPerl.Free;
	end;

	DoneTesting;
end.

