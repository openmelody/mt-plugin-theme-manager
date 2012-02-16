package ThemeManager::Theme;

=head1 NAME

ThemeManager::Theme - MT::Object subclass for theme records

=head1 SYNOPSIS

    my $blog  = MT->model('blog')->load( 1 );
    my $theme = $blog->theme;
    # DOCUMENTATION NEEDED

=head1 DESCRIPTION

A full description of the module and its features.

May include numerous subsections (i.e., =head2, =head3, etc.).

=cut
use strict;
use warnings;
use Carp;
use Try::Tiny;
use Scalar::Util qw( blessed ); #looks_like_number );
use Perl::Version;
use Data::Dumper;
use Params::Validate qw( :all );

use base qw( MT::Object );

use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
###l4p our $logger = MT::Log::Log4perl->new();

use MT;

__PACKAGE__->install_properties( {
                               column_defs => {
                                    'id' => 'integer not null auto_increment',
                                    'plugin_sig' => 'string(255)',
                                    'ts_id'      => 'string(255)',
                                    'ts_label'   => 'string(255)',
                                    'theme_meta' => 'blob',
                               },
                               indexes    => { plugin_sig => 1, ts_id => 1, },
                               datasource => 'theme',
                               primary_key => 'id',
                             }
);

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

sub class_label {
    MT->translate("Theme");
}

sub class_label_plural {
    MT->translate("Themes");
}

##############################################################################

=head2 $Class->load_from_blog

( \%terms, \%args )

This class method instantiates a theme object that is associated with and in
use by B<a single blog>, specified by the load parameter arguments. If no
blogs or more than one blog is returned by the provided load terms and
optional args, a class error will be thrown (ThemeManager::Theme->errstr)
and this method will return c<undef>.

It's important to note that this method instantiates a B<blog-specific> theme
object which is related to but not the same as the theme object returned via
the C<load> method.  This means that any actions taken or modifications made
will only affect the specified blog.

=cut
sub load_from_blog {
    my $class   = shift;
    my ( $arg ) = @_;
    my $Blog = MT->model('blog');
    my $blog   = $arg if try { $arg->isa( $Blog ) };

    my $theme = try {

        $blog ||= $Blog->load( @_ )
            or die sprintf( "Error loading blog: %s",
                                ($Blog->errstr || Dumper(\@_) ));
        my $ts_id    = $blog->template_set or return;
        my $plugin   = $class->plugin( $ts_id )
            or die "Could not load plugin for template_set $ts_id";

        my $th_terms = {
            plugin_sig => lc($plugin->{plugin_sig}),
            ts_id      => $ts_id,
        };

        my $theme = $class->load( $th_terms );
        if ( $theme ) {
            $theme->_cache( %$_ )
                        for ({ plugin_object => $plugin            },
                             { theme_blog    => $blog              },
                             { definition    => $theme->definition });
        }
        else { die $class->errstr if $class->errstr }
        return $theme;
    }
    catch {
        warn "Blog theme load failed: $_";
        $class->error( "Blog theme load failed: $_" );
    };
    return $theme;
}

=head3 Aliased method C<$blog->theme>

For convenience and brevity's sake,
C<ThemeManager::Theme->load_from_blog( $blog )> has been aliased to
$blog->theme.

=cut
{
    no strict 'refs';
    my $Blog = MT->model('blog');
    *{$Blog.'::theme'} = sub { __PACKAGE__->load_from_blog( @_ ) }
}

##############################################################################

=head2 set_defaults

This overridden parent class method—called automatically at the time a
ThemeManager::Theme object is instantiated—provisions the new object with
default values for any properties defined by the class but not populated with
a value in its cached theme metadata.  Since these values I<do not exist> in
the blog-specific theme data (cached at the time it was applied to the blog),
they are culled from the always up-to-date source of the parent theme plugin.

For this reason, you must be cognizant of the fact that anytime you introduce
a new field/property into your theme, all previous versions of that theme
still in use by blogs throughout your installation may use the new field's
value as their default for the property. Since most plugin metadata
tends to be applicable across versions (e.g. the author name and URL) this
usually isn't a problem. Still, I<caveat emptor>...

