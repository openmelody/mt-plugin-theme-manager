package Perl::Version;

use warnings;
use strict;
use Carp;
use Scalar::Util qw( blessed );

our $VERSION = '1.011';

use overload (
  '""'  => \&stringify,
  '<=>' => \&vcmp,
  'cmp' => \&vcmp,
);

use constant REGEX => qr/ ( (?i: Revision: \s+ ) | v | )
                          ( \d+ (?: [.] \d+)* )
                          ( (?: _ \d+ )? ) /x;

use constant MATCH => qr/ ^ ( \s* ) @{[ REGEX ]} ( \s* ) $ /x;

my %NORMAL_FORMAT = (
  prefix => 'v',
  printf => ['%d'],
  extend => '.%d',
  alpha  => '_%02d',
  suffix => '',
  fields => 3,
);

my %NUMERIC_FORMAT = (
  prefix => '',
  printf => [ '%d', '.%03d' ],
  extend => '%03d',
  alpha  => '_%02d',
  suffix => '',
  fields => 2,
);

my %COMPONENT_NAME;

BEGIN {
  %COMPONENT_NAME = (
    revision   => 0,
    version    => 1,
    subversion => 2
  );

  # Make accessors
  my @fields = ( keys %COMPONENT_NAME, qw( alpha ) );

  no strict 'refs';

  for my $field ( @fields ) {
    *$field = sub {
      my $self = shift;
      return $self->component( $field, @_ );
    };

    my $inc_func = "inc_$field";
    *$inc_func = sub {
      my $self = shift;
      return $self->increment( $field );
    };
  }
}

sub new {
  my $class = shift;
  my $self 
   = bless {}, ref $class
   || $class
   || croak "new must be called as a class or object method";

  $self->{version} = [0];

  $self->_parse( @_ ) if @_;

  return $self;
}

sub _resolve_component_name {
  my $self = shift;
  my $name = shift;

  if ( $name =~ /^-?\d+$/ ) {
    # Allow negative subscripts
    $name += $self->components if $name < 0;
    return $name;
  }

  croak "Unknown component name: $name"
   unless exists $COMPONENT_NAME{ lc( $name ) };

  return $COMPONENT_NAME{ lc( $name ) };
}

sub _guess_num_format {
  my $self = shift;
  my $num  = shift;

  if ( $num =~ m{ ^ 0 \d }x ) {
    return '%0' . length( $num ) . 'd';
  }

  return '%d';
}

sub _parse {
  my $self = shift;

  # Check for vstring before anything else happens
  if ( $] >= 5.008_001 && Scalar::Util::isvstring $_[0] ) {
    $self->{format} = {%NORMAL_FORMAT};
    my @parts = map { ord } split //, shift;
    $self->{version} = \@parts;
    return;
  }

  my $version = join( ' ', map { "$_" } @_ );

  croak "Illegal version string: $version"
   unless $version =~ MATCH;

  my $format = { fields => 1 };
  my ( $pad, $pfx, $ver, $alp, $sfx ) = ( $1, $2, $3, $4, $5 );

  # Decode version into format
  $format->{prefix} = $pad . $pfx;
  $format->{suffix} = $sfx;

  my @parts = split( /[.]/, $ver );
  my @ver = ( shift( @parts ) + 0 );

  my @fmt = ( $self->_guess_num_format( $ver[0] ) );

  if ( @parts == 1 && length( $parts[0] ) >= 3 ) {

    my $threes = pop @parts;
    my @cluster = ( $threes =~ /(\d{1,3})/g );

    # warn "# $threes <", join( '>, <', @cluster ), ">\n";
    push @fmt, map { $self->_guess_num_format( $_ ) } @cluster;
    $fmt[1] = '.' . $fmt[1];
    $format->{extend} = '%03d';

    push @parts, map { 0 + $_ } @cluster;
  }
  else {

    # Parts with leading zeros
    my @lz = grep { m{ ^ 0 \d }x } @parts;

    # Work out how many different lengths we have
    my %le = map { length( $_ ) => 1 } @parts;

    if ( @lz && keys %le == 1 ) {
      push @fmt,
       ( '.' . $self->_guess_num_format( shift @lz ) ) x @parts;
    }
    else {
      push @fmt, map { '.' . $self->_guess_num_format( $_ ) } @parts;
    }

    $format->{extend} = ( @parts ? '' : '.' ) . $fmt[-1];
  }

  $format->{printf} = \@fmt;

  if ( length( $alp ) ) {
    die "Badly formatted alpha got through"
     unless $alp =~ m{ _ (\d+) }x;

    my $alpha = $1;

    $self->{alpha}   = $alpha + 0;
    $format->{alpha} = '_' . $self->_guess_num_format( $alpha );
  }
  else {
    $format->{alpha} = $NORMAL_FORMAT{alpha};
  }

  $self->{format} = $format;

  push @ver, map { $_ + 0 } @parts;

  $self->{version} = \@ver;

  return;
}

