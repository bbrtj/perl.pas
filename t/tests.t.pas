program Tests;

uses TAPSuite,
	BasicTests;

begin
	// Note: suites can also be added in initialization sections, but then
	// there is less control over their sequence.
	Suite(TBasicSuite);

	RunAllSuites;
end.

