package PascalObject;

use strict;
use warnings;

require DynaLoader;
our @ISA = qw(DynaLoader);
__PACKAGE__->bootstrap;

sub setup_methods
{
	my ($class, @methods) = @_;

	foreach my $method (@methods) {
		no strict 'refs';
		*{"${class}::${method}"} = sub {
			my $self = shift;
			return $self->_call_method($method, @_);
		};
	}
}

1;

__END__

=head1 NAME

PascalObject - Base class for wrapping Pascal objects in Perl

=head1 SYNOPSIS

    use PascalObject;

    # Create a Pascal object (assuming MyPascalClass is registered)
    my $obj = PascalObject->new('MyPascalClass', @constructor_args);

    # Call methods
    my $result = $obj->some_method(@args);

    # Or use AUTOLOAD
    my $result = $obj->some_method(@args);

=head1 DESCRIPTION

This module provides a bridge to use Pascal objects from Perl. Pascal classes
must be registered on the Pascal side to be accessible.

=cut