sub _format {
  my $self   = shift;
  my $format = shift;

  my @result = ();

  my @parts = @{ $self->{version} };
  my @fmt   = @{ $format->{printf} };

  push @parts, 0 while @parts < $format->{fields};

  # Adjust the format to be the same length as the number of fields
  pop @fmt while @fmt > @parts;
  push @fmt, $format->{extend} while @parts > @fmt;

  my $version
   = ( $format->{prefix} )
   . sprintf( join( '', @fmt ), @parts )
   . ( $format->{suffix} );

  $version .= sprintf( $format->{alpha}, $self->{alpha} )
   if defined $self->{alpha};

  push @result, $version;

  return join( ' ', @result );
}

sub stringify {
  my $self = shift;
  return $self->_format( $self->{format} || \%NORMAL_FORMAT );
}

sub normal {
  return shift->_format( \%NORMAL_FORMAT );
}

sub numify {
  return shift->_format( \%NUMERIC_FORMAT );
}

sub is_alpha {
  my $self = shift;
  return exists $self->{alpha};
}

sub vcmp {
  my ( $self, $other, $rev ) = @_;

  # Promote to object
  $other = __PACKAGE__->new( $other ) unless ref $other;

  croak "Can't compare with $other"
   unless blessed $other && $other->isa( __PACKAGE__ );

  return $other->vcmp( $self, 0 ) if $rev;

  my @this = @{ $self->{version} };
  my @that = @{ $other->{version} };

  push @this, 0 while @this < @that;
  push @that, 0 while @that < @this;

  while ( @this ) {
    if ( my $cmp = ( shift( @this ) <=> shift( @that ) ) ) {
      return $cmp;
    }
  }

  return ( $self->{alpha} || 0 ) <=> ( $other->{alpha} || 0 );
}

sub components {
  my $self = shift;

  if ( @_ ) {
    my $fields = shift;

    if ( ref $fields eq 'ARRAY' ) {
      $self->{version} = [@$fields];
    }
    else {
      croak "Can't set the number of components to 0"
       unless $fields;

      # Adjust the number of fields
      pop @{ $self->{version} }, while @{ $self->{version} } > $fields;
      push @{ $self->{version} }, 0,
       while @{ $self->{version} } < $fields;
    }
  }
  else {
    return @{ $self->{version} };
  }
}

sub component {
  my $self  = shift;
  my $field = shift;

  defined $field or croak "You must specify a component number";

  if ( lc( $field ) eq 'alpha' ) {
    if ( @_ ) {
      my $alpha = shift;
      if ( $alpha ) {
        $self->{alpha} = $alpha;
      }
      else {
        delete $self->{alpha};
      }
    }
    else {
      return $self->{alpha} || 0;
    }
  }
  else {
    $field = $self->_resolve_component_name( $field );
    my $fields = $self->components;

    if ( @_ ) {
      if ( $field >= $fields ) {

        # Extend array if necessary
        $self->components( $field + 1 );
      }

      $self->{version}->[$field] = shift;
    }
    else {
      return unless $field >= 0 && $field < $fields;
      return $self->{version}->[$field];
    }
  }
}

