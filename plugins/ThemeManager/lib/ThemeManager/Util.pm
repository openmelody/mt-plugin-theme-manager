package ThemeManager::Util;

use strict;
use MT::Util qw(caturl);
use base 'Exporter';

our @EXPORT_OK = qw( theme_label theme_thumbnail_url theme_preview_url
        theme_description theme_author_name theme_author_link 
        theme_paypal_email theme_version theme_link theme_doc_link 
        about_designer theme_docs _theme_thumb_path _theme_thumb_url );

my $app = MT::App->instance();
my $tm  = MT->component('ThemeManager');

sub theme_label {
    # Grab the theme label. If no template set label is supplied then use
    # the parent plugin's name plus the template set ID.
    my ($set, $obj) = @_;
    return $obj->registry('template_sets', $set, 'label')
        ? $obj->registry('template_sets', $set, 'label')
        : eval {$obj->name.': '} . $set;
}

sub theme_thumbnail_url {
    # Build the theme thumbnail URL. If no thumb is supplied, grab the
    # "default" thumbnail.
    my ($set, $obj) = @_;
    my $app = MT->instance;
    return $obj->{registry}->{'template_sets'}->{$set}->{thumbnail}
        ? $app->config('StaticWebPath').'support/plugins/'
            .$obj->id.'/'.$obj->{registry}->{'template_sets'}->{$set}->{thumbnail}
        : $app->config('StaticWebPath').'support/plugins/'
            .$tm->id.'/images/default_theme_thumb-small.png';
}

sub theme_preview_url {
    # Build the theme thumbnail URL. If no thumb is supplied, grab the
    # "default" thumbnail.
    my ($set, $obj) = @_;
    my $app = MT->instance;
    return $obj->{registry}->{'template_sets'}->{$set}->{preview}
        ? $app->config('StaticWebPath').'support/plugins/'
            .$obj->id.'/'.$obj->{registry}->{'template_sets'}->{$set}->{preview}
        : $app->config('StaticWebPath').'support/plugins/'
            .$tm->id.'/images/default_theme_thumb-large.png';
}

sub theme_description {
    # Grab the description. If no template set description is supplied
    # then use the parent plugin's description. This may be a file reference
    # or just some HTML, or even code.
    my ($set, $obj) = @_;
    my $desc = $obj->{registry}->{'template_sets'}->{$set}->{description}
        ? $obj->{registry}->{'template_sets'}->{$set}->{description}
        : eval {$obj->description};
    if (ref $desc eq 'HASH') {
        $desc = MT->handler_to_coderef($desc->{code});
    }
    return $desc->($obj, @_) if ref $desc eq 'CODE';
    if ($desc =~ /\s/) {
        return $desc;
    } else { # no spaces in $about_designer; must be a filename...
        return eval {$obj->load_tmpl($desc)};
    }
}

sub theme_author_name {
    # Grab the author name. If no template set author name, then use
    # the parent plugin's author name.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{author_name}
        ? $obj->{registry}->{'template_sets'}->{$set}->{author_name}
        : eval {$obj->author_name};
}

sub theme_author_link {
    # Grab the author name. If no template set author link, then use
    # the parent plugin's author link.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{author_link}
        ? $obj->{registry}->{'template_sets'}->{$set}->{author_link}
        : eval {$obj->author_link};
}

sub theme_paypal_email {
    # Grab the paypal donation email address. If no template set paypal
    # email address, then it might have been set at the plugin level.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{paypal_email}
        ? $obj->{registry}->{'template_sets'}->{$set}->{paypal_email}
        : eval {$obj->paypal_email};
}

sub theme_version {
    # Grab the version number. If no template set version, then use
    # the parent plugin's version.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{version}
        ? $obj->{registry}->{'template_sets'}->{$set}->{version}
        : eval {$obj->version};
}

sub theme_link {
    # Grab the theme link URL. If no template set theme link, then use
    # the parent plugin's plugin_link.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{theme_link}
        ? $obj->{registry}->{'template_sets'}->{$set}->{theme_link}
        : eval {$obj->plugin_link};
}

sub theme_doc_link {
    # Grab the theme doc URL. If no template set theme doc, then use
    # the parent plugin's doc_link.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{doc_link}
        ? $obj->{registry}->{'template_sets'}->{$set}->{doc_link}
        : eval {$obj->doc_link};
}

sub about_designer {
    # Return the content about the designer. This may be a file reference or 
    # just some HTML, or even code.
    my ($set, $obj) = @_;
    my $about_designer = $obj->{registry}->{'template_sets'}->{$set}->{about_designer};
    return unless $about_designer;
    if (ref $about_designer eq 'HASH') {
        $about_designer = MT->handler_to_coderef($about_designer->{code});
    }
    return $about_designer->($obj, @_) if ref $about_designer eq 'CODE';
    if ( $about_designer && ($about_designer =~ /\s/) ) {
        return "<h3>About the Designer</h3>".$about_designer;
    } else { # no spaces in $about_designer; must be a filename...
        return eval {$obj->load_tmpl($about_designer)};
    }
}

sub theme_docs {
    # Theme Docs are inline-presented documentation.
    my ($set, $obj) = @_;
    my $docs = $obj->{registry}->{'template_sets'}->{$set}->{documentation};
    return unless $docs;
    if (ref $docs eq 'HASH') {
        $docs = MT->handler_to_coderef($docs->{code});
    }
    return $docs->($obj, @_) if ref $docs eq 'CODE';

    if ( $docs && ($docs =~ /\s/) ) {
        return $docs;
    } else { # no spaces in $docs; must be a filename...
        my $app = MT->instance();
        my $tmpl = eval { $obj->load_tmpl($docs) };
        return '' unless $tmpl;
        my $ctx = $tmpl->context;
        $ctx->stash('blog',$app->blog);
        $ctx->stash('blog_id',$app->blog->id);
        my $contents = $app->build_page($tmpl);
        return $contents;
    }
}

sub _theme_thumb_path {
    my @path = ($app->config('StaticFilePath'), 'support', 'plugins', $tm->id, 'theme_thumbs');
    return File::Spec->catfile( @path );
}
sub _theme_thumb_url {
    return caturl( $app->static_path , 'support' , 'plugins', $tm->id, 'theme_thumbs', 
            $app->blog->id.'.jpg' );
}



1;

__END__
