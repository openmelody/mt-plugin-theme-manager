package ThemeManager::Test::Compile;

use FindBin qw($Bin);
use lib ( grep { -d $_ } "$Bin/lib" );
use base qw( Test::MT::ThemeManager::Base );

my @modules;

BEGIN {
    @modules = qw(
        ThemeManager::DashboardWidget
        ThemeManager::Init
        ThemeManager::L10N::en_us
        ThemeManager::L10N
        ThemeManager::Plugin
        ThemeManager::Tags
        ThemeManager::TemplateInstall
        ThemeManager::Theme::Util
        ThemeManager::Theme
        ThemeManager::Tool::Controller
        ThemeManager::Tool
        ThemeManager::Util
        MT::App::Test
        Test::MT
        Test::MT::Base
        Test::MT::Database
        Test::MT::Environment
        Test::MT::Environment::Data
        Test::MT::Environment::Data::YAML
        Test::MT::Environment::Data::Perl
        Test::MT::ThemeManager
        Test::MT::ThemeManager::Base
        Test::MT::ThemeManager::Database
        Test::MT::ThemeManager::Environment
        Test::MT::ThemeManager::Environment::Data::YAML
        CharlieTheme::Plugin
    );
}

use Test::More tests => scalar @modules;

use_ok($_) foreach @modules;

1;

__END__



