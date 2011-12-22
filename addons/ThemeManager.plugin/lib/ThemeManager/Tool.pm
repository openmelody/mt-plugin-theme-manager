package ThemeManager::Tool;

use strict;
use warnings;
use Data::Dumper;
use Carp;
use base qw( MT::App::CLI );

use Pod::Usage;

use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
our $logger = MT::Log::Log4perl->new();

$| = 1;
our %classes_seen;

sub usage {
    my $header = "Usage: $0 [options]\nOptions:\n";
    my $flags =<<EOD;
    --verbose   Output more progress information
    --man       Output the man page for the utility
    --help      Output this message
EOD
    return { header => $header, flags => $flags };
}

sub help {}

sub option_spec {
    return $_[0]->SUPER::option_spec();
}

sub init_options {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    # $app->show_usage() unless @ARGV;

    $app->SUPER::init_options(@_) or return;
    my $opt = $app->options || {};
    # $opt->{cols} = ref $opt->{cols} eq 'ARRAY' 
    #              ? $opt->{cols} 
    #              : [ split( /\s*,\s*/, ($opt->{cols} || 'id,name,site_url') )];
    ###l4p $logger->debug('$opt: ', l4mtdump( $opt ));

    if ( my $mode = shift @ARGV ) {
        $app->mode($mode);
        my %args = @ARGV;
        $opt->{$_} = $args{$_} foreach keys %args;
    }

    1;
}

sub mode_default {}

1;

__END__

=head1 NAME

Tool.pm - One-line description of module's purpose

=head1 VERSION

This documentation refers to Tool.pm version 0.0.1.

=head1 SYNOPSIS

   use Tool.pm;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.

=head1 DESCRIPTION

A full description of the module and its features.

May include numerous subsections (i.e., =head2, =head3, etc.).

=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.

These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module
provides.

Name the section accordingly.

In an object-oriented module, this section should begin with a sentence (of the
form "An object of this class represents ...") to give the reader a high-level
context to help them understand the methods that are subsequently described.

=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate (even
the ones that will "never happen"), with a full explanation of each problem,
one or more likely causes, and any suggested remedies.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module, including
the names and locations of any configuration files, and the meaning of any
environment variables or properties that can be set. These descriptions must
also include details of any configuration language used.

=head1 DEPENDENCIES

A list of all of the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules
are part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for system
or program resources, or due to internal limitations of Perl (for example, many
modules that use source code filters are mutually incompatible).

=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also, a list of restrictions on the features the module does provide: data types
that cannot be handled, performance issues and the circumstances in which they
may arise, practical limitations on the size of data sets, special cases that
are not (yet) handled, etc.

The initial template usually just has:

There are no known bugs in this module.

Please report problems to Jay Allen (<contact address>)

Patches are welcome.

=head1 AUTHOR

Jay Allen, Textura Design http://texturadesign.com/code

=head1 LICENSE AND COPYRIGHT

Copyright (c) <year> <copyright holder> (<contact address>).
All rights reserved.

followed by whatever license you wish to release it under.

For Perl code that is often just:

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.