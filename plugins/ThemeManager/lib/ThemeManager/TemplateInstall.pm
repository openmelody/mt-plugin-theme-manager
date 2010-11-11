package ThemeManager::TemplateInstall;

use strict;
use ConfigAssistant::Util qw( find_theme_plugin );
use ThemeManager::Util qw( prepare_theme_meta );
use MT::Util qw(caturl dirify offset_time_list);
use MT;

sub _refresh_all_templates {

    # This is basically lifted right from MT::CMS::Template (from Movable Type
    # version 4.261), with some necessary changes to work with Theme Manager.
    my ( $ts_id, $blog_id, $app ) = @_;
    my $q = $app->can('query') ? $app->query : $app->param;

    my $t = time;

    my @id = ( scalar $blog_id );

    require MT::DefaultTemplates;

    my $user = $app->user;
    my @blogs_not_refreshed;
    my $can_refresh_system = $user->is_superuser() ? 1 : 0;
  BLOG:
    for my $blog_id (@id) {
        my $blog;
        if ($blog_id) {
            $blog = MT->model('blog')->load($blog_id);
            next BLOG unless $blog;
        }

        if ( !$can_refresh_system )
        {    # system refreshers can refresh all blogs
            my $perms = MT->model('permission')
              ->load( { blog_id => $blog_id, author_id => $user->id } );
            my $can_refresh_blog
              = !$perms                       ? 0
              : $perms->can_edit_templates()  ? 1
              : $perms->can_administer_blog() ? 1
              :                                 0;
            if ( !$can_refresh_blog ) {
                push @blogs_not_refreshed, $blog->id;
                next BLOG;
            }
        }

        my $tmpl_list;

        # the user wants to back up all templates and
        # install the new ones
        my @ts = offset_time_list( $t, $blog_id );
        my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $ts[5] + 1900,
          $ts[4] + 1, @ts[ 3, 2, 1, 0 ];

        # Backup/delete all the existing templates.
        my $tmpl_iter
          = MT->model('template')
          ->load_iter(
                      { blog_id => $blog_id, type => { not => 'backup' }, } );
        while ( my $tmpl = $tmpl_iter->() ) {

            # Don't backup Widgets or Widget Sets if the user asked
            # that they be saved.
            my $skip = 0;

            # Because Widget Sets reference Widgets, we don't want to backup
            # widgets, either, because that will change their "type" and
            # therefore not be widgets anymore--potentially breaking the
            # Widget Set.
            if (
                 $q->param('save_widgetsets')
                 && (    ( $tmpl->type eq 'widgetset' )
                      || ( $tmpl->type eq 'widget' ) )
                 && ( ( $tmpl->linked_file ne '*' )
                      || !defined( $tmpl->linked_file ) )
              )
            {
                $skip = 1;
            }
            if (
                    $q->param('save_widgets')
                 && ( $tmpl->type eq 'widget' )
                 && ( ( $tmpl->linked_file ne '*' )
                      || !defined( $tmpl->linked_file ) )
              )
            {
                $skip = 1;
            }
            if ( $skip == 0 ) {

                # zap all template maps
                MT->model('templatemap')
                  ->remove( { template_id => $tmpl->id, } );
                $tmpl->name(   $tmpl->name
                             . ' (Backup from '
                             . $ts . ') '
                             . $tmpl->type );
                $tmpl->type('backup');
                $tmpl->identifier(undef);
                $tmpl->rebuild_me(0);
                $tmpl->linked_file(undef);
                $tmpl->outfile('');
                $tmpl->save;
            }
        } ## end while ( my $tmpl = $tmpl_iter...)

        if ($blog_id) {

            # Create the default templates and mappings for the selected
            # set here, instead of below.
            _create_default_templates( $ts_id, $blog );

            $blog->template_set($ts_id);
            $blog->save;
            $app->run_callbacks( 'blog_template_set_change',
                                 { blog => $blog } );

            next BLOG;
        }

        # Now that a new theme has been applied, we want to be sure the correct
        # thumbnail gets displayed on the Theme Dashboard, which means we should
        # delete the existing thumb (if there is one), so that it gets recreated
        # when the user visits the dashboard.
        my $tm = MT->component('ThemeManager');
        my $thumb_path
          = File::Spec->catfile( _theme_thumb_path(), $blog_id . '.jpg' );
        my $fmgr = MT->model('filemgr')->new('Local');
        if ( $fmgr->exists($thumb_path) ) {
            unlink $thumb_path;
        }
    } ## end for my $blog_id (@id)
    if (@blogs_not_refreshed) {

        # Failed!
        return 0;
    }

    # Success!
    return 1;
} ## end sub _refresh_all_templates

