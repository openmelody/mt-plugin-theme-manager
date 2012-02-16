package Pure::ThemeManager::BlogUpgrader;

use base qw( Class::Accessor MT::ErrorHandler );
__PACKAGE__->mk_accessors(qw( blog_id blog theme progress_handler ));


package ThemeManager::BlogUpgrader;

=head1 NAME

ThemeManager::BlogUpgrader - A controller class for upgrading the theme in
use by a blog

=head1 SYNOPSIS

   use ThemeManager::BlogUpgrader;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.

=head1 DESCRIPTION

A full description of the module and its features.

May include numerous subsections (i.e., =head2, =head3, etc.).

=cut

use strict;
use warnings;
use Carp qw( croak cluck );
use Data::Dumper;
use Pod::Usage;
use File::Spec;
use Try::Tiny;
use Cwd qw( realpath );
use Scalar::Util qw( looks_like_number blessed );

use base qw( Pure::ThemeManager::BlogUpgrader );

use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
###l4p our $logger = MT::Log::Log4perl->new();

=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.

These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module
provides.

Name the section accordingly.

In an object-oriented module, this section should begin with a sentence (of the
form "An object of this class represents ...") to give the reader a high-level
context to help them understand the methods that are subsequently described.

=head2 blog_id

Accessor and single-use mutator for the C<blog_id> property of the
BlogUpgrader object.

If unset, this will be calculated from the C<blog> property meaning that one
of the two must be set before executing any non-initialization methods.

=cut
sub blog_id {
    my $self = shift;
    return $self->SUPER::blog_id() ? $self->SUPER::blog_id()
         :                    @_ ? $self->SUPER::blog_id(@_)
                                 : try { $self->blog->id };
}


=head2 blog

Accessor and single use mutator for the C<blog> property of the BlogUpgrader
object. See C<blog_id> property documentation for further details.

=cut
sub blog {
    my $self = shift;
    return $self->SUPER::blog() ? $self->SUPER::blog()
         :                 @_ ? $self->SUPER::blog(@_)
                              : try {
                                  my $id = $self->blog_id or return;
                                  my $b  = MT->model('blog')->load( $id );
                                  $b ? $self->SUPER::blog( $b ) : undef;
                                };
}


=head2 theme

Accessor and single-use mutator for the C<theme> property of the BlogUpgrader
object.

If unset, this will be calculated from the C<blog> property.  If the blog
has no theme, this will return undef.

=cut
sub theme {
    my $self = shift;
    require ThemeManager::Theme;
    return $self->SUPER::theme() ? $self->SUPER::theme()
         :                  @_ ? $self->SUPER::theme(@_)
                               : try {
                                   my $t  = $self->blog->theme;
                                   my $id = $self->blog_id;
                                   $t ? $self->SUPER::theme( $t ) : undef
                                 }
                                 catch {
                                     warn "$_";
                                     return undef;
                                 };
}


=head2 progress

This method is a utility method for reporting progress via the
C<progress_handler>.

=cut
sub progress {
    my $self = shift;
    my $handler = $self->progress_handler()
               || sub { 
                        my $msg = @_ > 1 ? sprintf( +shift, @_ )
                                         : shift();
                        print "* $msg\n";
                  };
    $handler->( @_ );
}

=head2 progress_handler

Accessor/mutator for the C<progress_handler> property which holds a reference
to the method used by the C<progress> method to output progress messages.

=head2 upgrade

# This function is responsible for completing the theme upgrade. It is used
# for manual, user-initiated upgrades (in Production Mode) and automatic
# upgrades (in Designer Mode). Returns a results hash with messages about the
# upgrade success/failure.

    # Update the theme meta in the DB so that the new version number is
    # reflected (as well as any other changes to the theme meta, too, of
    # course)

=cut
sub upgrade {
    my $self  = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $Blog  = MT->model('blog');
    my $blog  = $self->blog()
        or return $self->errtrans( 'Upgrade requires either blog or '.
                                   'blog_id property to be set' );

    my $theme = $self->theme
        or return $self->errtrans( 'Blog ID [_1] has no theme', $blog->id );

    my $definition = $theme->definition
        or return $self->errtrans( "Could not load theme definition from "
                                 . "plugin for theme '[_1]'", $theme->ts_id );

    $self->progress(
        sprintf 'STARTING UPGRADE of theme %s for blog "%s" (ID:%d)',
                $theme->ts_id, $blog->name, $blog->id );

    # Actually do the upgrade, based on all of the above submitted info.
    return $self->_refresh_system_custom_fields()
        && $self->_refresh_fd_fields()
        && $self->_refresh_templates()
        && $self->_save_theme_meta();
}



