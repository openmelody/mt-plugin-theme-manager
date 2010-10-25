package ThemeManager::Init;

use ConfigAssistant::Util qw( find_theme_plugin );
# Sub::Install is included with Config Assistant. Since CA is required for
# Theme Manager, we can rely on it being available.
use Sub::Install;

sub init_app {
    # TODO - This should not have to reinstall a subroutine. It should invoke 
    #        a callback.
    Sub::Install::reinstall_sub( {
        code => \&_translate,
        into => 'MT::Component',
        as   => 'translate',
    });
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
    # This first check for $q is necessary so that run-periodic-tasks
    # doesn't throw errors.
    if ( eval{$q} && $q->param('__mode') ) {
        if ( $q->param('__mode') eq 'setup_theme' ) {
            # The user is applying a new theme.
            $c = find_theme_plugin( $q->param('theme_id') );
            my $template_set_language = $q->param('language') || $app->user->preferred_language;
            if ( eval "require " . $c->l10n_class . ";" ) {
                $h = $c->l10n_class->get_handle( $template_set_language );
            }
        }
        elsif ( $q->param('__mode') eq 'save' && $q->param('_type') eq 'blog' ) {
            # The user is creating a new blog.
            $c = find_theme_plugin( $q->param('template_set') );
            my $template_set_language = $q->param('template_set_language') || $app->user->preferred_language;
            if ( $c && eval "require " . $c->l10n_class . ";" ) {
                $h = $c->l10n_class->get_handle( $template_set_language );
            }
        }
    }

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
                    map { MT::I18N::encode_text( $_, $enc, 'utf-8' ) } @args
                ),
                'utf-8', $enc
            );
        }
    }
    if ( !defined $str ) {
        $str = MT->translate(@_);
    }
    $str;
}

1;

__END__