sub increment {
  my $self   = shift;
  my $field  = shift;
  my $fields = $self->components;

  if ( lc( $field ) eq 'alpha' ) {
    $self->alpha( $self->alpha + 1 );
  }
  else {
    $field = $self->_resolve_component_name( $field );

    croak "Component $field is out of range 0..", $fields - 1
     if $field < 0 || $field >= $fields;

    # Increment the field
    $self->component( $field, $self->component( $field ) + 1 );

    # Zero out any following fields
    while ( ++$field < $fields ) {
      $self->component( $field, 0 );
    }
    $self->alpha( 0 );
  }
}

sub set {
  my $self  = shift;
  my $other = shift;

  $other = __PACKAGE__->new( $other ) unless ref $other;

  my @comp = $other->components;

  $self->components( \@comp );
  $self->alpha( $other->alpha );
}

1;
__END__

=head1 NAME

Perl::Version - Parse and manipulate Perl version strings

=head1 VERSION

This document describes Perl::Version version 1.011

=head1 SYNOPSIS

    use Perl::Version;

    # Init from string
    my $version = Perl::Version->new( '1.2.3' );

    # Stringification preserves original format
    print "$version\n";                 # prints '1.2.3'

    # Normalised
    print $version->normal, "\n";       # prints 'v1.2.3'

    # Numified
    print $version->numify, "\n";       # prints '1.002003'

    # Explicitly stringified
    print $version->stringify, "\n";    # prints '1.2.3'

    # Increment the subversion (the third component)
    $version->inc_subversion;

    # Stringification returns the updated version formatted
    # as the original was
    print "$version\n";                 # prints '1.2.4'

    # Normalised
    print $version->normal, "\n";       # prints 'v1.2.4'

    # Numified
    print $version->numify, "\n";       # prints '1.002004'

    # Refer to subversion component by position ( zero based )
    $version->increment( 2 );

    print "$version\n";                 # prints '1.2.5'

    # Increment the version (second component) which sets all
    # components to the right of it to zero.
    $version->inc_version;

    print "$version\n";                 # prints '1.3.0'

    # Increment the revision (main version number)
    $version->inc_revision;

    print "$version\n";                 # prints '2.0.0'

    # Increment the alpha number
    $version->inc_alpha;

    print "$version\n";                 # prints '2.0.0_001'

=head1 DESCRIPTION

Perl::Version provides a simple interface for parsing, manipulating and
formatting Perl version strings.

Unlike version.pm (which concentrates on parsing and comparing version
strings) Perl::Version is designed for cases where you'd like to
parse a version, modify it and get back the modified version formatted
like the original.

For example:

    my $version = Perl::Version->new( '1.2.3' );
    $version->inc_version;
    print "$version\n";

prints

    1.3.0

whereas

    my $version = Perl::Version->new( 'v1.02.03' );
    $version->inc_version;
    print "$version\n";

prints

    v1.03.00

Both are representations of the same version and they'd compare equal
but their formatting is different.

Perl::Version tries hard to guess and recreate the format of the
original version and in most cases it succeeds. In rare cases the
formatting is ambiguous. Consider

    1.10.03

Do you suppose that second component '10' is zero padded like the third
component? Perl::Version will assume that it is:

    my $version = Perl::Version->new( '1.10.03' );
    $version->inc_revision;
    print "$version\n";
    
will print

    2.00.00

If all of the components after the first are the same length (two
characters in this case) and any of them begins with a zero
Perl::Version will assume that they're all zero padded to the
same length.

The first component and any alpha suffix are handled separately. In each
case if either of them starts with a zero they will be zero padded to
the same length when stringifying the version.

=head2 Version Formats

Perl::Version supports a few different version string formats. 

=over

=item Z<> 1, 1.2

Versions that look like a number. If you pass a numeric value its string
equivalent will be parsed:

    my $version = Perl::Version->new( 1.2 );
    print "$version\n";

prints

    1.2

In fact there is no special treatment for versions that resemble decimal
numbers. This is worthy of comment only because it differs from
version.pm which treats actual numbers used as versions as a special
case and performs various transformations on the stored version.