=head2 _refresh_system_custom_fields

=cut
sub _refresh_system_custom_fields {
    my $self     = shift;
    my ( $blog ) = $self->blog;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    return 1 unless MT->component('Commercial');

    my $app   = MT->instance;
    my $theme = $self->theme;
    my $set   = $app->registry( 'template_sets', $theme->ts_id )
        or return $self->errtrans(
            'Could not load theme info from registry for '.$theme->ts_id );

    # In order to refresh both the blog-level and system-level custom fields,
    # merge each of those hashes. We don't have to worry about those hashes
    # not having unique keys, because the keys are the custom field basenames
    # and custom field basenames must be unique regardless of whether they
    # are for the blog or system.
    my $fields = {};

    # Any fields under the "sys_fields" key should be created/updated
    # as should any key under the "fields" key. I'm not sure why/when both
    # of these types were created/introduced. It makes sense that maybe
    # "sys_fields" is for system custom fields and "fields" is for blog level
    # custom fields, however the scope key means that they can be used
    # interchangeably.
    @$fields{ keys %{ $set->{sys_fields} } } = values %{ $set->{sys_fields} };
    @$fields{ keys %{ $set->{fields} } }     = values %{ $set->{fields} };

    # Give up if there are no custom fields to install.
    return 1 unless %$fields;

  FIELD: while ( my ( $field_id, $field_data ) = each %$fields ) {
        next if blessed( $field_data ) and $field_data->isa('MT::Component');
        my %field       = %$field_data;
        delete @field{qw( blog_id basename )};
        my $field_name  = delete $field{label};
        my $field_scope = ( $field{scope}
                        && delete $field{scope} eq 'system' ? 0 : $blog->id );
        $field_name = $field_name->() if 'CODE' eq ref $field_name;

        # If the custom field definition is missing the required basic field
        # definitions then we should report that problem immediately. In
        # Production Mode, just die immediately; in Designer Mode save the
        # error to the Activity Log.
      REQUIRED: for my $required (qw( obj_type tag )) {
            next REQUIRED if $field{$required};

            if ($blog->theme_mode eq 'designer') {
                my $tm    = MT->component('ThemeManager');
                MT->log( {
                           level   => MT->model('log')->ERROR(),
                           blog_id => $field_scope,
                           message => $tm->translate(
                                   'Could not install custom field [_1]: field '
                                     . 'attribute [_2] is required',
                                   $field_id,
                                   $required,
                               ),
                         }
                );

                next FIELD;
            }
            else {
                die "Could not install custom field $field_id: field attribute "
                    . "$required is required.";
            }
        }

        # Does the blog have a field with this basename?
        my $field_obj = $Field->load( {
                                  blog_id  => $field_scope,
                                  basename => $field_id,
                                  obj_type => $field_data->{obj_type} || q{},
                                }
        );

        if ($field_obj) {

            # The field data type can't just be changed willy-nilly. Because
            # different data types store data in different formats and in
            # different fields we can't expect to change to another field type
            # and just see things continue to work. Again, in Production Mode
            # the user should be notified immediately, while in Designer Mode
            # the error is written to the Activity Log.
            if ( $field_obj->type ne $field_data->{type} ) {
                if ($blog->theme_mode eq 'designer') {
                    my $tm    = MT->component('ThemeManager');
                    MT->log( {
                           level   => MT->model('log')->ERROR(),
                           blog_id => $field_scope,
                           message =>
                             $tm->translate(
                               'Could not install custom field [_1] on blog [_2]: '
                                 . 'the blog already has a field [_1] with a '
                                 . 'conflicting type',
                               $field_id,
                             ),
                        }
                    );

                    next FIELD;
                }
                else {
                    die "Could not install custom field $field_id on blog "
                        . $blog->name . ": the blog already has a field "
                        . "$field_id with a conflicting type.";
                }
            }
        }
        else {

            # This field doesn't exist yet.
            $field_obj = $Field->new;
        }

        #use Data::Dumper;
        #MT->log("Setting fields: " . Dumper(%field));
        $field_obj->set_values( {
                                  blog_id  => $field_scope,
                                  name     => $field_name,
                                  basename => $field_id,
                                  %field,
                                }
        );
        $field_obj->save()
            or die 'Error saving custom field: '.$field_obj->errstr;
    } ## end while ( my ( $field_id, $field_data...))

    1;

} ## end sub _refresh_system_custom_fields


