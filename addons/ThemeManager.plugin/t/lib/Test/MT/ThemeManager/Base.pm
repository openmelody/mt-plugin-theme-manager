package Test::MT::ThemeManager::Base;

=head1 NAME

Test::MT::ThemeManager::Base - Subclass of Test::MT::Base and also the
abstract base class for all Theme Manager tests

=head1 SYNOPSIS

    package Test::MT::ThemeManager::Suite::Compile;

    use base qw( Test::MT::ThemeManager::Base );
    my $test = __PACKAGE__->new();

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use Carp;
use Test::Most;
use Try::Tiny;
use Data::Dumper::Names;

use base qw( Test::MT::Base );

BEGIN {
    my $mt = $ENV{MT_HOME} || '';
    $mt and $mt =~ s{/*$}{/}i;   # Trailing slash; 
                                 # i is TextMate syntax coloring fix
    unshift( @INC, (
        "${mt}lib", "${mt}extlib",
        "${mt}addons/ConfigAssistant.pack/lib", 
        "${mt}addons/ThemeManager.plugin/lib", 
        "${mt}addons/ThemeManager.plugin/extlib",
        "${mt}addons/ThemeManager.plugin/t/lib", 
        "${mt}addons/ThemeManager.plugin/t/extlib"
    ));
}

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
