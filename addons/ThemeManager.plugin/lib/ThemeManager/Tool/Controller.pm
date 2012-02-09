package ThemeManager::Tool::Controller;

=head1 NAME

ThemeManager::Tool::Controller - Library containing functionality
for the tmctl utility

=head1 SYNOPSIS

The following code comes from the tmctl utility:

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

DOCUMENTATION NEEDED

=cut
sub usage {
    my $self = shift;
    my $usage = $self->SUPER::usage();

    my $flags =<<EOD;
EOD

    return join('', $usage->{header}, $flags, $usage->{flags} );
}

=head2 help

DOCUMENTATION NEEDED

=cut
sub help { q{ CHANGE ME SOON! } }

# sub option_spec {
#     return ( 'cols:s', $_[0]->SUPER::option_spec() );
# }

=head2 init_options

DOCUMENTATION NEEDED

=cut
sub init_options {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    $app->SUPER::init_options(@_) or return;

    my $opt = $app->options || {};
    $opt->{ts_id} ||= delete $opt->{theme} if $opt->{theme};
    $opt->{cols} = ref $opt->{cols} eq 'ARRAY'
                 ? $opt->{cols}
                 : [ split( /\s*,\s*/, ($opt->{cols} || 'id,name,site_url') )];
    ###l4p $logger->debug('$opt: ', l4mtdump( $opt ));

    1;
}

=head2 init

DOCUMENTATION NEEDED

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

DOCUMENTATION NEEDED

list themes used
list themes all
list blogs all
list blogs with theme TS_ID
list blogs with theme ''
list blogs with theme none

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

DOCUMENTATION NEEDED

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

DOCUMENTATION NEEDED

=cut
sub mode_info {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $opt = $app->options();
    return Dumper({mysub => 'mode_info', %$opt});
}

=head2 mode_republish

DOCUMENTATION NEEDED

=cut
sub mode_republish { shift->error('Not yet implemented') }

=head2 mode_check

DOCUMENTATION NEEDED

=cut
sub mode_check { shift->error('Not yet implemented') }

=head2 upgrade_theme

DOCUMENTATION NEEDED

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

DOCUMENTATION NEEDED

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
