package StringManipulator;

use v5.10;
use strict;
use warnings;

use StringManipulator::StringUtil;

my $util_instance;

sub start
{
	$util_instance = StringManipulator::StringUtil->new;
	return;
}

sub append
{
	my ($string) = @_;

	$util_instance // die 'no util instance - call start first';
	$util_instance->append($string);
	return $util_instance->get;
}

sub replace
{
	my ($regex_string, $replacement) = @_;

	$util_instance // die 'no util instance - call start first';
	$util_instance->replace($regex_string, $replacement);
	return $util_instance->get;
}

1;