sub _create_default_templates {

    # This is basically lifted right from MT::CMS::Template (from Movable Type
    # version 4.261), with some necessary changes to work with Theme Manager.
    my $ts_id     = shift;
    my $blog      = shift;
    my $app       = MT->instance;
    my $tm        = MT->component('ThemeManager');
    my $curr_lang = $app->current_language;
    $app->set_language( $blog->language );

    require MT::DefaultTemplates;
    my $tmpl_list = MT::DefaultTemplates->templates($ts_id);
    if ( !$tmpl_list || ( ref($tmpl_list) ne 'ARRAY' ) || ( !@$tmpl_list ) ) {
        $app->set_language($curr_lang);
        return $blog->error(
                         $tm->translate("No default templates were found.") );
    }

    my $p = find_theme_plugin($ts_id);

    require MT::Template;
    my @arch_tmpl;
    for my $val (@$tmpl_list) {
        next if $val->{global};
        my $obj = MT::Template->new;

        local $val->{name}
          = $val->{name};    # name field is translated in "templates" call
        local $val->{text} = $p->translate_templatized( $val->{text} );

        $obj->build_dynamic(0);
        foreach my $v ( keys %$val ) {
            $obj->column( $v, $val->{$v} ) if $obj->has_column($v);
        }
        $obj->blog_id( $blog->id );
        if ( my $pub_opts = $val->{publishing} ) {
            $obj->include_with_ssi(1) if $pub_opts->{include_with_ssi};
        }
        if ( ( 'widgetset' eq $val->{type} ) && ( exists $val->{widgets} ) ) {
            my $modulesets = delete $val->{widgets};
            $obj->modulesets(
                 MT::Template->widgets_to_modulesets( $modulesets, $blog->id )
            );
        }
        $obj->save;

        if ( $val->{mappings} ) {
            push @arch_tmpl,
              {
                template => $obj,
                mappings => $val->{mappings},
                exists( $val->{preferred} )
                ? ( preferred => $val->{preferred} )
                : ()
              };
        }
    } ## end for my $val (@$tmpl_list)

    my %archive_types;
    if (@arch_tmpl) {
        require MT::TemplateMap;
        for my $map_set (@arch_tmpl) {
            my $tmpl     = $map_set->{template};
            my $mappings = $map_set->{mappings};
            foreach my $map_key ( keys %$mappings ) {
                my $m  = $mappings->{$map_key};
                my $at = $m->{archive_type};
                $archive_types{$at} = 1;

                # my $preferred = $mappings->{$map_key}{preferred};
                my $map = MT::TemplateMap->new;
                $map->archive_type($at);
                if ( exists $m->{preferred} ) {
                    $map->is_preferred( $m->{preferred} );
                }
                else {
                    $map->is_preferred(1);
                }
                $map->template_id( $tmpl->id );
                $map->file_template( $m->{file_template} )
                  if $m->{file_template};
                $map->blog_id( $tmpl->blog_id );
                $map->save;
            } ## end foreach my $map_key ( keys ...)
        } ## end for my $map_set (@arch_tmpl)
    } ## end if (@arch_tmpl)

    $blog->archive_type( join ',', keys %archive_types );
    foreach my $at (qw( Individual Daily Weekly Monthly Category )) {
        $blog->archive_type_preferred($at), last
          if exists $archive_types{$at};
    }
    $blog->custom_dynamic_templates('none');
    $blog->save;

    MT->run_callbacks( ref($blog) . '::post_create_default_templates',
                       $blog, $tmpl_list );

    $app->set_language($curr_lang);
    return $blog;
} ## end sub _create_default_templates

