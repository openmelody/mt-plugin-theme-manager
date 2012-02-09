package CharlieTheme::Plugin;

use strict;
use Carp qw( croak );
#use MT::Util qw( encode_url );

sub if_twitter {
    my $plugin = MT->component('TwitterCommenters');
    return 0 if !$plugin;
    my $config = $plugin->get_config_hash('system');
    my $tkey = $config->{twitter_consumer_key} || MT->config('TwitterOAuthConsumerKey');
    my $secret = $config->{twitter_consumer_secret} || MT->config('TwitterOAuthConsumerSecret');
    return 1 if ($tkey && $secret);
    return 0;
}

sub if_facebook {
    my $plugin = MT->component('FacebookCommenters');
    return 0 unless $plugin;
    my $blog = MT::App->instance->blog;
    return 0 unless $blog;
    my $fb_api_key = $plugin->get_config_value('facebook_app_key', "blog:" . $blog->id);
    my $fb_api_secret = $plugin->get_config_value('facebook_app_secret', "blog:" . $blog->id);
    return 1 if ( $fb_api_secret && $fb_api_key );
    return 0;
}

sub _hdlr_plugin_installed {
    my($ctx, $args, $cond) = @_;
    my $p = $args->{'plugin'};
    return 1 if (MT->component($p));
    return 0;
}

1;