=item Z<> 1.2.3, 1.2.3.4

Simple versions with three or more components.

=item Z<> v1.2.3

Versions with a leading 'v'.

=item Z<> 5.008006

Fielded numeric versions. You'll likely have seen this in relation to
versions of Perl itself. If a version string has a single decimal point
and the part after the point is three more more digits long components
are extracted from each group of three digits in the fractional part.

For example

    my $version = Perl::Version->new( 1.002003004005006 );
    print $version->normal;

prints

    v1.2.3.4.5.6

=item vstring

Perls later than 5.8.1 support vstring format. A vstring looks like a
number with more than one decimal point and (optionally) a leading
'v'. The 'v' is mandatory for vstrings containing fewer than two
decimal points.

Perl::Version will successfully parse vstrings

    my $version = Perl::Version->new( v1.2 );
    print "$version\n";
    
prints

    v1.2

Note that stringifying a Perl::Version constructed from a vstring will
result in a regular string. Because it has no way of knowing whether the
vstring constant had a 'v' prefix it always generates one when
stringifying back to a version string.

=item CVS version

A common idiom for users of CVS is to use keyword replacement to
generate a version automatically like this:

    $VERSION = version->new( qw$Revision: 2.7 $ );

Perl::Version does the right thing with such versions so that

    my $version = Perl::Version->new( qw$Revision: 2.7 $ );
    $version->inc_revision;
    print "$version\n";

prints

    Revision: 3.0

=back

=head3 Real Numbers

Real numbers are stringified before parsing. This has two implications:
trailing zeros after the decimal point will be lost and any underscore
characters in the number are discarded.

Perl allows underscores anywhere in numeric constants as an aid to
formatting. These are discarded when Perl converts the number into its
internal format. This means that

    # Numeric version
    print Perl::Version->new( 1.001_001 )->stringify;
    
prints

    1.001001
    
but

    # String version
    print Perl::Version->new( '1.001_001' )->stringify;

prints

    1.001_001
    
as expected.

In general you should probably avoid versions expressed either as
decimal numbers or vstrings. The safest option is to pass a regular
string to Perl::Version->new().

=head3 Alpha Versions

By convention if a version string has suffix that consists of an
underscore followed by one or more digits it represents an alpha or
developer release. CPAN treats modules with such version strings
specially to reflect their alpha status.

This alpha notation is one reason why using decimal numbers as versions
is a bad idea. Underscore is a valid character in numeric constants
which is discarded by Perl when a program's source is parsed so any
intended alpha suffix will become part of the version number.

To be considered alpha a version must have a non-zero alpha
component like this

    3.0.4_001

Generally the alpha component will be formatted with leading zeros but
this is not a requirement.

=head2 Component Naming

A version number consists of a series of components. By Perl convention
the first three components are named 'revision', 'version' and
'subversion':

    $ perl -V
    Summary of my perl5 (revision 5 version 8 subversion 6) configuration:
    
    (etc)

Perl::Version follows that convention. Any component may be accessed by
passing a number from 0 to N-1 to the L<component> or L<increment> but for
convenience the first three components are aliased as L<revision>,
L<version> and L<subversion>.

    $version->increment( 0 );

is the same as

    $version->inc_revision;
    
and

    my $subv = $version->subversion;
    
is the same as

    my $subv = $version->component( 2 );

The alpha component is named 'alpha'.

=head2 Comparison with version.pm

If you're familiar with version.pm you'll notice that there's a certain
amount of overlap between what it does and this module. I originally
created this module as a mutable subclass of version.pm but the
requirement to be able to reformat a modified version to match the
formatting of the original didn't sit well with version.pm's internals.

As a result this module is not dependent or based on version.pm.

=head1 INTERFACE

=over

=item C<< new >>

