unit PerlEmbed;

{$mode objfpc}{$H+}{$J-}

interface

uses
	Ctypes, SysUtils, Math;

const
	CMaxPerlContextDepth = 20;

type
	TPerlInterpreter = Pointer;

	PPChar = ^PChar;

	TPerlSV = Pointer;
	PPerlSV = ^TPerlSV;

	TPerlIV = clong;
	TPerlNV = cdouble;
	TPerlPV = PChar;

	TPerlStrLen = csize_t;
	PPerlStrLen = ^TPerlStrLen;

	EPerl = class(Exception);
	EPerlContext = class(Exception);
	EPerlEvalFailed = class(EPerl);
	EPerlCallFailed = class(EPerl);

	TPerlHandle = class
	private class var
		FInterpreterCount: Integer;
	strict private var
		FPerl: TPerlInterpreter;
		FPerlVars: Array of TPerlSV;
		FPerlVarsCapacity: Integer;
		FPerlVarsLastIndex: Integer;
		FPerlVarsMarks: Array[0 .. CMaxPerlContextDepth - 1] of Integer;
	strict private
		procedure AdoptScalar(Value: TPerlSV);
		procedure DisownScalars(Mark: Integer = 0);
	public
		constructor Create(Cleanup: Boolean = false);
		constructor Create(Args: Array of String; Cleanup: Boolean = false);
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
		procedure EnterContext();
		procedure LeaveContext();
	public
		function RunCode(const Code: String; ExceptionOnError: Boolean = true): TPerlSV;
		function CallSub(const Name: String; const Args: Array of TPerlSV; ExceptionOnError: Boolean = true): TPerlSV;
		function EvalError(): TPerlSV;
		function EvalSuccess(): Boolean;
	end;

{ Perl C API functions }
function perl_alloc(): TPerlInterpreter; cdecl; external 'perl';
procedure perl_construct(Interp: TPerlInterpreter); cdecl; external 'perl';
function perl_parse(Interp: TPerlInterpreter;
	XsInit: Pointer; Argc: cint; Argv: PPChar; Env: PPChar): cint; cdecl; external 'perl';
function perl_run(Interp: TPerlInterpreter): cint; cdecl; external 'perl';
procedure perl_destruct(Interp: TPerlInterpreter); cdecl; external 'perl';
procedure perl_free(Interp: TPerlInterpreter); cdecl; external 'perl';
function Perl_eval_pv(Code: PChar; CroakOnError: cint): TPerlSV; cdecl; external 'perl';
function Perl_newSVnv(Nv: TPerlNV): TPerlSV; cdecl; external 'perl';
function Perl_newSViv(Iv: TPerlIV): TPerlSV; cdecl; external 'perl';
function Perl_newSVpv(Pv: TPerlPV; Len: TPerlStrLen): TPerlSV; cdecl; external 'perl';

{ Our wrapper functions }
procedure xs_init(Interp: TPerlInterpreter); cdecl; external;
procedure setup_flags(DestructLevel: cint); cdecl; external;
function call_perl_sub(SubName: PChar; Args: PPerlSV; ArgCount: cint): TPerlSV; cdecl; external;
procedure do_PERL_SYS_INIT3(Argc: cint; Argv: PPChar; Env: PPChar); cdecl; external;
procedure do_PERL_SYS_TERM(); cdecl; external;
function do_SvPV(Sv: TPerlSV; Len: PPerlStrLen): TPerlPV; cdecl; external;
function do_SvNV(Sv: TPerlSV): TPerlNV; cdecl; external;
function do_SvIV(Sv: TPerlSV): TPerlIV; cdecl; external;
function do_SvOK(Sv: TPerlSV): cint; cdecl; external;
function do_SvTRUE(Sv: TPerlSV): cint; cdecl; external;
function do_ERRSV(): TPerlSV; cdecl; external;
procedure do_SVREFCNT_dec(Sv: TPerlSV); cdecl; external;

implementation

{$link perlwrapper}

procedure TPerlHandle.AdoptScalar(Value: TPerlSV);
const
	CStartCapacity = 10;
	CCapacityGrowthRate = 1.5;
begin
	Inc(FPerlVarsLastIndex);
	if FPerlVarsLastIndex >= FPerlVarsCapacity then	begin
		FPerlVarsCapacity := Max(CStartCapacity, Floor(FPerlVarsCapacity * CCapacityGrowthRate));
		SetLength(FPerlVars, FPerlVarsCapacity);
	end;

	{ NOTE: scalar should already have an increased refcount }
	FPerlVars[FPerlVarsLastIndex] := Value;
end;

procedure TPerlHandle.DisownScalars(Mark: Integer = 0);
begin
	while FPerlVarsLastIndex >= Mark do begin
		do_SVREFCNT_dec(FPerlVars[FPerlVarsLastIndex]);
		Dec(FPerlVarsLastIndex);
	end;
