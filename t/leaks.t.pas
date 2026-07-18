program Leaks;

{$mode objfpc}{$H+}{$J-}

uses TAP, PerlEmbed;

{ This sets up non-cleaning perl interpreter, which allows valgrind leak check
  and other software to see leaked scalars. It also serves as a nice test for a
  sub with three arguments }

{ TODO: make checking for leaked memory automatic (avoid needing valgrind) }

var
	Perl: TPerlHandle;
	SubResult: TPerlSV;
begin
	Perl := TPerlHandle.Create;

	try
		Perl.RunCode('sub test_substr { return $_[0] =~ s{\Q$_[1]\E}{$_[2]}rg; }');
		SubResult := Perl.CallSub(
			'test_substr',
			[
				Perl.StringToScalar('footender fooman'),
				Perl.StringToScalar('foo'),
				Perl.StringToScalar('bar')
			]
		);

		TestIs(Perl.ScalarToString(SubResult), 'bartender barman', 'leak test return value ok');
	finally
		Perl.Free;
	end;

	DoneTesting;
end.