Create a new Perl::Version by parsing a version string. As discussed
above a number of different version formats are supported. Along with
the value of the version formatting information is captured so that the
version can be modified and the updated value retrieved in the same
format as the original.

    my @version = (
        '1.3.0',    'v1.03.00',     '1.10.03', '2.00.00',
        '1.2',      'v1.2.3.4.5.6', 'v1.2',    'Revision: 3.0',
        '1.001001', '1.001_001',    '3.0.4_001',
    );

    for my $v ( @version ) {
        my $version = Perl::Version->new( $v );
        $version->inc_version;
        print "$version\n";
    }

prints

    1.4.0
    v1.04.00
    1.11.00
    2.01.00
    1.3
    v1.3.0.0.0.0
    v1.3
    Revision: 3.1
    1.002000
    1.002
    3.1.0

In each case the incremented version is formatted in the same way as the original.

If no arguments are passed an empty version intialised to 'v0' will be
constructed.

In order to support CVS version syntax

    my $version = Perl::Version->new( qw$Revision: 2.7 $ );

C<new> may be passed an array in which case it concatenates all of its
arguments with spaces before parsing the result.

If the string can't be parsed as a version C<new> will croak with a
suitable error. See L<DIAGNOSTICS> for more information.

=back

=head2 Accessors

=over

=item C<< component >>

Set or get one of the components of a version.

    # Set the subversion
    $version->component( 2, 17 );
    
    # Get the revision
    my $rev = $version->component( 0 );
    
Instead of a component number you may pass a name: 'revision',
'version', 'subversion' or 'alpha':

    my $rev = $version->component( 'revision' );

=item C<< components >>

Get or set all of the components of a version.

    # Set the number of components
    $version->components( 4 );
    
    # Get the number of components
    my $parts = $version->components;
    
    # Get the individual components as an array
    my @parts = $version->components;
    
    # Set the components from an array
    $version->components( [ 5, 9, 2 ] );

Hmm. That's a lot of interface for one subroutine. Sorry about that.

=item C<< revision >>

Alias for C<< component( 0 ) >>. Gets or sets the revision component.

=item C<< version >>

Alias for C<< component( 1 ) >>. Gets or sets the version component.

=item C<< subversion >>

Alias for C<< component( 2 ) >>. Gets or sets the subversion component.

=item C<< alpha >>

Get or set the alpha component of a version. Returns 0 for versions with no alpha.

    # Set alpha
    $version->alpha( 12 );
    
    # Get alpha
    my $alp = $version->alpha;

=item C<< is_alpha >>

Return true if a version has a non-zero alpha component.

=item C<< set >>

Set the version to match another version preserving the formatting of this version.

    $version->set( $other_version );

You may also set the version from a literal string:

    $version->set( '1.2.3' );

The version will be updated to the value of the version string but will
retain its current formatting.

=back

=head2 Incrementing

=over

=item C<< increment >>

Increment a component of a version.

    my $version = Perl::Version->new( '3.1.4' );
    $version->increment( 1 );
    print "$version\n";
    
prints

    3.2.0

Components to the right of the incremented component will be set to zero
as will any alpha component.

As an alternative to passing a component number one of the predefined
component names 'revision', 'version', 'subversion' or 'alpha' may be
passed.

=item C<< inc_alpha >>

Increment a version's alpha component.

=item C<< inc_revision >>

Increment a version's revision component.

=item C<< inc_subversion >>

Increment a version's subversion component.

=item C<< inc_version >>

Increment a version's version component.

=back

=head2 Formatting

=over

=item C<< normal >>

Return a normalised representation of a version.

    my $version = Perl::Version->new( '5.008007_01' );
    print $version->normal, "\n";
    
prints

    v5.8.7_001

=item C<< numify >>

Return a numeric representation of a version. The numeric form is most
frequently used for versions of Perl itself.

    my $version = Perl::Version->new( '5.8.7_1' );
    print $version->normal, "\n";

prints

    5.008007_001

=item C<< stringify >>

Return the version formatted as closely as possible to the version from
which it was initialised.

    my $version = Perl::Version->new( '5.008007_01' );
    $version->inc_alpha;
    print $version->stringify, "\n";

prints

    5.008007_02

