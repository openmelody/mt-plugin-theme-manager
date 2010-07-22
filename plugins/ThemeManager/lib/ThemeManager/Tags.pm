package ThemeManager::Tags;

use strict;

sub template_set_language {
    my ($ctx, $args) = @_;
    my $blog = $ctx->stash('blog');
    return '' unless $blog;
    my $ts_lang = $blog->template_set_language || $blog->language;
    return $ts_lang;
}

1;

__END__