=head2 _refresh_fd_fields

=cut
sub _refresh_fd_fields {
    my $self     = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my ( $blog ) = $self->blog;
    return 1 unless MT->component('FieldDay');

    my $app   = MT->instance;
    my $theme = $self->theme;
    my $set   = $app->registry( 'template_sets', $theme->ts_id );
    return 1 unless $ts_id and $set;

    # Field Day fields are all defined under the fd_fields key. Install groups
    # first (in the group key), then install fields (in the fields key). That
    # way, if a field is in a group, the group already exists.
    foreach my $kind (qw( group field )) {
        while ( my ( $field_id, $field_data ) = each %{ $set->{fd_fields}->{$kind} } ) {
            $self->_refresh_fd_field({
                field_id   => $field_id,
                field_data => $field_data,
                field_type => $kind,
            });
        }
    }

    1;
} ## end sub _refresh_fd_fields


# Process the individual Field Day group or field, installing or updating as
# needed.
=head2 _refresh_fd_field

=cut
sub _refresh_fd_field {
    my $self       = shift;
    my ($arg_ref)  = @_;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $blog       = $self->blog;
    my $field_id   = $arg_ref->{field_id};
    my $field_data = $arg_ref->{field_data};
    my $field_type = $arg_ref->{field_type};
    my $tm         = MT->component('ThemeManager');

    return if blessed $field_data and $field_data->isa('MT::Component');

    my $field_scope = ( $field_data->{scope}
                      && delete $field_data->{scope} eq 'system' ? 0 : $blog->id );

    # If the Field Day field definition is missing the required basic
    # field definitions then we should report that problem immediately. In
    # Production Mode, just die immediately; in Designer Mode save the
    # error to the Activity Log.
    unless ( $field_data->{obj_type} ) {
        die "Could not install Field Day field $field_id: field "
            . "attribute obj_type is required."
            unless $blog->theme_mode eq 'designer';

        MT->log( {
                   level   => MT->model('log')->ERROR(),
                   blog_id => $field_scope,
                   message => $tm->translate(
                           'Could not install Field Day field [_1]: '
                             . 'field attribute obj_type is required',
                           $field_id
                       ),
                 }
        );
        return;
    }

    # Does the blog have a field with this basename?
    my $field_obj = MT->model('fdsetting')->get_by_key( {
        blog_id     => $field_scope,
        name        => $field_id,
        object_type => $field_data->{obj_type} || q{},
        type        => $field_data->{type} || 'field',
    });

    # This field exists already. Verify the type before proceeding.
    if ( $field_obj->id ) {

        # The field data type can't just be changed willy-nilly. Because
        # different data types store data in different formats and in
        # different fields we can't expect to change to another field type
        # and just see things continue to work. Again, in Production Mode
        # the user should be notified immediately, while in Designer Mode
        # the error is written to the Activity Log.
        if ( $field_obj->type ne $field_type ) {

            die "Could not install Field Day field $field_id on blog "
                . $blog->name . ": the blog already has a field "
                . "$field_id with a conflicting type."
                unless $blog->theme_mode eq 'designer';

            MT->log( {
                   level   => MT->model('log')->ERROR(),
                   blog_id => $field_scope,
                   message =>
                     $tm->translate(
                       'Could not install Field Day field [_1] on '
                         . 'blog [_2]: the blog already has a field '
                         . '[_1] with a conflicting type',
                       $field_id,
                     ),
                }
            );
            return;
        }
    }

    my $data = $field_data->{data};

    # The label field needs to be dereferenced.
    $data->{label} = &{ $data->{label} };  # $data->{label}->()   ???

    # The `group` key references a Field Day group name within the YAML. Field
    # Day requires that this key reflect the group ID, so we need to switch to
    # that before installing.
    if ( $data->{group} ) {

        # Load the group row based on this field's group ID.
        my $group = MT->model('fdsetting')->load({
            blog_id => $field_scope,
            type    => 'group',
            name    => $data->{group},
        });

        # Reset this field's group (currently an ID) to the name of the group
        # which we can easily use later to correctly build the fields.
         $data->{group} = $group->id
             if $group;
    }

    $field_obj->set_values({
        order => $field_data->{order},
        data  => $data,
    });

    $field_obj->save()
        or die 'Error saving Field Day field: '.$field_obj->errstr;
}


