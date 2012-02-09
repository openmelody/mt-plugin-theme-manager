package Test::MT::ThemeManager::Data::YAML;

use strict;
use warnings;

use base qw( Test::MT::Data::YAML );

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    ( my $key = lc(__PACKAGE__) ) =~ s{:+}{-}g;
    $self->Key( $key );

    my $data = $self->data;
    $self->data( $data );
}

1;

__END__
