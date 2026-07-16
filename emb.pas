program EmbedPerl;

{$mode objfpc}{$H+}{$J-}

uses PerlEmbed;

type
	TMyPerl = class(TPerlContext)
	public
		constructor Create(); override;
	public
		function GetCircleArea(Radius: Single): Single;
		function MockPascal(const Txt: String): String;
	end;

{ implementation }

constructor TMyPerl.Create();
begin
	inherited;

	self.RunCode(
		'use v5.40;' +
		'sub circle_area ($r) { return 3.14159 * $r ** 2; }' +
		'sub mock_pascal ($str) { return $str =~ s{pascal}{Perl}rig; }'
	);
end;

function TMyPerl.GetCircleArea(Radius: Single): Single;
begin
	result := self.ScalarToFloat(
		self.CallMethod('circle_area', [self.FloatToScalar(Radius)])
	);
end;

function TMyPerl.MockPascal(const Txt: String): String;
begin
	result := self.ScalarToString(
		self.CallMethod('mock_pascal', [self.StringToScalar(Txt)])
	);
end;

{ implementation end }

var
	Perl: TMyPerl;
begin
	Perl := TMyPerl.Create;
	try
		writeln(Perl.GetCircleArea(10));
		writeln(Perl.MockPascal('pascal is a nice language'));
	finally
		Perl.Free;
	end;
end.

