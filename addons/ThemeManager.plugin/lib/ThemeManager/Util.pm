package ThemeManager::Util;

use strict;
use warnings;
use MT::Util qw(caturl);
use ConfigAssistant::Util qw( find_theme_plugin );
use base 'Exporter';

our @EXPORT_OK = qw( theme_label theme_thumbnail_url theme_preview_url
  theme_description theme_author_name theme_author_link
  theme_paypal_email theme_version theme_link theme_doc_link
  theme_about_designer theme_documentation theme_thumb_path theme_thumb_url
  prepare_theme_meta );

use MT;

# TODO - this looks very broken to me. NO global variables.
my $app = MT->instance;
my $tm  = MT->component('ThemeManager');

sub theme_label {

    # Grab the theme label. If no template set label is supplied then use
    # the parent plugin's name plus the template set ID.
    my ( $data, $obj ) = @_;

    # If the description wasn't found in the theme meta, return the plugin
    # description (if present).
    $data = eval { $obj->name || $obj->id } unless $data;

    # If no name can be found for the theme, just give it a label.
    $data = 'Unnamed Theme' unless $data;
    return _return_data( $data, $obj );
}

sub theme_thumbnail_url {

    # Build the theme thumbnail URL. If no thumb is supplied, grab the
    # "default" thumbnail.
    my ( $thumb_path, $obj_id ) = @_;
    my $app = MT->instance;
    return
      eval {$thumb_path}
      ? $app->static_path . 'support/plugins/' . $obj_id . '/' . $thumb_path
      : $app->static_path
      . 'support/plugins/'
      . $tm->id
      . '/images/default_theme_thumb-small.png';
}

sub theme_preview_url {

    # Build the theme thumbnail URL. If no thumb is supplied, grab the
    # "default" thumbnail.
    my ( $thumb_path, $obj_id ) = @_;
    my $app = MT->instance;
    return
      eval {$thumb_path}
      ? $app->static_path . 'support/plugins/' . $obj_id . '/' . $thumb_path
      : $app->static_path
      . 'support/plugins/'
      . $tm->id
      . '/images/default_theme_thumb-large.png';
}

sub theme_description {

    # Grab the description. If no template set description is supplied
    # then use the parent plugin's description. This may be a file reference
    # or just some HTML, or even code.
    my ( $data, $obj ) = @_;

    # If the description wasn't found in the theme meta, return the plugin
    # description (if present).
    $data = eval { $obj->description } unless $data;
    return _return_data( $data, $obj );
}

sub theme_author_name {

    # Grab the author name. If no template set author name, then use
    # the parent plugin's author name.
    my ( $data, $obj ) = @_;

    # If the author name wasn't found in the theme meta, return the plugin
    # author name (if present).
    $data = eval { $obj->author_name } unless $data;
    return _return_data( $data, $obj );
}

sub theme_author_link {

    # Grab the author name. If no template set author link, then use
    # the parent plugin's author link.
    my ( $data, $obj ) = @_;

    # If the author name wasn't found in the theme meta, return the plugin
    # author name (if present).
    $data = eval { $obj->author_link } unless $data;
    return _return_data( $data, $obj );
}

sub theme_paypal_email {

    # Grab the paypal donation email address. If no template set paypal
    # email address, then it might have been set at the plugin level.
    my ( $data, $obj ) = @_;

    # The paypal_email may be specified at the theme level, or at the plugin
    # level. (It may be specified at the plugin level if the theme contains
    # many themes, for example.)
    $data = eval { $obj->paypal_email } unless $data;
    return _return_data( $data, $obj );
}

# Grab the version number. If no template set version, then use the parent 
# plugin's version. If that's not set, just make up a value to use.
sub theme_version {
    my ( $data, $obj ) = @_;

    # If no version was found in the theme meta, return the plugin
    # version (if present).
    $data = defined $data 
        ? $data                  # $data is valid!
        : eval { $obj->version } # Is their a plugin version?
        ? eval { $obj->version } # Yes, use the plugin version
        : '0.0.1';               # Make up a value because none was available.

    return _return_data( $data, $obj );
}

sub theme_link {

    # Grab the theme link URL. If no template set theme link, then use
    # the parent plugin's plugin_link.
    my ( $data, $obj ) = @_;

    # If no theme link was found in the theme meta, return the plugin
    # link (if present).
    $data = eval { $obj->plugin_link } unless $data;
    return _return_data( $data, $obj );
}

sub theme_doc_link {

    # Grab the theme doc URL. If no template set theme doc, then use
    # the parent plugin's doc_link.
    my ( $data, $obj ) = @_;

    # If no documentation link was found in the theme meta, return the
    # plugin documentation link (if present).
    $data = eval { $obj->doc_link } unless $data;
    return _return_data( $data, $obj );
}

