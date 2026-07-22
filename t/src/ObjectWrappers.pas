unit ObjectWrappers;

{$mode objfpc}{$H+}{$J-}

interface

uses SysUtils, PerlEmbed, PerlObjectLayer;

type
	TPerlCalculator = class(TPerlObject)
	protected
		function GetPerl(): TPerlHandle; override;
	public
		constructor Create();
	public
		class function PerlClassName(): String; override;
		procedure Add(Num: Double);
		procedure Subtract(Num: Double);
		procedure Divide(Num: Double);
		procedure Multiply(Num: Double);
		function GetValue(): Double;
	end;

	TCalculator = class(TPascalObject)
	private
		FValue: Double;
	protected
		function GetPerl(): TPerlHandle; override;
	public
		constructor Create(); override;
		function CallMethod(const AMethodName: String; Args: Array of TPerlSV): TPerlSV; override;
	public
		procedure Add(Value: Double);
		procedure Subtract(Value: Double);
		procedure Multiply(Value: Double);
		procedure Divide(Value: Double);
		function GetValue(): Double;
	end;

var
	{ global perl handle to avoid keeping a copy in every object }
	ObjectWrappersPerl: TPerlHandle;

implementation

function TPerlCalculator.GetPerl(): TPerlHandle;
begin
	result := ObjectWrappersPerl;
end;

constructor TPerlCalculator.Create();
begin
	inherited Create([]);
end;

class function TPerlCalculator.PerlClassName(): String;
begin
	result := 'Calculator';
end;

procedure TPerlCalculator.Add(Num: Double);
begin
	self.Perl.CallMethod(
		self.Instance,
		'add',
		[self.Perl.FloatToScalar(Num)]
	);
end;

procedure TPerlCalculator.Subtract(Num: Double);
begin
	self.Perl.CallMethod(
		self.Instance,
		'subtract',
		[self.Perl.FloatToScalar(Num)]
	);
end;

procedure TPerlCalculator.Divide(Num: Double);
begin
	self.Perl.CallMethod(
		self.Instance,
		'divide',
		[self.Perl.FloatToScalar(Num)]
	);
end;

procedure TPerlCalculator.Multiply(Num: Double);
begin
	self.Perl.CallMethod(
		self.Instance,
		'multiply',
		[self.Perl.FloatToScalar(Num)]
	);
end;

function TPerlCalculator.GetValue(): Double;
begin
	result := self.Perl.ScalarToFloat(
		self.Perl.CallMethod(
			self.Instance,
			'get_value',
			[]
		)
	);
end;

function TCalculator.GetPerl(): TPerlHandle;
begin
	result := ObjectWrappersPerl;
end;

constructor TCalculator.Create();
begin
	inherited;
	FValue := 0;
end;

function TCalculator.CallMethod(const AMethodName: String; Args: Array of TPerlSV): TPerlSV;
	procedure AssertArgsCount(Count: Integer);
	begin
		if length(Args) <> Count then
			raise Exception.Create('bad number of arguments, expected ' + Count.ToString);
	end;

begin
	result := nil;

	case AMethodName of
		'add': begin
			AssertArgsCount(1);
			self.Add(self.Perl.ScalarToFloat(Args[0]));
		end;
		'subtract': begin
			AssertArgsCount(1);
			self.Subtract(self.Perl.ScalarToFloat(Args[0]));
		end;
		'multiply': begin
			AssertArgsCount(1);
			self.Multiply(self.Perl.ScalarToFloat(Args[0]));
		end;
		'divide': begin
			AssertArgsCount(1);
			self.Divide(self.Perl.ScalarToFloat(Args[0]));
		end;
		'get_value': begin
			result := self.Perl.FloatToScalar(self.GetValue);

			{ XS will expect the code calling it to take the ownership of the
			  scalar - don't adopt it }
			self.Perl.SnatchScalar;
		end;
		otherwise
			raise Exception.Create('No such method');
	end;
end;

procedure TCalculator.Add(Value: Double);
begin
	FValue := FValue + Value;
end;

procedure TCalculator.Subtract(Value: Double);
begin
	FValue := FValue - Value;
end;

procedure TCalculator.Multiply(Value: Double);
begin
	FValue := FValue * Value;
end;

procedure TCalculator.Divide(Value: Double);
begin
	if Value <> 0 then
		FValue := FValue / Value
	else
		raise Exception.Create('Division by zero');
end;

function TCalculator.GetValue(): Double;
begin
	result := FValue;
end;

initialization
	{ Register the Calculator class so it can be used from Perl }
	PascalObjectRegistry.RegisterClass(TCalculator);
end.