=head2 _refresh_templates


    # Does anything need to be done with templates?
        # Any upgraded templates also get a backup of the original created.
        # Create a timestamp to apply to the backup, which can be applied to
        # all of the templates backups created.
            # New templates need to be installed. Look for the current
            # template identifier in the @new_templates array. If found, add
            # the template.
                # This is a new template that needs to be installed. Before
                # installing, just do a quick check to ensure it doesn't
                # exist, though.
                    # Is there a manually created version of this template in
                    # the theme? If so it needs to be retired so that the new
                    # template can be installed.
            # Existing templates need to be updated. The parameter
            # "upgrade_existing_templates" is a checkbox the user has
            # previously selected, acknowledging that upgrading templates
            # could overwrite any of their manually added changes. Also, look
            # for the current template identifier in the @changed_templates
            # array. If found, we need to upgrade the template. Update the
            # actual template text only, not any of the template meta because
            # the user may have purposefully changed that.
                # Create a backup of the existing template.
                # FIXME Really should be using MT::Template::clone() here
                #  Otherwise, you aren't future-compat and may be missing meta
                # my $tmpl_backup = $db_tmpl->clone()
                # $tmpl_backup->name( $tmpl_backup->name
                #                   . " (Backup from $ts) " . $db_tmpl->type );
                # $tmpl_backup->type('backup');
                # Translate the template to another language, if translations
                # were provided.
=cut
sub _refresh_templates {
    my $self  = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $blog  = $self->blog;
    my $theme = $blog->theme;

    return unless @{ $theme->updated_templates() }
               || @{ $theme->new_templates()     };

    my $defaults = $theme->default_templates( $blog->language );
    foreach my $def_tmpl ( @$defaults ) {
        my $tmpl = $self->install_template( $def_tmpl ) or return;
    }
    1;
}

=head2 _save_theme_meta
    # When a new theme is being applied, save the theme meta for easy use later.
    # Save the data to the theme_meta meta field.

=cut
sub _save_theme_meta {
    my $self       = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $blog       = $self->blog;
    my $theme      = $self->theme;
    my $ts_id      = $theme->ts_id;
    my $definition = $theme->definition; # or return;

    my $meta = ThemeManager::Util::prepare_theme_meta($ts_id);
    my $yaml = try {
        require ThemeManager::Theme::Util;
        ThemeManager::Theme::Util::deflate_yaml( $meta );
    } catch {
        warn "deflate_yaml error: $_";
        '';
    };

    # Turn that YAML into a plain old string and save it.
    $blog->theme_meta( $yaml );
    $blog->save or die 'Error saving blog: '.$blog->errstr;
}


=head2 update_changed_template
            # Existing templates need to be updated. The parameter
            # "upgrade_existing_templates" is a checkbox the user has
            # previously selected, acknowledging that upgrading templates
            # could overwrite any of their manually added changes. Also, look
            # for the current template identifier in the @changed_templates
            # array. If found, we need to upgrade the template. Update the
            # actual template text only, not any of the template meta because
            # the user may have purposefully changed that.
