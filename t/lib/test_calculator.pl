use strict;
use warnings;

use TCalculator;

sub run_calculation
{
	my $calc = TCalculator->new;

	$calc->add(15.3);
	$calc->divide(3);
	$calc->multiply(2.5);
	$calc->subtract(5);

	return $calc->get_value;
}

sub run_exception
{
	my $calc = TCalculator->new;

	# this method is registered, but no such method declared in pascal
	$calc->UNKNOWN;
}