sub theme_about_designer {

    # Return the content about the designer. This may be a file reference or
    # just some HTML, or even code.
    my ( $data, $obj ) = @_;
    return _return_data( $data, $obj );
}

# Theme Docs are inline-presented documentation.
sub theme_documentation {
    my ( $data, $obj ) = @_;
    return _return_data( $data, $obj );
}

sub _return_data {

    # The theme may keys may have been specified inline, or they could be
    # code or template references. Just grab the final result and return it.
    my ( $data, $obj ) = @_;

    # It's possible their is no valid $data supplied, so deal with that.
    return '' unless defined $data;
    if ( ref $data eq 'HASH' ) {
        $data = MT->handler_to_coderef( $data->{code} );
    }
    return $data->( $obj, @_ ) if ref $data eq 'CODE';
    if ( $data =~ /\.html$/ ) {

        # Ends with .html so this must be a filename/template.
        eval {
            my $tmpl = $obj->load_tmpl($data) or die $obj->errstr;
            $data = $tmpl->output();
        };
        if ($@) {
            $@ and warn $@;    # TODO - error message
            MT->log( {
                   level   => MT->model('log')->ERROR(),
                   blog_id => MT->instance->blog->id,
                   message =>
                     $tm->translate(
                       'Theme Manager could not load the documentation for this theme: '
                         . $@
                     ),
                }
            );
        }
    } ## end if ( $data =~ /\.html$/)
    return $data;
} ## end sub _return_data

sub theme_thumb_path {
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

sub theme_thumb_url {

    # The theme thumbnail/preview image was previously generated by the
    # site_preview_image Task. Of course, this requires that
    # run-periodic-tasks have run already. If it hasn't run, a thumbnail
    # preview may not be created yet. If that's the case, we should fall
    # back to the theme preview image. If that's not available, fallback to
    # the Theme Manager default preview image.
    my $blog = $app->blog;

    # Create the file path to the already-created theme_thumbs file.
    my $file_path
      = File::Spec->catfile( theme_thumb_path(), $blog->id . '.jpg' );

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
        my $plugin = find_theme_plugin($ts_id) or return;

        # Just use theme_preview_url to craft the URL. Sure, this is really
        # intended for when the user is applying a theme, but it works just
        # fine for our purposes here.
        return
          theme_preview_url(
                             $plugin->registry(
                                            'template_sets', $ts_id, 'preview'
                             ),
                             $plugin->id
          );
    }
} ## end sub theme_thumb_url

sub prepare_theme_meta {

    # Prepare the theme meta by ensuring that default values exist.
    my ($ts_id) = @_;
    my $theme_meta = {};

    my $plugin = find_theme_plugin($ts_id);

    # If the plugin couldn't be loaded that means it's been uninstalled or
    # disabled, and so we can't load any theme meta. Just give it a label
    # and give up.
    if ( !$plugin ) {
        $theme_meta->{label} = 'Unknown Theme';
        return $theme_meta;
    }

    # Grab the existing theme meta
    $theme_meta = $plugin->registry( 'template_sets', $ts_id );

    # Place the final theme meta into $meta. We need to grab and save only
    # the meta that we need, because code references will cause YAML::Tiny
    # to fail.
    my $meta = {};

    # We've grabbed the theme meta already, but we can't be sure
    # that all fields have been filled out; fallbacks may be used.
    # Check the important fields and create fallbacks if needed.
    $meta->{label} = theme_label( $theme_meta->{label}, $plugin );
    $meta->{description}
      = theme_description( $theme_meta->{description}, $plugin );
    $meta->{author_name}
      = theme_author_name( $theme_meta->{author_name}, $plugin );
    $meta->{author_link}
      = theme_author_link( $theme_meta->{author_link}, $plugin );
    $meta->{paypal_email}
      = theme_paypal_email( $theme_meta->{paypal_email}, $plugin );
    $meta->{version} = theme_version( $theme_meta->{version}, $plugin );
    $meta->{theme_link} = theme_link( $theme_meta->{theme_link}, $plugin );
    $meta->{theme_doc_link}
      = theme_doc_link( $theme_meta->{theme_doc_link}, $plugin );
    $meta->{thumbnail}     = $theme_meta->{thumbnail};
    $meta->{preview}       = $theme_meta->{preview};
    $meta->{documentation} = $theme_meta->{documentation};
    $meta->{about_designer}
      = theme_about_designer( $theme_meta->{about_designer}, $plugin );

    return $meta;
} ## end sub prepare_theme_meta

1;

__END__
