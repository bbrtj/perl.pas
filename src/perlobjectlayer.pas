unit PerlObjectLayer;

{$mode objfpc}{$H+}{$J-}

interface

uses
	Ctypes, SysUtils, Generics.Collections, PerlEmbed;

type
	TDynaLoaderPerl = class(TPerlHandle)
	protected
		function GetXSInit(): TXSInit; override;
	end;

	TPascalObject = class abstract
	private
		FManageObject: Boolean;
	protected
		function GetPerl(): TPerlHandle; virtual; abstract;
	protected
		property Perl: TPerlHandle read GetPerl;
		property ManageObject: Boolean read FManageObject write FManageObject;
	public
		constructor Create(); virtual;
		constructor CreateFromPerl(Args: Array of TPerlSV); virtual;
	public
		function MakeSV(): TPerlSV;
		function CallMethod(const AMethodName: String; Args: Array of TPerlSV): TPerlSV; virtual; abstract;
	end;

	TPerlObject = class abstract
	protected
		FInstance: TPerlSV;
		FManageSV: Boolean;
	protected
		function GetPerl(): TPerlHandle; virtual; abstract;
	protected
		property Perl: TPerlHandle read GetPerl;
		property Instance: TPerlSV read FInstance;
	public
		constructor Create(Args: Array of TPerlSV; ManageSV: Boolean = false);
		constructor CreateFromSV(AInstance: TPerlSV);
		destructor Destroy; override;
	public
		class function ConstructorName(): String; virtual;
		class function PerlClassName(): String; virtual; abstract;
	end;

	TPascalObjectClass = class of TPascalObject;
	TPascalClasses = specialize TDictionary<String, TPascalObjectClass>;

	TPascalObjectRegistry = class
	strict private
		FClasses: TPascalClasses;
	public
		constructor Create();
		destructor Destroy(); override;
	public
		procedure RegisterClass(ObjClass: TPascalObjectClass);
		procedure UnregisterClass(const AClassName: String);
		function GetClass(const AClassName: String): TPascalObjectClass;
	end;

var
	PascalObjectRegistry: TPascalObjectRegistry;
	LastPascalError: String;

{ DynaLoader boot procedure (needs DynaLoader) }
procedure boot_DynaLoader(Cv: TPerlCV); cdecl; external;

{ C callbacks called from XS layer }
function pascal_object_new(AClassName: PChar; Args: PPerlSV; ArgCount: cint): Pointer; cdecl; public;
procedure pascal_object_destroy(Handle: Pointer); cdecl; public;
function pascal_object_call_method(Handle: Pointer; AMethodName: PChar; Args: PPerlSV; ArgCount: cint): TPerlSV; cdecl; public;
function pascal_last_error(): PChar; cdecl; public;

implementation

{ use alternative (non-empty) xs_init to include DynaLoader }
procedure MyXSInit(); cdecl;
var
	ThisFile: String;
begin
	ThisFile := {$I %FILE%};
	Perl_newXS('DynaLoader::boot_DynaLoader', @boot_DynaLoader, PChar(ThisFile));
end;

function TDynaLoaderPerl.GetXSInit(): TXSInit;
begin
	result := @MyXSInit;
end;

constructor TPascalObject.Create();
begin
	FManageObject := true;
end;

constructor TPascalObject.CreateFromPerl(Args: Array of TPerlSV);
begin
	self.Create;
	FManageObject := false;
end;

function TPascalObject.MakeSV(): TPerlSV;
var
	Pkg: String;
begin
	Pkg := self.ClassName;
	result := bless_pointer(PChar(Pkg), self);
	self.Perl.AdoptScalar(result);
end;

constructor TPascalObjectRegistry.Create();
begin
	inherited Create;
	FClasses := TPascalClasses.Create;
end;

destructor TPascalObjectRegistry.Destroy();
var
	Instance: TPascalObject;
begin
	FClasses.Free;
	inherited Destroy;
end;

procedure TPascalObjectRegistry.RegisterClass(ObjClass: TPascalObjectClass);
begin
	FClasses.AddOrSetValue(ObjClass.ClassName, ObjClass);
end;

procedure TPascalObjectRegistry.UnregisterClass(const AClassName: String);
begin
	FClasses.Remove(AClassName);
end;

function TPascalObjectRegistry.GetClass(const AClassName: String): TPascalObjectClass;
begin
	if not FClasses.TryGetValue(AClassName, result) then
		result := nil;
end;

constructor TPerlObject.Create(Args: Array of TPerlSV; ManageSV: Boolean = false);
begin
	FManageSV := ManageSV;
	FInstance := self.Perl.CallMethod(
		self.Perl.StringToScalar(self.PerlClassName),
		self.ConstructorName,
		Args
	);

	if FManageSV then
		self.Perl.SnatchScalar;
end;

constructor TPerlObject.CreateFromSV(AInstance: TPerlSV);
begin
	FManageSV := false;
	FInstance := AInstance;
end;

destructor TPerlObject.Destroy();
begin
	if (FInstance <> nil) and FManageSV then
		self.Perl.DisownScalar(FInstance);
end;

class function TPerlObject.ConstructorName(): String;
begin
	result := 'new';
end;

{ C callback implementations }

function pascal_object_new(AClassName: PChar; Args: PPerlSV; ArgCount: cint): Pointer; cdecl;
var
	ObjClass: TPascalObjectClass;
	Instance: TPascalObject;
	PerlArgs: Array of TPerlSV;
	I: Integer;
begin
	result := nil;
	LastPascalError := '';

	ObjClass := PascalObjectRegistry.GetClass(String(AClassName));
	if ObjClass = nil then begin
		LastPascalError := 'Pascal class not found';
		exit;
	end;

	try
		{ Convert C array to Pascal array }
		SetLength(PerlArgs, ArgCount);
		for I := 0 to ArgCount - 1 do
			PerlArgs[I] := PPerlSV(Args + I * SizeOf(TPerlSV))^;

		{ Use the instance pointer as the handle }
		Instance := ObjClass.CreateFromPerl(PerlArgs);
		result := Instance;
	except
		on E: Exception do begin
			LastPascalError := E.Message;
		end;
	end;
end;

procedure pascal_object_destroy(Handle: Pointer); cdecl;
begin
	LastPascalError := '';

	try
		if not TPascalObject(Handle).ManageObject then
			TPascalObject(Handle).Free;
	except
		on E: Exception do
			LastPascalError := E.Message;
	end;
end;

function pascal_object_call_method(Handle: Pointer; AMethodName: PChar; Args: PPerlSV; ArgCount: cint): TPerlSV; cdecl;
var
	PerlArgs: Array of TPerlSV;
	I: Integer;
begin
	result := nil;
	LastPascalError := '';

	if Handle = nil then begin
		LastPascalError := 'Invalid Pascal object handle';
		exit;
	end;

	try
		{ Convert C array to Pascal array }
		SetLength(PerlArgs, ArgCount);
		for I := 0 to ArgCount - 1 do
			PerlArgs[I] := PPerlSV(Args + I * SizeOf(TPerlSV))^;

		result := TPascalObject(Handle).CallMethod(String(AMethodName), PerlArgs);
	except
		on E: Exception do
			LastPascalError := E.Message;
	end;
end;

function pascal_last_error(): PChar; cdecl;
begin
	result := PChar(LastPascalError);
end;

initialization
	PascalObjectRegistry := TPascalObjectRegistry.Create;
	LastPascalError := '';

finalization
	PascalObjectRegistry.Free;

end.