=cut
sub update_template {
    my $self                 = shift;
    my ( $tmpl, $tmpl_data ) = @_;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $blog                 = $self->blog;

    require Digest::MD5;
    my $text_new = $self->translate_text( $tmpl_data );
    my $text_old = $tmpl->text;
    my $digest = sub {
        my $x = shift;
        return defined $x and $x ne '' ? Digest::MD5::md5_hex($x) : '';
    };
    if ( $digest->($text_new) eq $digest->($text_old) ){
        $self->progress(
            sprintf('Template already up-to-date: %s', $tmpl->name) );
        return $tmpl;
    }

    my $tmpl_backup = $tmpl->backup();
    # die 'Error saving backup template: '.$tmpl_backup->errstr
    #     unless $tmpl_backup and $tmpl_backup->id;

    $tmpl->text( $text_new );
    $tmpl->save
        or die 'Error saving template: '.$tmpl->errstr;

    $self->purge_template_cache( $tmpl );

    my $message
        = sprintf('Upgraded template: %s', $tmpl->name);
    MT->log({
        level   => MT->model('log')->INFO(),
        blog_id => $blog->id,
        message => 'Theme upgrade: ' . $message,
    });
    $self->progress( $message );
    return $tmpl;
}


=head2 purge_template_cache

=cut
sub purge_template_cache {
    my $self = shift;
    my $tmpl = shift;
    # Delete any caching for this template.
    my $key = 'blog::' . $tmpl->blog_id . '::template_'
        . $tmpl->type . '::' . $tmpl->name;
    MT->model('session')->remove( { id => $key });
    # $self->progress("Removed template caching session: ".$key);
    1;
}

=head2 translate_text

=cut
sub translate_text {
    my $self = shift;
    my $data = shift;
    my $text = defined $data->{text} ? $data->{text} : '';

    # Translate the template to another language, if translations
    # were provided.
    my $trans = try {
        $self->theme->plugin->translate_templatized($text);
    }
    catch {
        die "There was an error translating the template '"
            . $data->{name} . ".' Error: " . $_;
    };
    $trans;

}

=head2 install_new_template

            # New templates need to be installed. Look for the current
            # template identifier in the @new_templates array. If found, add
            # the template.
    # This is a new template that needs to be installed. Before
    # installing, just do a quick check to ensure it doesn't
    # exist, though.
    # Is there a manually created version of this template in
    # the theme? If so it needs to be retired so that the new
    # template can be installed.
    # Create a template based on the theme's definition. Also creates template
    # maps for archive templates. Returns the created template object.

=cut
sub install_template {
    my $self      = shift;
    my $tmpl_data = shift;

    my $tmpl = $self->find_theme_template( $tmpl_data );

    return $tmpl ? $self->update_template( $tmpl, $tmpl_data )
                 : $self->create_template( $tmpl_data );
}

sub create_template {
    my $self      = shift;
    my $tmpl_data = shift;
    my $blog      = $self->blog;
    my $Template  = MT->model('template');
    my $tmpl      = $Template->new();

    $tmpl->$_( $tmpl_data->{$_} )
        foreach grep { ! ref $_ and $tmpl->has_column($_) } keys %$tmpl_data;

    $tmpl->blog_id( $blog->id );
    $tmpl->text( $self->translate_text( $tmpl_data ) );
    $tmpl->build_dynamic(0);
    $tmpl->include_with_ssi(1) if $tmpl_data->{cache}->{include_with_ssi};

    if (   'widgetset' eq $tmpl_data->{type}
        and exists $tmpl_data->{widgets} )
    {
        my $modulesets = delete $tmpl_data->{widgets};
        $tmpl->modulesets(
             $Template->widgets_to_modulesets( $modulesets, $blog->id )
        );
    }

    $tmpl->save or die 'Error saving template: '.$tmpl->errstr;

    # Create the template mappings, if any exist.
    if ( my $mappings = $tmpl_data->{mappings} ) {

        # There can be several mappings to a single template, so use a loop to
        # be sure to handle all of them.
        foreach my $map_key ( keys %$mappings ) {
            my $m  = $mappings->{$map_key};
            my $at = $m->{archive_type};

            my $map = MT->model('templatemap')->new;
            $map->template_id( $tmpl->id );
            $map->blog_id( $tmpl->blog_id );
            $map->archive_type($at);
            $map->is_preferred( defined $m->{preferred} ? $m->{preferred} : 1 );
            $map->file_template( $m->{file_template} ) if $m->{file_template};
            $map->save
                or die 'Error saving template mapping: '.$map->errstr;
        }
    }

    my $message = sprintf(
        'Installed new template: "%s"', $tmpl->name );
    MT->log({
        level   => MT->model('log')->INFO(),
        blog_id => $blog->id,
        message => 'Theme upgrade: ' . $message,
    });
    $self->progress( $message );

    return $tmpl;
}