sub template_filter {
    my ( $cb, $templates ) = @_;
    my $app = MT->instance;

    # TODO Determine whether this SHOULD actually be running for non MT::Apps
    return unless $app->isa('MT::App');
    my $q = $app->can('query') ? $app->query : $app->param;

    # If a new blog is being created/saved, we don't want to run this callback.
    return
      if (    eval {$q}
           && eval { $q->param('__mode') }
           && ( $q->param('__mode') eq 'save' )
           && ( $q->param('_type')  eq 'blog' ) );

    # If run-periodic-tasks is running we need to give up because the blog
    # context won't be set properly.
    return unless eval { $app->blog };

    my $blog_id
      = $q->can('blog')
      ? $app->blog->id
      : return;    # Only work on blog-specific widgets and widget sets

    # Give up if the user didn't ask for anything to be saved.
    unless ( $q->param('save_widgets') || $q->param('save_widgetsets') ) {
        return;
    }

    my $index = 0;    # To grab the current array item index.
    my $tmpl_count = scalar @$templates;

    while ( $index <= $tmpl_count ) {
        my $tmpl = @$templates[$index];
        if ( $tmpl->{'type'} eq 'widgetset' ) {
            if ( $q->param('save_widgetsets') ) {

                # Try to count a Widget Set in this blog with the same identifier.
                my $installed = MT->model('template')->load( {
                                         blog_id    => $blog_id,
                                         type       => 'widgetset',
                                         identifier => $tmpl->{'identifier'},
                                       }
                );

                # If a Widget Set by this name was found, remove the template from the
                # array of those templates to be installed.
                if ($installed) {

                    # Delete the Widget Set so it doesn't overwrite our existing Widget Set!
                    splice( @$templates, $index, 1 );
                    next;
                }
            }
        } ## end if ( $tmpl->{'type'} eq...)
        elsif ( $q->param('save_widgets') && $tmpl->{'type'} eq 'widget' ) {

            # Try to count a Widget in this blog with the same identifier.
            my $installed = MT->model('template')->count( {
                                         blog_id    => $blog_id,
                                         type       => 'widgetset',
                                         identifier => $tmpl->{'identifier'},
                                       }
            );

            # If a Widget by this name was found, remove the template from the
            # array of those templates to be installed.
            if ($installed) {

                # Delete the Widget so it doesn't overwrite our existing Widget!
                splice( @$templates, $index, 1 );
                next;
            }
        }
        $index++;
    } ## end while ( $index <= $tmpl_count)
} ## end sub template_filter

sub template_set_change {

    # Set the language of the template set. This is a special case for when
    # creating a new blog.
    _new_blog_template_set_language(@_);

    # Install Default Content
    _install_default_content(@_);

    # Install Template Set Custom Fields
    _install_template_set_fields(@_);

    # Set the publishing preferences for archive mappings
    _set_archive_map_publish_types(@_);

    # Set the publishing preferences for index templates
    _set_index_publish_type(@_);

    # Set the caching preferences for template modules and widgets
    _set_module_caching_prefs(@_);

    # Forcibly turn-on module caching for the blog
    _override_publishing_settings(@_);

    # Production and Designer Modes allow Theme Manager to be suited to two
    # different use cases. Production Mode is used by default. Designer Mode
    # is used to speed development. Eventually there will be many advantages
    # for theme creators using Designer Mode, but for now the only one is
    # that templates are linked by default.
    my $tm = MT->component('ThemeManager');
    my $mode = $tm->get_config_value( 'tm_mode', 'system' ) || '';
    if ( $mode eq 'Designer and Developer Mode' ) {

        # Link installed templates to theme files
        _link_templates(@_);
    }

    # Save the meta about this theme to the DB. This is particularly
    # important in two cases:
    # 1) When a user might uninstall a theme. We want things to (basically)
    #    continue working as expected.
    # 2) Save the theme version, in particular, so that when upgrading to
    #    the new version of a theme the user doesn't falsely think that
    #    they've already upgraded (as is the case with dynamic display of
    #    the version.)
    _save_theme_meta(@_);
} ## end sub template_set_change

sub _new_blog_template_set_language {

    # Only run when a new blog is being created.
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    return
      unless (    ( ( $q->param('__mode') || '' ) eq 'save' )
               && ( ( $q->param('_type') || '' ) eq 'blog' ) );

    my ( $cb, $param ) = @_;
    my $ts_id = $param->{blog}->template_set;

    my $template_set_language = $q->param('template_set_language')
      || $app->user->preferred_language;
    my $blog = $param->{blog};
    $blog->template_set_language($template_set_language);
}

