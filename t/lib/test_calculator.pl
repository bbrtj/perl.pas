use strict;
use warnings;

use TCalculator;
use Calculator;

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

sub get_perl_calculator
{
	my $calc = Calculator->new;
	$calc->subtract(-20);

	return $calc;
}

sub check_pascal_object
{
	my ($calc) = @_;

	return $calc->get_value;
}

