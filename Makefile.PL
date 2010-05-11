use ExtUtils::MakeMaker;

use YAML::Any qw(LoadFile);
my $file = "plugins/ThemeManager/config.yaml";
my $version = LoadFile($file)->{version} ||
    die "No version found in $file";

WriteMakefile(
    NAME            => 'Theme Manager',
    VERSION         => $version,
    DISTNAME        => 'ThemeManager',
);
