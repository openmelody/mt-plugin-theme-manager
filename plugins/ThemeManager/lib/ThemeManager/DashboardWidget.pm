package ThemeManager::DashboardWidget;

use ThemeManager::Util qw( theme_label theme_description theme_author_name 
        theme_author_link theme_version theme_link theme_doc_link theme_docs 
        unserialize_theme_meta );

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

                # Unserializing converts the gobblety-gook back into a hash.
                my $theme_meta = unserialize_theme_meta( $app->blog->theme_meta );

                $param->{theme_label}       = theme_label($theme_meta->{label}, $plugin);
                $param->{theme_description} = theme_description($theme_meta->{description}, $plugin);
                $param->{theme_author_name} = theme_author_name($theme_meta->{author_name}, $plugin);
                $param->{theme_author_link} = theme_author_link($theme_meta->{author_link}, $plugin);
                $param->{theme_link}        = theme_link($theme_meta->{theme_link}, $plugin);
                $param->{theme_doc_link}    = theme_doc_link($theme_meta->{theme_docs}, $plugin);
                $param->{theme_version}     = theme_version($theme_meta->{version}, $plugin);
                $param->{theme_mini}        = ThemeManager::Plugin::_make_mini();
            },
            template => 'dashboard_widget.mtml',
            condition => sub { 
                my ($page, $scope) = @_;
                return 1 if ($scope ne 'system');
            },
            singular => 1,
        },
    };
}

1;

__END__
