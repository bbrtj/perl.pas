package StringManipulator::StringUtil;

use v5.10;
use strict;
use warnings;

sub new
{
	my ($class) = @_;

	return bless {
		current => '',
	}, $class;
}

sub append
{
	my ($self, $string) = @_;

	$self->{current} .= $string;
}

sub replace
{
	my ($self, $regex, $replacement) = @_;

	$self->{current} =~ s{$regex}{$replacement}g;
}

sub get
{
	my ($self) = @_;

	return $self->{current};
}

1;

