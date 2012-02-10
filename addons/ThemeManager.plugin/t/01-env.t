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

our $test = new_ok(__PACKAGE__);
ok( $test->init(), 'Test initialization' );
# ok( $test->init_db(), 'Initializing DB' );

my ($env);

subtest "Environment initialization" => sub {
    plan tests => 3;
    use_ok('Test::MT::ThemeManager::Environment');
    $env = new_ok( 'Test::MT::ThemeManager::Environment' );
    is( $env->init(), $env, 'Environment init succeeded' );
};


subtest "Path tests" => sub {
    plan tests => 23;
    my %path_tests = (
        MT_HOME     => $env->mt_dir(),
        MT_TEST_DIR => $env->test_dir(),
        MT_CONFIG   => $env->config_file(),
        MT_DS_DIR   => $env->ds_dir(),
        MT_REF_DIR  => $env->ref_dir(),
        db_file     => $env->db_file(),
    );

    foreach my $key ( keys %path_tests ) {
        is( defined( $path_tests{$key} ), 1, "$key accessor is defined" );
        is( File::Spec->file_name_is_absolute( $path_tests{$key} ), 1,
            "$key is absolute path");
        is( -e $path_tests{$key}, 1, "$key exists on filesystem" );
        next if $key eq 'db_file';
        is( $path_tests{$key}, $ENV{$key}, "$key accessor output is same as \%ENV" );
    }

};

note explain $env;

subtest "Database initialization" => sub {
    plan tests => 5;
    my ($data_class, $data_key);
    is( defined( $data_class = $env->DataClass ), 1,
        '$env DataClass defined: '.$data_class );
    use_ok( $data_class );
    my $data = new_ok( $data_class );
    is( defined( $data_key = $data->Key ), 1, 'Dataclass has Key: '.$data_key);

    is( $env->init_db( $data_class ), $env, 'New database initialized' );
};

subtest "Database connection and default content" => sub {
    plan tests => 8;
    ok( my @blogs = MT->model('blog')->load(), 'Loaded blogs' );
    ok( my @users = MT->model('author')->load(), 'Loaded authors' );
    is( scalar @users, 1, 'One user' );
    is( scalar @blogs, 1, 'One blog' );
    isa_ok( my $user = shift @users, 'MT::Author' );
    isa_ok( my $blog = shift @blogs, 'MT::Blog' );
    is( $user->name, 'Melody', 'First user is Melody');
    is( $blog->name, 'First Blog', 'First blog is First Weblog');
};

subtest "Data initialization" => sub {
    plan tests => 4;
    my $data = $env->init_data( file => './data/bootstrap_env.yaml' );
    isa_ok( $data, $env->DataClass );
    can_ok( $data, qw( init install data env_data ) );

    my $env_data = $data->install();
    is( ref $env_data, 'HASH', 'Data installed');
    isnt( scalar keys %$env_data, 0, 'Environment data is populated' );
};

my ( $app, $blog );

subtest "Test app and blog setup" => sub {
    plan tests => 8;
    my $env_data  = $env->data->env_data;
    my $blog_id   = $env_data->{blogs}{blog_narnia}{values}{id};
    my $blog_name = $env_data->{blogs}{blog_narnia}{values}{name};
    is( ref $env_data, 'HASH', 'Env data loaded' );
    is( defined($blog_id), 1, 'Got blog ID '.$blog_id );

    $blog = MT->model('blog')->load( $blog_id );
    isa_ok( $blog, 'MT::Blog' );
    is( $blog->name, $blog_name, 'Blog name' );
    is( $blog->template_set, 'mt_blog', 'Blog template set' );

    use_ok( 'MT::App::Test' );
    $app = MT::App::Test->construct( Config => $ENV{MT_CONFIG} );
    isa_ok( $app, 'MT::App::Test' );
        explain [keys %{ $app->registry( 'template_sets' ) }];

    $blog->template_set( 'alpha_theme' );
    require ThemeManager::Util;
    $blog->theme_meta( ThemeManager::Util::prepare_theme_meta('alpha_theme') );
    explain $blog->theme_meta;
    is( $blog->save(), 1, 'Blog saved with new template sets' );
};


done_testing();

1;

__END__