sub _link_templates {

    # Link the templates to the theme.
    my ( $cb, $param ) = @_;
    my $blog_id = $param->{blog}->id;
    my $ts_id   = $param->{blog}->template_set;

    my $cur_ts_plugin = find_theme_plugin($ts_id);
    my $cur_ts_widgets =
      $cur_ts_plugin->registry( 'template_sets', $ts_id,
                                'templates',     'widget' );

    # Grab all of the templates except the Widget Sets, because the user
    # should be able to edit (drag-drop) those all the time.
    my $iter = MT->model('template')
      ->load_iter( { blog_id => $blog_id, type => { not => 'backup' }, } );
    while ( my $tmpl = $iter->() ) {
        if (
             ( ( $tmpl->type ne 'widgetset' ) && ( $tmpl->type ne 'widget' ) )
             || (    ( $tmpl->type eq 'widget' )
                  && ( $cur_ts_widgets->{ $tmpl->identifier } ) )
          )
        {
            $tmpl->linked_file('*');
        }
        else {

            # Just in case Widget Sets were previously linked,
            # now forcefully unlink!
            $tmpl->linked_file(undef);
        }
        $tmpl->save;
    }
} ## end sub _link_templates

sub _override_publishing_settings {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;
    $blog->include_cache(1);
    $blog->save;
}

sub _set_module_caching_prefs {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;

    my $set_name = $blog->template_set or return;
    my $set = MT->app->registry( 'template_sets', $set_name ) or return;
    my $tmpls = MT->app->registry( 'template_sets', $set_name, 'templates' );
    foreach my $t (qw( module widget )) {

        # Give up if there are no templates that match
        next unless eval { %{ $tmpls->{$t} } };
        foreach my $m ( keys %{ $tmpls->{$t} } ) {
            if ( $tmpls->{$t}->{$m}->{cache} ) {
                my $tmpl = MT->model('template')
                  ->load( { blog_id => $blog->id, identifier => $m, } );
                foreach (qw( expire_type expire_interval expire_event )) {
                    my $var = 'cache_' . $_;
                    my $val = $tmpls->{$t}->{$m}->{cache}->{$_};
                    if ($val) {
                        $val = ( $val * 60 ) if ( $_ eq 'expire_interval' );
                        $tmpl->$var($val);
                    }
                }
                foreach (qw( include_with_ssi )) {
                    $tmpl->$_( $tmpls->{$t}->{$m}->{cache}->{$_} );
                }
                $tmpl->save;
            }
        }
    } ## end foreach my $t (qw( module widget ))
} ## end sub _set_module_caching_prefs

sub _set_archive_map_publish_types {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;

    my $set_name = $blog->template_set or return;
    my $set = MT->app->registry( 'template_sets', $set_name ) or return;
    my $tmpls = MT->app->registry( 'template_sets', $set_name, 'templates' );
    my $tm = MT->component('ThemeManager');
    foreach my $a (qw( archive individual )) {

        # Give up if there are no templates that match
        next unless eval { %{ $tmpls->{$a} } };
        foreach my $t ( keys %{ $tmpls->{$a} } ) {
            foreach my $m ( keys %{ $tmpls->{$a}->{$t}->{mappings} } ) {
                my $map = $tmpls->{$a}->{$t}->{mappings}->{$m};
                if ( $map->{build_type} ) {
                    my $tmpl = MT->model('template')
                      ->load( { blog_id => $blog->id, identifier => $t, } );
                    return unless $tmpl;
                    my $tm = MT->model('templatemap')->load( {
                                        blog_id      => $blog->id,
                                        archive_type => $map->{archive_type},
                                        template_id  => $tmpl->id,
                                      }
                    );
                    return unless $tm;
                    $tm->build_type( $map->{build_type} );
                    $tm->is_preferred( $map->{preferred} );
                    $tm->save()
                      or MT->log( {
                           level   => MT->model('log')->ERROR(),
                           blog_id => $blog->id,
                           message => $tm->translate(
                               "Could not update template map for '
                                . 'template [_1].", $t
                           ),
                        }
                      );
                } ## end if ( $map->{build_type...})
            } ## end foreach my $m ( keys %{ $tmpls...})
        } ## end foreach my $t ( keys %{ $tmpls...})
    } ## end foreach my $a (qw( archive individual ))
} ## end sub _set_archive_map_publish_types