See MT::Object for further details.

'id' => 'integer not null auto_increment',
'plugin_sig' => 'string(255)',
'ts_id'      => 'string(255)',
'ts_label'   => 'string(255)',
'theme_meta' => 'blob',


=cut
sub set_defaults {
    my $self = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    $self->SUPER::set_defaults();

    return unless $self->ts_id;

    # return unless $self->_cache( 'definition' )
    #            || $self->definition;

    my $definition  = $self->_cache( 'definition' )
                    || $self->_cache( 'definition', $self->definition );
    return unless $definition;

    require Storable;
    my $cached_meta = $self->metadata;
    foreach my $key ( keys %$definition ) {
        # Skip if $cached_meta already has a non-empty value for $key
        # or the corresponding value in $definition is undefined
        next if defined $cached_meta->{$key} and $cached_meta->{$key} ne '';
        next unless defined $definition->{$key};

        # Set the default but use Storable::dclone if the value is a reference
        # so we don't expose the registry to inadvertent modification
        my $pm = $definition->{$key};
        $cached_meta->{$key} = ref( $pm ) ? Storable::dclone($pm) : $pm
    }
}


sub default_templates {
    my $self     = shift;
    my ( $lang ) = @_;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    my $app  = MT->instance;
    my $curr_lang = $app->current_language || 'en_US';
    $lang  ||= $curr_lang;

    my $default_tmpl = $self->_cache( 'default_templates' );
    return $default_tmpl->{$lang} if $default_tmpl->{$lang};

    $app->set_language( $lang );

    require MT::DefaultTemplates;
    my $templates = MT::DefaultTemplates->templates( $self->ts_id ) || [];
    if ( @$templates ) {
        $default_tmpl->{$lang} = $templates;
        $self->_cache( 'default_templates', $default_tmpl );
    }

    $app->set_language( $curr_lang );

    return $templates;
}

##############################################################################

=head2 metadata

This instance method provides a convenient, reliable and intelligent way to
access and modify a theme's metadata stored in the C<theme_meta> property,
the database and (usually) the plugin source as a B<YAML-formatted string>.
This makes working directly with C<theme_meta> onerous since the data must
always be converted between YAML and a usable Perl data structure.

This method B<automatically handles everything for you>, hiding away the
messy details while providing lossless round-trip conversion between Perl data
structure and its serialized YAML form.

This method will always return a reference to a data structure equivalent to
the YAML string (which is usually a hash reference) and can accept either
format when modifying the metadata.

    my $meta        = $theme->metadata;
    $meta->{whatevs}

    my $yaml_string = $theme->metadata({ key => value, key => value });

=cut
sub metadata {
    my $self = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    my $tmeta = $self->column_func( 'theme_meta' );
    ###l4p $logger->debug('tmeta: ', l4mtdump($tmeta));
    ###l4p $logger->debug('tmeta output: ', l4mtdump($self->$tmeta()));
    ###l4p $logger->debug('tmeta output: '.$self->$tmeta());
    ###l4p require ThemeManager::Theme::Util;
    ###l4p $logger->debug('tmeta_output YAML: ', l4mtdump( ThemeManager::Theme::Util::inflate_yaml( $self->$tmeta() ) ));

    if ( @_ ) {   ### STORING ###

        my $val;

        # If we've been provided a reference, we need to serialize it first
        # as a YAML string before storing it in the object
        if ( ref $_[0] ) {
            require ThemeManager::Theme::Util;
            $val = try {
                ThemeManager::Theme::Util::deflate_yaml( $_[0] );
            } catch {
                warn "deflate_yaml error: $_";
                '';
            };
        }
        else {
            $val = $_[0];
        }
        return $self->$tmeta( $val );
    }
    else {  ### RETRIEVING ###

        # Conversely, we must deserialize the YAML-formatted theme_meta value
        # into a reference before returning it
        return try {
            require ThemeManager::Theme::Util;
            ThemeManager::Theme::Util::inflate_yaml( $self->$tmeta() );
        } catch {
            warn "inflate_yaml error: $_";
            {};
        };
    }
}