sub find_theme_template {
    my $self      = shift;
    my $tmpl_data = shift;
    my $blog      = $self->blog;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    my $target;

    my @identified = MT->model('template')->load({
        blog_id    => $blog->id,
        identifier => $tmpl_data->{identifier},
    });

    foreach my $tmpl ( @identified ) {
        if ( $tmpl->type eq 'backup' ) {  # Backups should not have identifiers
            $tmpl->save_as_backup();
            $self->progress(
                'Removed identifier "%s" from backup template ID %d',
                $tmpl_data->{identifier}, $tmpl->id
            );
        }
        elsif ( $target ) {    # My master says we already got one
            $tmpl->save_as_backup();
            $self->progress(
                'Converted redundant %s template (ID: %d) to a backup',
                $tmpl_data->{identifier}, $tmpl->id
            );
        }
        else {
            $target = $tmpl;   # Choose first non-backup
        }
    }

    # If we've found one, return it
    return $target if $target;

    # Otherwise, we need to look for templates with no identifier but
    # same name and type indicating it was possibly manually created
    my @name_and_type = MT->model('template')->load({
        blog_id => $blog->id,
        name    => $tmpl_data->{name},
        type    => $tmpl_data->{type},
    });

    foreach my $tmpl ( @name_and_type ) {
        if ( $target ) {    # My master says we already got one
            $tmpl->save_as_backup();
            $self->progress(
                'Converted redundant %s template (ID: %d) to a backup',
                $tmpl_data->{identifier}, $tmpl->id
            );
        }
        else {
            $target = $tmpl;   # Choose first non-backup
        }
    }

    return $target;    # Hopefully we have one by now
}

package MT::Template;

use Scalar::Util qw( blessed );

=head2 backup

This method creates a backup copy of a template by first cloning it and then
converting the clone to a backup (see C<save_as_backup>).

=cut
sub backup {
    my $self        = shift;
    my $ts          = $self->backup_ts();
    my $tmpl_backup = $self->clone({ Except => { id => 1 } });
    $tmpl_backup->name( $self->name
                      . " (Backup from $ts) " . $self->type );
    $tmpl_backup->save_as_backup();
    $tmpl_backup;
}

=head2 retire

This method should be used to retire a template permanently. When called on
a template instance, it modifies the name to indicate its retired status
and converts it to a backup template (see C<save_as_backup>).

=cut
sub retire {
    my $self = shift;
    return if $self->type eq 'backup';
    my $ts = $self->backup_ts();
    $self->name(join(' ', $self->name, "(Retired $ts)", $self->type ));
    $self->save_as_backup();
}

=head2 save_as_backup

This method is called on a template object to convert it to a backup template.
After the appropriate values are set (see C<backup_values>), the template is
saved and all of its related template maps and fileinfo records are expunged.

=cut
sub save_as_backup {
    my $self = shift;
    $self->set_values( $self->backup_values() );
    $self->save
        && MT->model('fileinfo')->remove({ template_id => $self->id })
        && MT->model('templatemap')->remove({ template_id => $self->id });
}


=head2 backup_values

Method which returns a hash reference representing the appropriate values
to use when converting a template to or creating a backup template

=cut
sub backup_values {
    return {
        type          => 'backup',
        identifier    => '',
        linked_file   => '',
        outfile       => '',
        rebuild_me    => 0,
        build_dynamic => 0,
    };
}


=head2 backup_ts

Internal method for creating timestamps for backup template names

=cut
sub backup_ts {
    my $self    = shift;
    require MT::Util;
    my $blog_id = blessed( $self ) ? $self->blog_id : undef;
    my @ts      = MT::Util::offset_time_list( time, $blog_id );
    sprintf "%04d-%02d-%02d %02d:%02d:%02d",
        $ts[5] + 1900, $ts[4] + 1, @ts[ 3, 2, 1, 0 ];
}


1;

__END__
=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate (even
the ones that will "never happen"), with a full explanation of each problem,
one or more likely causes, and any suggested remedies.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems via http://help.endevver.com/

Patches are welcome.

=head1 AUTHOR

Jay Allen, Endevver, LLC http://endevver.com/

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 Endevver, LLC (info@endevver.com).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