sub _set_index_publish_type {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;

    my $set_name = $blog->template_set or return;
    my $set = MT->app->registry( 'template_sets', $set_name ) or return;
    my $tmpls = MT->app->registry( 'template_sets', $set_name, 'templates' );

    # Give up if there are no templates that match
    return unless eval { %{ $tmpls->{index} } };

    my $tm = MT->component('ThemeManager');

    foreach my $t ( keys %{ $tmpls->{index} } ) {
        if ( $tmpls->{index}->{$t}->{build_type} ) {
            my $tmpl = MT->model('template')
              ->load( { blog_id => $blog->id, identifier => $t, } );
            return unless $tmpl;
            $tmpl->build_type( $tmpls->{index}->{$t}->{build_type} );
            $tmpl->save()
              or MT->log( {
                   level   => MT->model('log')->ERROR(),
                   blog_id => $blog->id,
                   message =>
                     $tm->translate(
                        "Could not update template map for template [_1].", $t
                     ),
                 }
              );
        }
    }
} ## end sub _set_index_publish_type

sub _install_template_set_fields {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;
    return _refresh_system_custom_fields($blog);
}

sub _refresh_system_custom_fields {
    my ($blog) = @_;
    return unless MT->component('Commercial');

    my $tm       = MT->component('ThemeManager');
    my $set_name = $blog->template_set or return;
    my $set      = MT->app->registry( 'template_sets', $set_name ) or return;
    my $fields   = $set->{sys_fields} or return;

  FIELD: while ( my ( $field_id, $field_data ) = each %$fields ) {
        next if UNIVERSAL::isa( $field_data, 'MT::Component' );    # plugin
        my %field = %$field_data;
        delete @field{qw( blog_id basename )};
        my $field_name = delete $field{label};
        my $field_scope
          = ( delete $field{scope} eq 'system' ? 0 : $blog->id );
        $field_name = $field_name->() if 'CODE' eq ref $field_name;

      REQUIRED: for my $required (qw( obj_type tag )) {
            next REQUIRED if $field{$required};
            MT->log( {
                       level   => MT->model('log')->ERROR(),
                       blog_id => $field_scope,
                       message =>
                         $tm->translate(
                                 'Could not install custom field [_1]: field '
                                   . 'attribute [_2] is required',
                                 $field_id,
                                 $required,
                         ),
                     }
            );
            next FIELD;
        }

        # Does the blog have a field with this basename?
        my $field_obj = MT->model('field')->load( {
                                  blog_id  => $field_scope,
                                  basename => $field_id,
                                  obj_type => $field_data->{obj_type} || q{},
                                }
        );

        if ($field_obj) {

            # Warn if the type is different.
            MT->log( {
                     level   => MT->model('log')->WARNING(),
                     blog_id => $field_scope,
                     message =>
                       $tm->translate(
                          'Could not install custom field [_1] on blog [_2]: '
                            . 'the blog already has a field [_1] with a '
                            . 'conflicting type',
                          $field_id,
                       ),
                   }
            ) if $field_obj->type ne $field_data->{type};
            next FIELD;
        }

        $field_obj = MT->model('field')->new;

        #use Data::Dumper;
        #MT->log("Setting fields: " . Dumper(%field));
        $field_obj->set_values( {
                                  blog_id  => $field_scope,
                                  name     => $field_name,
                                  basename => $field_id,
                                  %field,
                                }
        );
        $field_obj->save() or die $field_obj->errstr();
    } ## end while ( my ( $field_id, $field_data...))
} ## end sub _refresh_system_custom_fields

sub _install_categories {
    return _install_containers( 'category', 'categories', @_ );
}

sub _install_folders {
    return _install_containers( 'folder', 'folders', @_ );
}

