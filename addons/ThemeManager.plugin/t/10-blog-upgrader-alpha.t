package Test::MT::ThemeManager::Setup;

use strict;
use warnings;
use Carp;

use Try::Tiny;
use Data::Dumper::Names;
use FindBin qw($Bin);
use lib ( "$Bin/lib" );

use base qw( Test::MT::ThemeManager::Base );

use Test::MT;
use Test::MT::ThemeManager::Environment;

our $test = __PACKAGE__->new();
$test->init();
# ok( $test->init_db(), 'Initializing DB' );

my $env = Test::MT::ThemeManager::Environment->new();
$env->init();

my $data_class = $env->DataClass;
eval "require $data_class;";
# my $data = $data_class->new();
$env->init_db( $data_class );

my $data = $env->init_data( file => './data/bootstrap_env.yaml' );
my $env_data = $data->install();
my $blog_id   = $env_data->{blogs}{blog_narnia}{values}{id};

my $blog = MT->model('blog')->load( $blog_id );

require MT::App::Test;
require ThemeManager::Util;
my $app = MT::App::Test->construct( Config => $ENV{MT_CONFIG} );
$blog->template_set( 'alpha_theme' );
# $blog->theme_meta( ThemeManager::Util::prepare_theme_meta('alpha_theme') );
$blog->save();

my ( $upgrader, $definition );

subtest "BlogUpgrader object" => sub {
    plan tests => 10;

    use_ok( 'ThemeManager::BlogUpgrader' );
    $upgrader = new_ok( 'ThemeManager::BlogUpgrader'
                            => [{ blog_id => $blog->id }] );
    # return $upgrader->upgrade() || $app->error( $upgrader->errstr );
    is( $upgrader->blog_id(), $blog->id, 'BlogUpgrader blog_id' );
    is( $upgrader->blog->id, $blog->id, 'BlogUpgrader blog object' );

    use_ok( 'ThemeManager::Theme' );
    my $blog_theme     = $blog->theme;
    isa_ok( $blog_theme, 'ThemeManager::Theme' );

    my $upgrader_theme = $upgrader->theme;
    isa_ok( $upgrader_theme, 'ThemeManager::Theme' );

    is( $blog_theme->ts_id, 'alpha_theme', 'blog->theme is alpha_theme' );
    is( $upgrader_theme->ts_id, 'alpha_theme',
        'upgrader->theme is alpha_theme' );

    $definition = $blog_theme->definition;
    is_deeply( $definition, $app->registry( 'template_sets', $blog_theme->ts_id ),
        'Theme definition matches registry');
};


subtest "BlogUpgrader Custom Fields" => sub {
    plan tests => 2;

    my $Field         = MT->model('field');
    my $terms         = { blog_id => $blog->id };
    my @fields_before = $Field->load( $terms );

    is( $upgrader->_refresh_system_custom_fields(), 1,
        'Refreshed custom fields' );

    my @fields_after = $Field->load( $terms );

    is_deeply( \@fields_after, \@fields_before, 'No custom field changes');
};


subtest "BlogUpgrader Field Day Fields" => sub {
    plan tests => 2;
    SKIP: {
        skip "Field Day not installed", 2 unless MT->component('FieldDay');

        my $Field         = MT->model('fdsetting');
        my $terms         = { blog_id => $blog->id };
        my @fields_before = $Field->load( $terms );

        is( $upgrader->_refresh_fd_fields(), 1, 'Refreshed FD fields' );

        my @fields_after = $Field->load( $terms );

        is_deeply( \@fields_after, \@fields_before, 'No Field Day field changes');
    }
};


subtest "BlogUpgrader Templates" => sub {
    plan tests => 9;

    is( $upgrader->_refresh_templates(), 1, 'Refreshed templates' );
    
    my $Template = MT->model('template');
    my $main_index = $Template->load({ identifier => 'main_index',
                                        blog_id   => $blog->id });
    is( $main_index->name,
        $definition->{templates}{index}{main_index}{label}->(),
        'Main index name');

    like( $main_index->text, qr/mt-main-index/, 'Main index text' );


    my $entry_arch = $Template->load({  identifier => 'entry',
                                        blog_id   => $blog->id });
    is( $entry_arch->name,
        $definition->{templates}{individual}{entry}{label}->(),
        'Entry archive name');

    like( $entry_arch->text, qr/mt-entry-archive/, 'Entry archive text' );

    my $TemplateMap = MT->model('templatemap');
    my $map = $TemplateMap->load({  template_id => $entry_arch->id,
                                    blog_id     => $blog->id });
    is( defined($map), 1, 'Templatemap for entry archive' );
    is( $map->archive_type, 'Individual', 'Templatemap archive type');
    is( $map->file_template, '%y/%m/%-f', 'Templatemap file_template');
    is( $map->is_preferred, 1, 'Templatemap is_preferred');
};

subtest "BlogUpgrader Theme Meta" => sub {
    plan tests => 4;

    is( $upgrader->_save_theme_meta(), 1,
        'Saved theme meta' );
    my $theme = $blog->theme;
    is( $theme->ts_id, 'alpha_theme', 'Installed theme ts_id' );
    is( $theme->ts_label, 'Alpha Theme', 'Installed theme label' );
    is( $theme->version, '1.0.1', 'Installed theme version' );

};

done_testing();

# Initialize the database

1;

__END__

