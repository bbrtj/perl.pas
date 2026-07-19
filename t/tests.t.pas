program Tests;

uses TAPSuite,
	BasicTests, LibTests;

begin
	Suite(TBasicSuite);
	Suite(TLibSuite);

	RunAllSuites;
end.