sub _install_containers {
    my ( $model, $key, $blog, $struct, $parent ) = @_;
    my $pid = $parent ? $parent->id : 0;
    foreach my $basename ( keys %$struct ) {
        my $c = $struct->{$basename};
        my $obj
          = MT->model($model)
          ->load(
            { basename => $basename, parent => $pid, blog_id => $blog->id } );
        unless ($obj) {
            $obj = MT->model($model)->new;
            $obj->blog_id( $blog->id );
            $obj->basename($basename);

            # Use the label if it has been specified. If not, fall back to
            # the field basename.
            my $label
              = eval { &{ $c->{label} } } ? &{ $c->{label} } : $basename;
            $obj->label($label);
            $obj->parent($pid);
            $obj->save;
        }
        if ( $c->{$key} ) {
            _install_containers( $model, $key, $blog, $c->{$key}, $obj );
        }
    } ## end foreach my $basename ( keys...)
} ## end sub _install_containers

sub _install_pages_or_entries {
    my ( $model, $blog, $struct ) = @_;
    my $app = MT::App->instance;
    foreach my $basename ( keys %$struct ) {
        my $p   = $struct->{$basename};
        my $obj = MT->model($model)
          ->load( { basename => $basename, blog_id => $blog->id } );
        unless ($obj) {

            # This entry or page doesn't exist yet, so let's create it.
            my $title
              = eval { &{ $p->{label} } } ? &{ $p->{label} } : $basename;
            $obj = MT->model('page')->new;
            $obj->basename($basename);
            $obj->blog_id( $blog->id );
            $obj->title($title);
            $obj->text( $p->{body} );
            $obj->author_id( $app->user->id );
            $obj->status( MT->model('entry')->RELEASE() );

            foreach ( keys %{ $p->{meta} } ) {
                $obj->meta( $_, $p->{meta}->{$_} );
            }
            $obj->set_tags( @{ $p->{tags} } );
            $obj->save;

            # Create the category/folder association if necessary.
            if ( $p->{folder} ) {

                # First try to load the specified folder
                my $folder
                  = MT->model('folder')
                  ->load(
                        { basename => $p->{folder}, blog_id => $blog->id, } );
                if ($folder) {

                    # The folder exists, so lets create the placement
                    my $placement = MT->model('placement')->new;
                    $placement->blog_id( $blog->id );

                    # Attach to the just-saved page.
                    $placement->entry_id( $obj->id );

                    # Attach to the just-loaded folder.
                    $placement->category_id( $folder->id );

                    # A folder always has a primary placement.
                    $placement->is_primary(1);
                    $placement->save;
                }
            } ## end if ( $p->{folder} )
        } ## end unless ($obj)
    } ## end foreach my $basename ( keys...)
} ## end sub _install_pages_or_entries

sub _install_default_content {
    my ( $cb, $param ) = @_;
    my $blog     = $param->{blog}      or return;
    my $set_name = $blog->template_set or return;
    my $set = MT->app->registry( 'template_sets', $set_name ) or return;
    my $content = $set->{content} or return;

    # Sorting the keys is an easy way to ensure that Folders are created
    # before Pages. This is important because when Pages are created, a
    #"folder" key may be specified that causes the Page to be associated
    # with a Folder. And the Folder needs to exist before it can be
    # associated with a Page.
    foreach my $key ( sort keys %$content ) {
        my $struct = $content->{$key};
        if ( $key eq 'folders' ) {
            my $parent = 0;
            _install_folders( $blog, $struct );
        }
        elsif ( $key eq 'categories' ) {
            my $parent = 0;
            _install_categories( $blog, $struct );
        }
        elsif ( $key eq 'pages' ) {
            _install_pages_or_entries( 'page', $blog, $struct );
        }
        elsif ( $key eq 'entries' ) {
            install_pages_or_entries( 'entry', $blog, $struct );
        }
    }
} ## end sub _install_default_content

sub _save_theme_meta {

    # When a new theme is being applied, save the theme meta for easy use later.
    my ( $cb, $param ) = @_;
    my $blog  = $param->{blog}      or return;
    my $ts_id = $blog->template_set or return;
    my $set = MT->app->registry( 'template_sets', $ts_id ) or return;

    # Save the data to the theme_meta meta field.
    $blog->theme_meta( prepare_theme_meta($ts_id) );
    $blog->save;
}

