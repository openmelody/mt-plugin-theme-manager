package ThemeManager::DashboardWidget;

use strict;
use MT;

sub widget {
    return {
        theme_manager => {
            label    => 'Theme Dashboard Widget',
#            plugin   => $ThemeManager,
            handler  => sub {
                my ($app, $tmpl, $param) = @_;

                my $ts_id = $app->blog->template_set;
                use ConfigAssistant::Util;
                my $plugin = ConfigAssistant::Util::find_theme_plugin($ts_id);

                $param->{theme_label}       = ThemeManager::Util::theme_label($ts_id, $plugin);
                $param->{theme_description} = ThemeManager::Util::theme_description($ts_id, $plugin);
                $param->{theme_author_name} = ThemeManager::Util::theme_author_name($ts_id, $plugin);
                $param->{theme_author_link} = ThemeManager::Util::theme_author_link($ts_id, $plugin);
                $param->{theme_link}        = ThemeManager::Util::theme_link($ts_id, $plugin);
                $param->{theme_doc_link}    = ThemeManager::Util::theme_docs($ts_id, $plugin);
                $param->{theme_version}     = ThemeManager::Util::theme_version($ts_id, $plugin);
                $param->{theme_mini}        = ThemeManager::Plugin::_make_mini();
            },
            template => 'dashboard_widget.mtml',

            singular => 1,
        },
    };
}

1;

__END__