##############################################################################

=head2 definition

DOCUMENTATION NEEDED

=cut
sub definition {
    my $self = shift;
    Carp::confess( "no TS ID for self ".Dumper($self) ) unless $self->ts_id;
    MT->instance->registry( 'template_sets', $self->ts_id );
}

##############################################################################

=head2 plugin

This method returns the plugin object for the plugin which provides a
specific theme. When called as an instance method, the theme is that
which is represented by the object.

    my $theme  = ThemeManager::Theme->load_from_blog( $terms );
    my $plugin = $theme->plugin;

=head3 ThemeManager::Theme->plugin( $TS_ID )

This method can also be called as a I<class method>, in which case a single
argument must be provided corresponding to the desired theme's C<ts_id>
property.  This is a convenience lookup function which proxies the request to
C<ConfigAssistant::Util::find_theme_plugin>:

    my $plugin = ThemeManager::Theme->plugin( $TS_ID );

=cut
sub plugin {
    my $self = shift;
    my $plugin;
    if ( blessed $self ) {
        $plugin   = $self->_cache('plugin_object');
        $plugin ||= MT->component( $self->plugin_sig )  if $self->plugin_sig;
        $self->_cache( plugin_object => $plugin )       if $plugin;
    }
    else {
        require ConfigAssistant::Util;
        $plugin = ConfigAssistant::Util::find_theme_plugin(@_);
    }
    return $plugin if $plugin;

    my $err  = "Could not load plugin%s for theme %s";
    my @args = blessed $self ? ( $self->plugin_sig, $self->ts_id )
                             : ( '', ' '.$_[0] );
    return $self->error( sprintf( $err, @args ));
}

=head2 is_outdated

DOCUMENTATION NEEDED

=cut
sub is_outdated {
    my $self   = shift;
    my $blog   = $self->blog
        or croak "Method is_outdated called on a theme with no associated blog";

    $self->latest_version > $self->version;
}

=head2 outdated_templates

# Determine what needs to be done to upgrade a theme. This will check if any
# new templates need to be installed or if any existing templates need to be
# updated. The param hash is used to inform the user of what is changing.

    # Create a list of the changed and new templates to be updated.

    # Compare the on-disk templates to the in-DB templates so that we can know
    # if they are being updated, and which ones.

        # Look at this template to determine if any new templates should
        # be installed. If a template is listed in config.yaml but not found
        # in the DB, then tell the user a new template(s) will be installed.

        # This template was not found in the DB.
            # Tell the user about the new templates being installed

            # Look at this template to determine if any existing templates need 
            # to be updated. Compare the actual template (text) to determine if 
            # anything changed. Don't compare the template meta (build type or 
            # caching, for example) because that's something that may have been 
            # purposefully customized, and we don't want to overwrite that.
            # The source template should be translated before trying to compare it 
            # to the already-translated template in the DB.

            # Compare an MD5 hash of the templates to tell if they changed. Skip
            # over any 'widgetset' template type because these have likely changed
            # and we don't want to check them.
                # This template is going to be updated. We want to warn the user
                # of this, so let's compile a list of changed templates
=cut
sub outdated_templates {
    my $self   = shift;
    my $blog   = $self->blog
        or croak "Method outdated_templates called on a theme with no associated blog";
    my $plugin = $self->plugin;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    my $outdated = $self->_cache( 'outdated_templates' );
    return $outdated if $outdated;

    my (@changed_templates, @new_templates);

    # Load the blog's current templates as well as the theme's "default"
    # template set for comparison.
    my $identifier = sub {
        my $tmpl = shift;
        $tmpl->identifier || "tmpl_name_".MT::Util::dirify( $tmpl->name );
    };
    my %blog_tmpls = map { $identifier->($_) => $_ }
                        MT->model('template')->load({ blog_id => $blog->id });

    my @default_tmpls = map { $self->vivify_tmpl( $_ ) }
                            @{ $self->default_templates( $blog->language ) };

    return $self->error( "No default templates were found." )
        unless @default_tmpls;

    require Digest::MD5;

    foreach my $canon ( @default_tmpls ) {

        if ( my $tmpl = $blog_tmpls{ $canon->identifier } ) {

            next if $canon->type          eq 'widgetset'
                 or Digest::MD5::md5_hex($canon->text) eq Digest::MD5::md5_hex($tmpl->text);

            push( @{$outdated->{updated}}, _tmpl_summary($tmpl) );
        }
        else {
            push( @{$outdated->{new}},     _tmpl_summary($canon) );
        }
    }
    return $self->_cache( 'outdated_templates', $outdated );
}

