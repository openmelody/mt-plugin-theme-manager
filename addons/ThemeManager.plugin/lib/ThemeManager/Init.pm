package ThemeManager::Init;

use ConfigAssistant::Util qw( find_theme_plugin );

# Sub::Install is included with Config Assistant. Since CA is required for
# Theme Manager, we can rely on it being available.
use Sub::Install;

# TODO Determine whether this SHOULD actually be running for non MT::Apps for
# example upon blog creation through the API

# FIXME At very least, the copied functions from MT 4.261 should be removed
# and replaced with a method that overrides the internal methods, evaluates
# the environment and either runs or passes back to the original method

# FIXME Overriding the core translate function of pretty much every component
# is overkill and I'm not sure why the individual plugins own L10N handles
# won't work perfectly. What's more, the handles are stored in the MT->request
# object and can be modified before and after the internal methods if nothing
# else.

sub init_app {
    my ( $cb, $app ) = @_;
    return
      unless $app->isa('MT::App')
          && ( $app->can('query') || $app->can('param') );

    # TODO - This should not have to reinstall a subroutine. It should invoke
    #        a callback.
    Sub::Install::reinstall_sub(
         { code => \&_translate, into => 'MT::Component', as => 'translate', }
    );

    # In Designer Mode, theme upgrades should happen automatically.
    _automatic_theme_upgrade();
}

sub _translate {

    # This is basically lifted right from MT::CMS::Template (from Movable Type
    # version 4.261), with some necessary changes to work with Theme Manager.
    my $c       = shift;
    my $handles = MT->request('l10n_handle') || {};
    my $h       = $handles->{ $c->id };
    unless ($h) {
        my $lang = MT->current_language || MT->config->DefaultLanguage;
        if ( eval "require " . $c->l10n_class . ";" ) {
            $h = $c->l10n_class->get_handle($lang);
        }
        else {
            $h = MT->language_handle;
        }
        $handles->{ $c->id } = $h;
        MT->request( 'l10n_handle', $handles );
    }

    # If a blog is being created or a new theme is being applied, we need to
    # handle the template translation in this special case.
    # $c is currently set to Theme Manager, which is incorrect: we need
    # the plugin component of the template set being installed. That way,
    # $c->l10n_class->get_handle() knows the correct place to look for
    # translations.
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    if ( eval {$q} && $q->param('__mode') ) {
        if ( $q->param('__mode') eq 'setup_theme' ) {

            # The user is applying a new theme.
            $c = find_theme_plugin( $q->param('theme_id') );
            my $template_set_language = $q->param('language')
              || $app->user->preferred_language;
            if ( eval "require " . $c->l10n_class . ";" ) {
                $h = $c->l10n_class->get_handle($template_set_language);
            }
        }
        elsif (    $q->param('__mode') eq 'save'
                && $q->param('_type') eq 'blog' )
        {

            # The user is creating a new blog.
            $c = find_theme_plugin( $q->param('template_set') );
            my $template_set_language = $q->param('template_set_language')
              || $app->user->preferred_language;
            if ( $c && eval "require " . $c->l10n_class . ";" ) {
                $h = $c->l10n_class->get_handle($template_set_language);
            }
        }
    } ## end if ( eval {$q} && $q->param...)

    my ( $format, @args ) = @_;
    foreach (@args) {
        $_ = $_->() if ref($_) eq 'CODE';
    }
    my $enc = MT->instance->config('PublishCharset');
    my $str;
    if ($h) {
        if ( $enc =~ m/utf-?8/i ) {
            $str = $h->maketext( $format, @args );
        }
        else {
            $str = MT::I18N::encode_text(
                $h->maketext(
                    $format,
                    map {
                        MT::I18N::encode_text( $_, $enc, 'utf-8' )
                      } @args
                ),
                'utf-8',
                $enc
            );
        }
    }
    if ( !defined $str ) {
        $str = MT->translate(@_);
    }
    $str;
} ## end sub _translate

# In Designer Mode, theme upgrades should happen automatically.
sub _automatic_theme_upgrade {
    my @blogs = MT->model('blog')->search_by_meta(
        'theme_mode', # Look in the theme_mode blog meta field...
        'designer',   # ...for any blog using Designer Mode.
    )
        or return 1; # Just quit if there are none.

    my ($app) = MT->instance;

    # The following blogs are using Designer Mode. Set the necessary variables
    # then use the ThemeManager::TemplateInstall::_do_theme_upgrade method to 
    # perform the upgrade.
    foreach my $blog (@blogs) {
        my $plugin = find_theme_plugin( $blog->template_set );
        my $new_theme_meta = $app->registry( 'template_sets', $blog->template_set);
        my $param = {};

        # Check which templates are new and which existing templates need 
        # updating.
        require ThemeManager::TemplateInstall;
        $param = ThemeManager::TemplateInstall::_upgrade_check_templates({
            param  => $param,
            blog   => $blog,
            plugin => $plugin,
        });

        # Check if Custom Fields and Field Day fields exist with this theme and
        # note that should will be (potentially) updated. These should be more
        # thoroughly checked, like the templates...
        $param = ThemeManager::TemplateInstall::_upgrade_check_fields({
            param          => $param,
            new_theme_meta => $new_theme_meta,
        });

        # In the theme upgrade GUI, the theme identifier is the only thing 
        # passed into the new_templates array, so that's all we need here, too.
        my (@new_templates, @changed_templates);
        foreach my $tmpl ( @{ $param->{new_templates} } ) {
            push @new_templates, $tmpl->{identifier};
        }

        # Changed templates don't need to be updated with the theme upgrade 
        # process because we're in Developer Mode: the templates are already
        # linked to the file system, and therefore are already picking up
        # any changes to the template.
        # foreach my $tmpl ( @{ $param->{changed_templates} } ) {
        #     push @changed_templates, $tmpl->{identifier};
        # }

        # Actually do the upgrade, based on all of the above submitted info.
        my @results = ThemeManager::TemplateInstall::_do_theme_upgrade({
            blog              => $blog,
            plugin            => $plugin,
            updated_cf_fields => $param->{updated_cf_fields},
            updated_fd_fields => $param->{updated_fd_fields},
            new_templates     => \@new_templates,
            changed_templates => \@changed_templates,
        });

        # Because we're in Designer Mode, all new templates should be linked
        # to the filesystem.
        foreach my $new_template (@new_templates) {
            my ($tmpl) = MT->model('template')->load({
                blog_id    => $blog->id,
                identifier => $new_template,
            })
                or next MT->log({
                    blog_id => $blog->id,
                    level => MT->model('log')->WARNING(),
                    message => 'The template "' . $new_template 
                        . '" could not be found!',
                });

            ThemeManager::TemplateInstall::_link_template({
                tmpl    => $tmpl,
                plugin  => $plugin,
                blog_id => $blog->id,
                ts_id   => $blog->template_set,
            });
        }
    }
}

1;

__END__
