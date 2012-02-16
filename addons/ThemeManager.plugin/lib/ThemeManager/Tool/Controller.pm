package ThemeManager::Tool::Controller;

=head1 NAME

ThemeManager::Tool::Controller - Library containing functionality
for the tmctl utility

=head1 SYNOPSIS

The following code can be used to bootstrap this class as can be seen in the
tmctl utility:

    #!/usr/bin/perl
    use strict;
    use warnings;
    use FindBin qw($Bin);
    use lib ( "$Bin/../lib", "$Bin/../extlib" );
    BEGIN {
        my $mtdir = $ENV{MT_HOME} ? "$ENV{MT_HOME}/" : '';
        unshift @INC, "$mtdir$_" foreach qw( lib extlib );
    }
    use MT::Bootstrap::CLI App => 'ThemeManager::Tool::Controller';

=head1 DESCRIPTION

See:

    addons/ThemeManager.plugin/tools/tmctl --man

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

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Pod::Usage;
use File::Spec;
use Try::Tiny;
use Cwd qw( realpath );

use base qw( ThemeManager::Tool );

use MT::Util qw( caturl );

use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
###l4p our $logger = MT::Log::Log4perl->new();

$| = 1;
our %classes_seen;

=head2 usage

This method overrides the inherited method to provide usage text for the
--help flag and any errors.

=cut
sub usage {
    my $self = shift;
    my $usage = $self->SUPER::usage();

    my $flags =<<EOD;
EOD

    return join('', $usage->{header}, $flags, $usage->{flags} );
}

=head2 help

This method overrides the inherited method to provide help text for the
--help flag.

=cut
sub help { q{ CHANGE ME SOON! } }

=head2 init_options

This method overides the inherited method in order to shift any C<theme>
parameter value to the aliased C<ts_id> parameter.

=cut
sub init_options {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    $app->SUPER::init_options(@_) or return;

    my $opt = $app->options || {};
    $opt->{ts_id}   ||= delete $opt->{theme} if $opt->{theme};
    ###l4p $logger->debug('$opt: ', l4mtdump( $opt ));

    1;
}

=head2 init

This method overrides the inherited method to define modes and mode handles
specific to this application.

=cut
sub init {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    $app->SUPER::init(@_) or return;
    $app->add_methods(
        'list'      => \&mode_list,
        'info'      => \&mode_info,
        'upgrade'   => \&mode_upgrade,
        'republish' => \&mode_republish,
        'check'     => \&mode_check,
    );
    $app;
}

=head2 mode_list

This method is the mode handler for the B<list> command. It outputs the
following information about all blogs in the installation:

=over 4

=item * Blog ID

=item * Blog name

=item * Blog URL

=item * Blog template set ID (if one is applied)

=item * The blog's theme version

=item * The theme version

=back

=cut
sub mode_list {
    my $app = shift;
    my $tm  = MT->component('ThemeManager');
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    my @keys = qw( id name site_url theme version latest );
    require Text::TabularDisplay;
    my $theme_table = Text::TabularDisplay->new( @keys );

    my $iter = MT->model('blog')->load_iter();
    while ( my $blog = $iter->() ) {

        # Basic blog data
        my @values = map { $blog->$_ } qw( id name site_url );

        require ThemeManager::Theme;
        # Basic blog theme data, if the blog has a theme
        if ( my $theme  = $blog->theme ) {
            push( @values,
                    ( map { ''.$theme->$_ } qw( ts_id version ) ),
                    $theme->is_outdated ? ''.$theme->latest_version
                                        : 'same',
            );
        }
        else {
            push( @values, $blog->template_set || '--', '--', '--');
                # mt_community_blog isn't being properly loaded as a theme
                # so we include $blog->template_set if it's set
        }

        # Force defined values
        @values = map { defined $_ ? $_ : '' } @values;

        $theme_table->add( @values );
    }

    return $theme_table->render;
}

=head2 mode_upgrade

The method is the B<upgrade> mode handler.

=cut
sub mode_upgrade {
    my $app = shift;
    my $q   = $app->query;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $opt = $app->options();
    my $id  = $q->param('blog_id') || $q->param('ts_id');
    return $app->error( "You did not specify a blog_id or ts_id" )
        unless $id;

    local $| = 1;

    return $q->param('blog_id') ? $app->upgrade_blog( $id )
         : $q->param('ts_id')   ? $app->upgrade_theme( $id )
                                : undef;
}

=head2 mode_info

Not yet implemented

=cut
sub mode_info {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $opt = $app->options();
    return Dumper({mysub => 'mode_info', %$opt});
}

=head2 mode_republish

Not yet implemented

=cut
sub mode_republish { shift->error('Not yet implemented') }

=head2 mode_check

Not yet implemented

=cut
sub mode_check { shift->error('Not yet implemented') }

=head2 upgrade_theme

This method iterates over all blogs in the installation looking for those
using the theme whose template set ID (C<TS_ID>) matches the provided
argument. All blogs using the theme are then upgraded via the C<upgrade_blog>
method.

=cut
sub upgrade_theme {
    my $app   = shift;
    my $ts_id = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    ###l4p $logger->info('Upgrading all blogs using theme: ', $ts_id);

    my $iter = MT->model('blog')->load_iter();
    while ( my $blog = $iter->() ) {
        my $theme  = $blog->theme;
        next unless $theme and $theme->ts_id eq $ts_id;
        ###l4p $logger->info('Upgrading theme '.$ts_id.' for blog ID '.$blog->id);

        $app->upgrade_blog( $blog->id ) or return;

        ###l4p $logger->info('Finished upgrading theme '.$ts_id.' for blog ID '.$blog->id);
    }
    ###l4p $logger->info('Finished upgrading all blogs with theme '.$ts_id);
    1;
}


=head2 upgrade_blog

This method takes a C<blog_id> parameter and bootstraps the BlogUpgrader to
execute a theme upgrade for the specified blog.

=cut
sub upgrade_blog {
    my $app     = shift;
    my $blog_id = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    require ThemeManager::BlogUpgrader;
    my $upgrader = ThemeManager::BlogUpgrader->new( blog_id => $blog_id );

    return $upgrader->upgrade() || $app->error( $upgrader->errstr );
}

1;

__END__

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