sub xfrm_add_language {

    # When a user is creating a new blog, we need to get in and update the
    # selections with language options. (and maybe others, in the future?) This
    # works by setting the mt_blog.blog_language field to the desired language.
    my ( $cb, $app, $tmpl ) = @_;

    my $old = q{<mt:setvarblock name="html_head" append="1">};
    my $add = <<'HTML';
<script src="<mt:Var name="static_uri">jquery/jquery.js" type="text/javascript"></script>
<script type="text/javascript">
$(document).ready( function() {
    // Expand upon the Template Sets dropdown with a visual chooser.
    $('#template_set-field .field-content').append('<div class="hint"><__trans phrase="Select a theme template set to create a new blog with, or use the"> <a href="javascript:void(0)" onclick="return openDialog(false, \'select_theme\')"><__trans phrase="visual chooser"></a>.</div>');
    // Add an ID to the template set dropdown just to make things easier.
    $('#template_set-field select').attr('id', 'template_set');
    
    
    // Template sets with languages
    var ts = new Array();
<mt:Loop name="ts_loop">
    ts[<mt:Var name="__counter__" op="--">] = '<mt:Var name="ts_id">';
    <mt:Loop name="ts_languages">
        <mt:If name="__first__">
    var <mt:Var name="ts_id"> = new Array;
        </mt:If>
    <mt:Var name="ts_id">[<mt:Var name="__counter__" op="--">] = '<mt:Var name="ts_language">';
    </mt:Loop>
</mt:Loop>

    // Build the blog_language field and place it after the
    // template_set dropdown.
    $('#template_set-field').after( $('<div id="template_set_language-field" class="field field-left-label pkg hidden"></div>') );
    $('#template_set_language-field').html('<div class="field-inner"><div class="field-header"><label id="template_set_language-label" for="template_set_language">Template Set Language</label></div><div class="field-content"><select name="template_set_language"></select><div class="hint"><__trans phrase="Translate templates to the selected language."></div></div></div></div>');

    $('#template_set-field select').click( function() {
        // By default, hide the language field for all template sets. No reason
        // to show it if there are no translations to choose from.
        $('#template_set_language-field').addClass('hidden');
        // If no language is in the template set, then we will want to apply a
        // default. It's probalby safe to say that the user's selected language
        // is a good place to start.
        $('#template_set_language-field select').html('<option value="<mt:Var name="default_language">"><mt:Var name="default_language"></option>');
        // When the template_set field is clicked, look at the value and compare
        // it to all template sets that have a language defined. If a template
        // set has a language defined, then show a chooser to let them select 
        // a language.
        $.each(ts, function(index, ts_id) {
            if ( $('#template_set-field select').val() == ts_id ) {
                $('#template_set_language-field').removeClass('hidden');
                var ts_langs = eval(ts_id);
                // First clear any existing languages.
                $('#template_set_language-field select').html('');
                // Now add the languages in this template set.
                for (var i = 0; i < ts_langs.length; i++) {
                    $('#template_set_language-field select').append('<option value="'+ts_langs[i]+'">'+ts_langs[i]+'</option>');
                }
            }
        });
    });
    
    // Offer an explanation of what the Blog Language selection is.
    $('#blog_language-field .field-content').append('<div class="hint"><__trans phrase="The blog language controls date and time display.</div>">');
});
</script>
HTML

    $$tmpl =~ s/$old/$old$add/;
} ## end sub xfrm_add_language

sub xfrm_param_add_language {
    my ( $cb, $app, $param, $tmpl ) = @_;


    # The user probably wants to apply a new theme; we start by browsing the
    # available themes.
    # Save themes to the theme table, so that we can build a listing screen from them.
    ThemeManager::Plugin::_theme_check();

    # Grab all of the themes/template sets.
    my @ts_loop;
    my $iter = MT->model('theme')->load_iter();
    while ( my $theme = $iter->() ) {

        # Grab the languages available
        my $ts_plugin = $MT::Plugins{ $theme->plugin_sig }{object};
        my $langs = $ts_plugin->registry( 'template_sets', $theme->ts_id,
                                          'languages' );

        # If any languages are available, put them in the loop.
        if ($langs) {
            my @ts_langs;
            foreach my $lang (@$langs) {
                push @ts_langs,
                  { ts_id => $theme->ts_id, ts_language => $lang, };
            }
            push @ts_loop,
              { ts_id => $theme->ts_id, ts_languages => \@ts_langs, };
        }
    }
    $param->{ts_loop} = \@ts_loop;
    $param->{default_language} = $app->user->preferred_language || 'en-us';

} ## end sub xfrm_param_add_language

1;

__END__