end;

constructor TPerlHandle.Create(Args: Array of String; Cleanup: Boolean = false);
var
	I: Integer;
	Argv: Array of PChar;
begin
	{ NOTE: need to be done early for the destructor to work properly }
	FPerlVarsLastIndex := -1;

	for I := low(FPerlVarsMarks) to high(FPerlVarsMarks) do
		FPerlVarsMarks[I] := -1;

	if FInterpreterCount > 0 then
		raise EPerl.Create('Only one perl interpreter can be allocated at once');

	FPerl := perl_alloc;
	perl_construct(FPerl);
	setup_flags(IfThen(Cleanup, 1, 0));

	SetLength(Argv, length(Args) + 2);
	for I := 0 to high(Args) do
		Argv[I + 1] := PChar(Args[I]);

	{ mandatory for the interpreter to work }
	Argv[0] := '';
	Argv[high(Argv)] := nil;

	{ Parse and initialize Perl }
	if perl_parse(FPerl, @xs_init, high(Argv), @Argv[0], nil) <> 0 then
		raise EPerl.Create('Failed to initialize Perl interpreter');

	if perl_run(FPerl) <> 0 then
		raise EPerl.Create('Failed to run Perl interpreter');

	Inc(FInterpreterCount);
end;

constructor TPerlHandle.Create(Cleanup: Boolean = false);
begin
	{ most basic way of creating the interpreter - eval emptiness }
	self.Create(['-e', '0'], Cleanup);
end;

destructor TPerlHandle.Destroy();
begin
	self.DisownScalars;

	if FPerl <> nil then begin
		perl_destruct(FPerl);
		perl_free(FPerl);

		Dec(FInterpreterCount);
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
	self.AdoptScalar(result);
end;

function TPerlHandle.IntToScalar(Value: Int64): TPerlSV;
begin
	result := Perl_newSViv(Value);
	self.AdoptScalar(result);
end;

function TPerlHandle.StringToScalar(const Value: String): TPerlSV;
begin
	result := Perl_newSVpv(PChar(Value), 0);
	self.AdoptScalar(result);
end;

procedure TPerlHandle.EnterContext();
var
	I: Integer;
begin
	for I := low(FPerlVarsMarks) to high(FPerlVarsMarks) do begin
		if FPerlVarsMarks[I] >= 0 then continue;

		FPerlVarsMarks[I] := FPerlVarsLastIndex + 1;
		exit;
	end;

	raise EPerlContext.Create('Perl max context pool is depleted');
end;

procedure TPerlHandle.LeaveContext();
var
	I: Integer;
begin
	for I := high(FPerlVarsMarks) downto low(FPerlVarsMarks) do begin
		if FPerlVarsMarks[I] < 0 then continue;

		self.DisownScalars(FPerlVarsMarks[I]);
		FPerlVarsMarks[I] := -1;
		exit;
	end;

	raise EPerlContext.Create('Attempt to leave Perl context without entering it first');
end;

function TPerlHandle.RunCode(const Code: String; ExceptionOnError: Boolean = true): TPerlSV;
begin
	result := Perl_eval_pv(TPerlPV(Code), 0);

	if ExceptionOnError and not self.EvalSuccess then
		raise EPerlEvalFailed.Create(
			Format(
				'evaluating code failed: %s',
				[self.ScalarToString(self.EvalError)]
			)
		);
end;

function TPerlHandle.CallSub(const Name: String; const Args: Array of TPerlSV; ExceptionOnError: Boolean = true): TPerlSV;
begin
	result := call_perl_sub(PChar(Name), @Args, length(Args));
	self.AdoptScalar(result);

	if ExceptionOnError and not self.EvalSuccess then
		raise EPerlCallFailed.Create(
			Format(
				'calling %s failed: %s',
				[Name, self.ScalarToString(self.EvalError)]
			)
		);
end;

function TPerlHandle.EvalError(): TPerlSV;
begin
	result := do_ERRSV;
end;

function TPerlHandle.EvalSuccess(): Boolean;
begin
	result := not self.ScalarTrue(self.EvalError);
end;

{ implementation end }

var
	I: Integer;
	Argv: Array of PChar;
	Env: Array of PChar;

initialization
	TPerlHandle.FInterpreterCount := 0;

	SetLength(Argv, ParamCount);
	for I := 0 to high(Argv) do
		Argv[I] := PChar(ParamStr(I));

	SetLength(Env, GetEnvironmentVariableCount);
	for I := 0 to high(Env) do
		Env[I] := PChar(GetEnvironmentString(I));

	do_PERL_SYS_INIT3(ParamCount, @Argv, @Env);

finalization
	do_PERL_SYS_TERM;
end.