sub updated_templates {
    my $self     = shift;
    my $outdated = $self->outdated_templates() || {};
    return $outdated->{updated} || [];
}

sub new_templates {
    my $self     = shift;
    my $outdated = $self->outdated_templates() || {};
    return $outdated->{new} || [];
}

sub _tmpl_summary {
    my $t = shift;
    {
        name       => $t->name,
        type       => $t->type,
        identifier => $t->identifier,
        $t->id ? ( id => $t->id ) : (),
    }
}

sub vivify_tmpl {
    my $self = shift;
    my $hash = shift;
    my $tmpl = MT->model('template')->new;

    foreach my $key ( keys %$hash ) {
        my $val = $hash->{$key};
        $val    = $val->() if ref $val eq 'CODE';
        if ( $key eq 'text' ) {
            $val = try {
                $self->theme->plugin->translate_templatized(
                    defined $val ? $val : ''
                )
            };
        }
        $key = 'name' if $key eq 'label' ;

        $tmpl->$key( $val )  if ! ref $key
                            and ! ref $val
                            and $tmpl->has_column( $key );
    }
    $tmpl;
}

=head2 version

DOCUMENTATION NEEDED

=cut
sub version {
    my $self   = shift;

    my $theme_meta;
    if ( my $blog = $self->blog ) {
        # Convert the saved YAML back into a hash.
        $theme_meta = try {
            require ThemeManager::Theme::Util;
            ThemeManager::Theme::Util::inflate_yaml( $blog->theme_meta );
        }
        catch {
            warn sprintf "Could not deserialize theme meta for blog ID %d: %s",
                $blog->id, $blog->theme_meta;
            {};
        };
    }
    my $meta_ver = ($theme_meta || {})->{version};
    return $meta_ver ? Perl::Version->new( $meta_ver )
                     : $self->latest_version;
}

=head2 base_version

DOCUMENTATION NEEDED

=cut
sub base_version {
    my $self       = shift;
    my $theme_info = $self->definition || {};
    Perl::Version->new(
        $theme_info->{version} || $self->plugin->version || '0.0.1' );
}
*latest_version = \&base_version;

##############################################################################

=head2 blog

DOCUMENTATION NEEDED

=cut
sub blog { shift->_cache( 'theme_blog' ) }

# This method is a very temporary internal caching mechanism.
# It is going away very soon.
# DO NOT USE IT OUTSIDE OF THIS MODULE!
# We're currently caching:
#       plugin_object => $plugin
#       theme_blog    => $blog
#       definition   => MT->instance->registry( 'template_sets', $ts_id )
sub _cache {
    my $self = shift;
    my $key  = shift;

    blessed $self
        or croak "Object method _cache() invoked as a class method";

    @_ and $self->{__cache}{ $key } = shift;
    return $key ? $self->{__cache}{ $key } : $self->{__cache};
}



