unit TestObjects;

{$mode objfpc}{$H+}{$J-}

interface

uses SysUtils;

type
	TCalculator = class
	private
		FValue: Double;
	public
		constructor Create();
	public
		procedure Add(Value: Double);
		procedure Subtract(Value: Double);
		procedure Multiply(Value: Double);
		procedure Divide(Value: Double);
		function GetValue(): Double;
	end;

implementation

constructor TCalculator.Create();
begin
	FValue := 0;
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

end.