and

    my $version = Perl::Version->new( '5.8.7_1' );
    $version->inc_alpha;
    print $version->stringify, "\n";

prints

    5.8.7_2

=back

=head2 Comparison

=over

=item C<< vcmp >>

Perform 'spaceship' comparison between two version and return -1, 0 or 1
depending on their ordering. Comparisons are semantically correct so that

    my $v1 = Perl::Version->new( '1.002001' );
    my $v2 = Perl::Version->new( '1.1.3' );

    print ($v1->vcmp( $v2 ) > 0 ? 'yes' : 'no'), "\n";
    
prints

    yes

=back

=head2 Overloaded Operators

=over

=item C<< <=> >> and C<< cmp >>

The C<< <=> >> and C<< cmp >> operators are overloaded (by the L<vcmp>
method) so that comparisions between versions work as expected. This
means that the other numeric and string comparison operators also work
as expected.

    my $v1 = Perl::Version->new( '1.002001' );
    my $v2 = Perl::Version->new( '1.1.3' );

    print "OK!\n" if $v1 > $v2;

prints

    OK!

=item C<< "" >> (stringification)

Perl::Version objects are converted to strings by calling the
L<stringify> method. This usually results in formatting close to that
of the original version string.

=back

=head2 Constants

=over

=item C<< REGEX >>

An unanchored regular expression that matches any of the version formats
supported by Perl::Version. Three captures get the prefix part, the main
body of the version and any alpha suffix respectively.

    my $version = 'v1.2.3.4_5';
    my ($prefix, $main, $suffix) = ($version =~ Perl::Version::REGEX);
    print "$prefix\n$main\n$suffix\n";
    
prints

    v
    1.2.3.4
    _5

=item C<< MATCH >>

An anchored regular expression that matches a correctly formatted
version string. Five captures get any leading whitespace, the prefix
part, the main body of the version, any alpha suffix and any
trailing spaces respectively.

    my $version = '  v1.2.3.4_5  ';
    my ($before, $prefix, $main, $suffix, $after) 
                 = ($version =~ Perl::Version::MATCH);
    print "|$before|$prefix|$main|$suffix|$after|\n";
    
prints

    | |v|1.2.3.4|_5| |

=back

=head1 DIAGNOSTICS

=head2 Error messages

=over

=item C<< Illegal version string: %s >>

The version string supplied to C<new> can't be parsed as a valid
version. Valid versions match this regex:

    qr/ ( (?i: Revision: \s+ ) | v | )
          ( \d+ (?: [.] \d+)* )
          ( (?: _ \d+ )? ) /x;

=item C<< new must be called as a class or object method >>

C<new> can't be called as a normal subroutine. Use

    $version_object->new( '1.2.3' );
    
or

    Perl::Version->new( '1.2.3' );
    
instead of

    Perl::Version::new( '1.2.3' );

=item C<< Unknown component name: %s >>

You've attempted to access a component by name using a name that isn't
recognised. Valid component names are 'revision', 'version', 'subversion'
and 'alpha'. Case is not significant.

=item C<< Can't compare with %s >>

You've tried to compare a Perl::Version with something other than a
version string, a number or another Perl::Version.

=item C<< Can't set the number of components to 0 >>

Versions must have at least one component.

=item C<< You must specify a component number >>

You've called L<component> or L<increment> without specifying the number (or
name) of the component to access.

=item C<< Component %s is out of range 0..%s >>

You've attempted to increment a component of a version but you've
specified a component that doesn't exist within the version:

    # Fails
    my $version = Perl::Version->new( '1.4' );
    $version->increment( 2 );

Slightly confusingly you'll see this message even if you specified the
component number implicitly by using one of the named convenience
accessors.

=back

=head1 CONFIGURATION AND ENVIRONMENT

Perl::Version requires no configuration files or environment variables.

=head1 DEPENDENCIES

No non-core modules.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-perl-version@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Andy Armstrong C<< <andy@hexten.net> >>

Hans Dieter Pearcey C<< <hdp@cpan.org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Andy Armstrong C<< <andy@hexten.net> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
