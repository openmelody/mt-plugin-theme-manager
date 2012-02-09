package Test::MT::ThemeManager;

=head1 NAME

Test::MT::ThemeManager - Subclass of MT::Test::Plugin containing
ThemeManager-specific test extension functions

=head1 SYNOPSIS

    use Test::MT::ThemeManager;
    my $env = Test::MT::ThemeManager->new();
    $env->init();

=head1 DESCRIPTION

A full description of the module and its features.

May include numerous subsections (i.e., =head2, =head3, etc.).

=cut
use strict;
use warnings;
use Carp;
use Data::Dumper;

use base qw( Test::MT );

=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.

These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module
provides.

Name the section accordingly.

In an object-oriented module, this section should begin with a sentence (of the
form "An object of this class represents ...") to give the reader a high-level
context to help them understand the methods that are subsequently described.

=cut

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
