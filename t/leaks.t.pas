program Leaks;

{$mode objfpc}{$H+}{$J-}

uses TAP, PerlEmbed, ObjectWrapper;

{ This sets up non-cleaning perl interpreter, which allows valgrind leak check
  and other software to see leaked scalars. It also serves as a nice test for a
  sub with three arguments }

{ TODO: make checking for leaked memory automatic (avoid needing valgrind) }

var
	Obj: TStringUtil;
begin
	ObjectWrapperPerl := TPerlHandle.Create(['-It/lib', '-MStringManipulator::StringUtil', '-e0']);

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

	DoneTesting;
end.

