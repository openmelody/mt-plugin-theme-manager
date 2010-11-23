package ThemeManager::Theme;

use strict;
use MT;
use base qw( MT::Object );

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

sub class_label {
    MT->translate("Theme");
}

sub class_label_plural {
    MT->translate("Themes");
}

1;

__END__
