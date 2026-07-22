program Tests;

uses TAPSuite,
	BasicTests, LibTests, WrapperTests;

begin
	Suite(TBasicSuite);
	Suite(TLibSuite);
	Suite(TWrapperSuite);

	RunAllSuites;
end.

