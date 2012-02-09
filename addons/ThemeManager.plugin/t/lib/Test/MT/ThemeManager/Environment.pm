package Test::MT::ThemeManager::Environment;

=head1 NAME

Test::MT::ThemeManager::Environment - Class representing the environment for all Theme Manager tests

=head1 SYNOPSIS

    use Test::MT::ThemeManager::Environment;
    my $env = Test::MT::ThemeManager::Environment->new();
    $env->init();

=head1 DESCRIPTION

Class representing the environment under which all all MT tests are executing

=cut

use strict;
use warnings;
use base qw( Test::MT::Environment );

__PACKAGE__->mk_classdata(
    DataClass => join('::', __PACKAGE__, 'Data::YAML'));

sub init_db {
    my $self = shift;
    $self->SUPER::init_db();
    require ThemeManager::Plugin;
    ThemeManager::Plugin->_theme_check();
    1;
}
1;

__END__

=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate (even
the ones that will "never happen"), with a full explanation of each problem,
one or more likely causes, and any suggested remedies.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems via http://help.endevver.com/

Patches are welcome.

=head1 AUTHOR

Jay Allen, Endevver, LLC http://endevver.com/

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 Endevver, LLC (info@endevver.com).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
