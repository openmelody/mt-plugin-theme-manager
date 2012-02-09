package ThemeManager::Tool;

=head1 NAME

ThemeManager::Tool - One-line description of module's purpose

=head1 SYNOPSIS

   use ThemeManager::Tool;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.

=head1 DESCRIPTION

A full description of the module and its features.

May include numerous subsections (i.e., =head2, =head3, etc.).

=cut
use strict;
use warnings;
use Data::Dumper;
use Carp;
use Pod::Usage;

use lib qw( addons/ConfigAssistant.pack/lib );
use base qw( MT::App::CLI );

use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
###l4p our $logger = MT::Log::Log4perl->new();

$| = 1;
our %classes_seen;

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

    $app->show_usage() unless @ARGV;

    $app->SUPER::init_options(@_) or return;
    my $opt = $app->options || {};
    ###l4p $logger->debug('$opt: ', l4mtdump( $opt ));

    if ( my $mode = shift @ARGV ) {
        ###l4p $logger->debug('Mode set to: ', $mode);
        $opt->{__mode} = $mode;
        my %args = @ARGV;
        $opt->{$_} = $args{$_} foreach keys %args;
    }

    1;
}

sub mode_default {}

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