sub theme_value {
    my $self            = shift;
    my ( $key, $value ) = @_;
    my $p               = $self->plugin;
    my $app             = MT->instance;
    my $tm              = $app->component('ThemeManager');
    my $dispatch = {
        fallback => {
            theme_label        => sub { $p->name || $p->id || 'Unnamed Theme' },
            theme_description  => sub { $p->description         },
            theme_author_name  => sub { $p->author_name         },
            theme_link         => sub { $p->plugin_link         },
            theme_doc_link     => sub { $p->doc_link            },
            theme_author_link  => sub { $p->author_link         },
            theme_paypal_email => sub { $p->paypal_email        },
            theme_version      => sub { $p->version || '0.0.1'  },
        },
        filter => {
            theme_thumbnail_url => sub {
                $_[0]
                    ? $app->static_path . 'support/plugins/' . $p->id . '/' . shift()
                    : $app->static_path
                      . 'support/plugins/'
                      . $tm->id
                      . '/images/default_theme_thumb-small.png';
            },
            theme_preview_url => sub {
                $_[0]
                    ? $app->static_path . 'support/plugins/' . $p->id . '/' . shift()
                    : $app->static_path
                    . 'support/plugins/'
                    . $tm->id
                    . '/images/default_theme_thumb-large.png';
                
            },
            '*' => sub {
                my $v = shift;
                return '' unless defined $v;

                $v = MT->handler_to_coderef( $v->{code} ) if ref $v eq 'HASH';

                return $v->( $p, @_ ) if ref $v eq 'CODE';

                if ( $v =~ /\.html$/ ) {
                    $v = try {
                        my $tmpl = $p->load_tmpl($v) or die $p->errstr;
                        $tmpl->output();
                    }
                    catch {
                        my $msg = $tm->translate(
                            "Error loading theme $key: ".$_ );
                        warn $msg;
                        MT->log( {
                               level   => MT->model('log')->ERROR(),
                               blog_id => $self->blog->id,
                               message => $msg,
                            }
                        );
                    }
                } ## end if ( $data =~ /\.html$/)
                return $v;
            }
        },
    };

print STDERR "*** VALUE: $value\n";
    $value = try { $dispatch->{fallback}{$key}->() }
        unless defined $value and $value ne '';
print STDERR "*** VALUE: $value\n";
    $value = $dispatch->{filter}{$key}->( $value )
        if exists $dispatch->{filter}{$key};

print STDERR "*** VALUE: $value\n";
    $value = $dispatch->{filter}{'*'}->( $value );
print STDERR "*** VALUE: $value\n";

    return $value;
} ## end sub _return_data

sub thumb_path {
    my $self   = shift;
    my $blog   = $self->blog;
    my $plugin = $self->plugin;
    my $app = MT->instance;
    my $tm = $app->component('ThemeManager');
    my @path = (
                 $app->static_file_path, 'support', 'plugins', $tm->id,
                 'theme_thumbs'
    );
    my $dest_path = File::Spec->catfile(@path);

    # If the destination directory doesn't exist, we need to create it.
    if ( !-d $dest_path ) {

        # FIXME There are hidden bugs here!!!!  This method returns undef on error but the return value isn't checked for that in most places I found.  It's much better to die from a Util method and use eval in the caller
        require MT::FileMgr;
        my $fmgr = MT::FileMgr->new('Local')
          or return $app->error( MT::FileMgr->errstr );
        $fmgr->mkpath($dest_path) or return $app->error( $fmgr->errstr );
    }
    return $dest_path;
}

sub thumb_url {
    my $self   = shift;
    my $blog   = $self->blog;
    my $plugin = $self->plugin;
    my $app = MT->instance;
    my $tm = $app->component('ThemeManager');
    
    # Create the file path to the already-created theme_thumbs file.
    my $file_path
      = File::Spec->catfile( $self->thumb_path(), $blog->id . '.jpg' );

    # Check the theme_thumbs folder for the preview image we need. If it's
    # there then return it. If not, then we need to use the theme default,
    # or fall back to Theme Manager's default.
    if ( $blog->file_mgr->exists($file_path) ) {
        return
          caturl( $app->static_path, 'support', 'plugins', $tm->id,
                  'theme_thumbs', $blog->id . '.jpg' );
    }
    else {
        my $ts_id = $blog->template_set or return;

        # Just use theme_preview_url to craft the URL. Sure, this is really
        # intended for when the user is applying a theme, but it works just
        # fine for our purposes here.
        return
          $self->theme_preview_url(
             $plugin->registry(
                            'template_sets', $self->ts_id, 'preview'
             ),
             $plugin->id
          );
    }
} ## end sub theme_thumb_url


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
