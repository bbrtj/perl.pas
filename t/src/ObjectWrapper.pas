unit ObjectWrapper;

{$mode objfpc}{$H+}{$J-}

interface

uses PerlEmbed;

type
	TStringUtil = class(TPerlObject)
	protected
		function GetPerl(): TPerlHandle; override;
	public
		constructor Create();
	public
		class function PerlClassName(): String; override;
		procedure AppendString(const Value: String);
		procedure ReplaceString(const Regex: String; const Replacement: String);
		function GetString(): String;
	end;

var
	{ global perl handle to avoid keeping a copy in every object }
	ObjectWrapperPerl: TPerlHandle;

implementation

function TStringUtil.GetPerl(): TPerlHandle;
begin
	result := ObjectWrapperPerl;
end;

constructor TStringUtil.Create();
begin
	inherited Create([]);
end;

class function TStringUtil.PerlClassName(): String;
begin
	result := 'StringManipulator::StringUtil';
end;

procedure TStringUtil.AppendString(const Value: String);
begin
	self.Perl.CallMethod(
		self.Instance,
		'append',
		[self.Perl.StringToScalar(Value)]
	);
end;

procedure TStringUtil.ReplaceString(const Regex: String; const Replacement: String);
begin
	self.Perl.CallMethod(
		self.Instance,
		'replace',
		[self.Perl.StringToScalar(Regex), self.Perl.StringToScalar(Replacement)]
	);
end;

function TStringUtil.GetString(): String;
begin
	result := self.Perl.ScalarToString(
		self.Perl.CallMethod(
			self.Instance,
			'get',
			[]
		)
	);
end;

end.

