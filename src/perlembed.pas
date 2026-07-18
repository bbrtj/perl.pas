unit PerlEmbed;

{$mode objfpc}{$H+}{$J-}

interface

uses
	ctypes, SysUtils;

type
	TPerlInterpreter = Pointer;
	PPChar = ^PChar;
	TPerlSV = Pointer;
	TPerlIV = clong;
	TPerlNV = cdouble;
	TPerlPV = PChar;
	PPerlSV = ^TPerlSV;
	TPerlStrLen = csize_t;
	PPerlStrLen = ^TPerlStrLen;

	EPerl = class(Exception);
	EPerlCallFailed = class(EPerl);

	TPerlHandle = class
	strict private class var
		FInterpreterCount: Integer;
	strict private var
		FPerl: TPerlInterpreter;
	public
		constructor Create(); virtual;
		destructor Destroy; override;
	public
		function ScalarDefined(Value: TPerlSV): Boolean;
		function ScalarTrue(Value: TPerlSV): Boolean;
		function ScalarToFloat(Value: TPerlSV): Double;
		function ScalarToString(Value: TPerlSV): String;
		function ScalarToInt(Value: TPerlSV): Int64;
		function FloatToScalar(Value: Double): TPerlSV;
		function IntToScalar(Value: Int64): TPerlSV;
		function StringToScalar(const Value: String): TPerlSV;
	public
		function RunCode(const Code: String): TPerlSV;
		function CallSub(const Name: String; const Args: Array of TPerlSV): TPerlSV;
		function EvalSub(const Name: String; const Args: Array of TPerlSV): TPerlSV;
		function EvalError(): TPerlSV;
		function EvalSuccess(): Boolean;
	end;

{ Perl C API functions }
function perl_alloc(): TPerlInterpreter; cdecl; external 'perl';
procedure perl_construct(interp: TPerlInterpreter); cdecl; external 'perl';
function perl_parse(interp: TPerlInterpreter;
	xsinit: Pointer; argc: cint; argv: PPChar; env: PPChar): cint; cdecl; external 'perl';
function perl_run(interp: TPerlInterpreter): cint; cdecl; external 'perl';
procedure perl_destruct(interp: TPerlInterpreter); cdecl; external 'perl';
procedure perl_free(interp: TPerlInterpreter); cdecl; external 'perl';
function Perl_eval_pv(code: PChar; croak_on_error: cint): TPerlSV; cdecl; external 'perl';
function Perl_newSVnv(Nv: TPerlNV): TPerlSV; cdecl; external 'perl';
function Perl_newSViv(Iv: TPerlIV): TPerlSV; cdecl; external 'perl';
function Perl_newSVpv(Pv: TPerlPV; Len: TPerlStrLen): TPerlSV; cdecl; external 'perl';

{ Our wrapper functions }
procedure xs_init(interp: TPerlInterpreter); cdecl; external;
function call_perl_sub(sub_name: PChar; args: PPerlSV; arg_count: cint): TPerlSV; cdecl; external;
function do_SvPV(Sv: TPerlSV; Len: PPerlStrLen): TPerlPV; cdecl; external;
function do_SvNV(Sv: TPerlSV): TPerlNV; cdecl; external;
function do_SvIV(Sv: TPerlSV): TPerlIV; cdecl; external;
function do_SvOK(Sv: TPerlSV): cint; cdecl; external;
function do_SvTRUE(Sv: TPerlSV): cint; cdecl; external;
function do_ERRSV(): TPerlSV; cdecl; external;

implementation

{$link perlwrapper}

constructor TPerlHandle.Create();
var
	Argv: Array[0..3] of PChar;
begin
	if FInterpreterCount > 0 then
		raise EPerl.Create('Only one perl interpreter can be allocated at once');

	FPerl := perl_alloc;
	perl_construct(FPerl);

	Argv[0] := '';
	Argv[1] := '-e';
	Argv[2] := '0';
	Argv[3] := nil;

	{ Parse and initialize Perl }
	if perl_parse(FPerl, @xs_init, High(Argv), @Argv, nil) <> 0 then
		raise EPerl.Create('Failed to initialize Perl interpreter');

	if perl_run(FPerl) <> 0 then
		raise EPerl.Create('Failed to run Perl interpreter');

	FInterpreterCount += 1;
end;

destructor TPerlHandle.Destroy();
begin
	if FPerl <> nil then begin
		perl_destruct(FPerl);
		perl_free(FPerl);

		FInterpreterCount -= 1;
	end;
end;

function TPerlHandle.ScalarDefined(Value: TPerlSV): Boolean;
begin
	result := do_SvOK(Value) <> 0;
end;

function TPerlHandle.ScalarTrue(Value: TPerlSV): Boolean;
begin
	result := do_SvTRUE(Value) <> 0;
end;

function TPerlHandle.ScalarToFloat(Value: TPerlSV): Double;
begin
	result := do_SvNV(Value);
end;

function TPerlHandle.ScalarToString(Value: TPerlSV): String;
var
	LLen: TPerlStrLen;
begin
	result := do_SvPV(Value, @LLen);
	// TODO: result should have LLen
end;

function TPerlHandle.ScalarToInt(Value: TPerlSV): Int64;
begin
	result := do_SvIV(Value);
end;

function TPerlHandle.FloatToScalar(Value: Double): TPerlSV;
begin
	result := Perl_newSVnv(Value);
	// TODO: store the scalar to destroy it later
end;

function TPerlHandle.IntToScalar(Value: Int64): TPerlSV;
begin
	result := Perl_newSViv(Value);
	// TODO: store the scalar to destroy it later
end;

function TPerlHandle.StringToScalar(const Value: String): TPerlSV;
begin
	result := Perl_newSVpv(PChar(Value), 0);
	// TODO: store the scalar to destroy it later
end;

function TPerlHandle.RunCode(const Code: String): TPerlSV;
begin
	result := Perl_eval_pv(TPerlPV(Code), 0);
end;

function TPerlHandle.CallSub(const Name: String; const Args: Array of TPerlSV): TPerlSV;
begin
	result := self.EvalSub(Name, Args);
	if not self.EvalSuccess then
		raise EPerlCallFailed.Create(
			Format(
				'calling %s failed: %s',
				[Name, self.ScalarToString(self.EvalError)]
			)
		);
end;

function TPerlHandle.EvalSub(const Name: String; const Args: Array of TPerlSV): TPerlSV;
begin
	result := call_perl_sub(PChar(Name), @Args, length(Args));
end;

function TPerlHandle.EvalError(): TPerlSV;
begin
	result := do_ERRSV;
end;

function TPerlHandle.EvalSuccess(): Boolean;
begin
	result := not self.ScalarTrue(self.EvalError);
end;

end.

