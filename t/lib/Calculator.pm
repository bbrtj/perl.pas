package Calculator;

use strict;
use warnings;

sub new
{
	my ($class) = @_;

	return bless {value => 0}, $class;
}

sub add
{
	my ($self, $num) = @_;

	$self->{value} += $num;
}

sub subtract
{
	my ($self, $num) = @_;

	$self->{value} -= $num;
}

sub divide
{
	my ($self, $num) = @_;

	$self->{value} /= $num;
}

sub multiply
{
	my ($self, $num) = @_;

	$self->{value} *= $num;
}

sub get_value
{
	my ($self, $num) = @_;

	return $self->{value};
}

1;

