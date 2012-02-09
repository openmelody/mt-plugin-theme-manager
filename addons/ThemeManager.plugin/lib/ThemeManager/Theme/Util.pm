package ThemeManager::Theme::Util;

use strict;
use warnings;

sub inflate_yaml {
    my $yaml = shift or return {};
    require YAML::Tiny;
    YAML::Tiny->read_string( $yaml )->[0];
}
 
sub deflate_yaml {
    require YAML::Tiny;
    YAML::Tiny->new( +shift || {} )->write_string();
}

1;
