package ThemeManager::TemplateInstall;

use strict;
use ConfigAssistant::Util qw( find_theme_plugin );
use ThemeManager::Util qw( theme_label theme_version prepare_theme_meta );
use MT::Util qw(caturl dirify offset_time_list);
use MT;

use Digest::MD5 qw(md5_hex);

# This sub is responsible for applying the new theme's templates.
# This is basically lifted right from MT::CMS::Template (from Movable Type
# version 4.261), with some necessary changes to work with Theme Manager.
sub _refresh_all_templates {
    my ( $ts_id, $blog_id, $app ) = @_;
    my $q = $app->query;

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
        my @ts = offset_time_list( time, $blog_id );
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

            if (
                ( 
                    $q->param('save_widgetsets')
                    && ( $tmpl->type eq 'widgetset' )
                )
                || (
                    $q->param('save_widgets')
                    && ( $tmpl->type eq 'widget' )
                )
            ) {
                $skip = 1;
            }

            if ( $skip == 0 ) {

                # Remove all template maps for this template.
                MT->model('templatemap')
                  ->remove( { template_id => $tmpl->id, } );

                # Remove all fileinfo records for this template.
                MT->model('fileinfo')
                  ->remove( { template_id => $tmpl->id, } );

                # Delete any caching for this template.
                my $key = 'blog::' . $blog_id . '::template_' . $tmpl->type 
                    . '::' . $tmpl->name;
                MT->model('session')->remove( { id => $key });

                $tmpl->name(   $tmpl->name
                             . ' (Backup from '
                             . $ts . ') '
                             . $tmpl->type );
                $tmpl->type('backup');
                $tmpl->identifier(undef);
                $tmpl->rebuild_me(0);
                $tmpl->linked_file(undef);
                $tmpl->outfile('');
                $tmpl->save
                    or die 'Error saving template: '.$tmpl->errstr;
            }
        } ## end while ( my $tmpl = $tmpl_iter...)

        if ($blog_id) {

            # Create the default templates and mappings for the selected
            # set here, instead of below.
            _create_default_templates( $ts_id, $blog );

            $blog->template_set($ts_id);
            $blog->save
                or die 'Error saving blog: '.$blog->errstr;

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
          = File::Spec->catfile( theme_thumb_path(), $blog_id . '.jpg' );
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

# This is basically lifted right from MT::CMS::Template (from Movable Type
# version 4.261), with some necessary changes to work with Theme Manager.
# Default templates are created when a new theme is applied, using the 
# templates specified in the theme.
sub _create_default_templates {
    my $ts_id     = shift;
    my $blog      = shift;
    my $app       = MT->instance;
    my $q         = $app->query;
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

    my $plugin = find_theme_plugin($ts_id);

    # This hash holds a list of all of the template mappings that are created
    # for each template. Then, after creating tmeplates, it's used to set the
    # blog-level preferred archive type.
    my %archive_types;
    
    my $save_widget_sets = $q->param('save_widgetsets');
    my $save_widgets     = $q->param('save_widgets');

    # Go through each template definition and create a template.
    for my $val (@$tmpl_list) {
        next if $val->{global};

        # Did the user request we save the widgets? If so, then we don't want
        # to overwrite any existing widget.
        next if ( 
            $save_widgets 
            && $val->{type} eq 'widget'
            && (
                MT->model('template')->exist({
                    blog_id    => $blog->id,
                    type       => 'widget',
                    identifier => $val->{identifier},
                })
                || MT->model('template')->exist({
                    blog_id => $blog->id,
                    type    => 'widget',
                    name    => $val->{name},
                })
            )
        );

        # Did the user request we save the widget sets? If so, then we don't
        # want to overwrite any existing widget sets.
        next if ( 
            $save_widget_sets 
            && $val->{type} eq 'widgetset'
            && (
                MT->model('template')->exist({
                    blog_id    => $blog->id,
                    type       => 'widgetset',
                    identifier => $val->{identifier},
                })
                || MT->model('template')->exist({
                    blog_id => $blog->id,
                    type    => 'widgetset',
                    name    => $val->{name},
                })
            )
        );

        my $tmpl = _create_template($val, $blog, $plugin);

        my $iter = MT->model('templatemap')->load_iter({ 
            template_id => $tmpl->id 
        });
        while ( my $tmpl_map = $iter->() ) {
            $archive_types{$tmpl_map->archive_type} = 1;
        }
    }

    $blog->archive_type( join ',', keys %archive_types );
    foreach my $at (qw( Individual Daily Weekly Monthly Category )) {
        $blog->archive_type_preferred($at), last
          if exists $archive_types{$at};
    }
    $blog->custom_dynamic_templates('none');
    $blog->save
        or die 'Error saving blog: '.$blog->errstr;

    MT->run_callbacks( ref($blog) . '::post_create_default_templates',
                       $blog, $tmpl_list );

    $app->set_language($curr_lang);
    return $blog;
} ## end sub _create_default_templates

# Create a template based on the theme's definition. Also creates template 
# maps for archive templates. Returns the created template object.
sub _create_template {
    my ($tmpl_data) = shift;
    my ($blog)      = shift;
    my ($plugin)    = shift;

    # Create the template
    my $tmpl = MT->model('template')->new;

    local $tmpl_data->{name}
      = $tmpl_data->{name};    # name field is translated in "templates" call
     # This code was added by Byrne because the localization of the $val->{text}
     # variable within the context of the eval block was resulting in the
     # translated text not to be saved to the variable.
    my $trans = $tmpl_data->{text};
    eval {
        $trans = $plugin->translate_templatized($trans);
        1;
      }
      or do {
        my $tm = MT->component('ThemeManager');
        MT->log(
            level   => MT->model('log')->ERROR(),
            blog_id => $blog ? $blog->id : 0,
            message =>
              $tm->translate(
                "There was an error translating the template '[_1].' Error: [_2]",
                $tmpl_data->{name},
                $@
              )
        );
      };
    local $tmpl_data->{text} = $trans;

    $tmpl->build_dynamic(0);
    foreach my $v ( keys %$tmpl_data ) {
        $tmpl->column( $v, $tmpl_data->{$v} ) if $tmpl->has_column($v);
    }
    $tmpl->blog_id( $blog->id );
    $tmpl->include_with_ssi(1) if $tmpl_data->{cache}->{include_with_ssi};
    if ( ( 'widgetset' eq $tmpl_data->{type} ) && ( exists $tmpl_data->{widgets} ) ) {
        my $modulesets = delete $tmpl_data->{widgets};
        $tmpl->modulesets(
             MT::Template->widgets_to_modulesets( $modulesets, $blog->id )
        );
    }

    $tmpl->save or die 'Error saving template: '.$tmpl->errstr;
    
    # Create the template mappings, if any exist.
    if ( $tmpl_data->{mappings} ) {

        # There can be several mappings to a single template, so use a loop to
        # be sure to handle all of them.
        my $mappings = $tmpl_data->{mappings};
        foreach my $map_key ( keys %$mappings ) {
            my $m  = $mappings->{$map_key};
            my $at = $m->{archive_type};

            my $map = MT->model('templatemap')->new;
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
            $map->save
                or die 'Error saving template mapping: '.$map->errstr;
        }
    }
    
    return $tmpl;
}

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
    my ( $cb, $param ) = @_;
    my $theme_mode = $param->{blog}->theme_mode || 'production';
    if ( $theme_mode eq 'designer' ) {

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
    my $q = $app->query;
    return
      unless (    ( ( $q->param('__mode') || '' ) eq 'save' )
               && ( ( $q->param('_type') || '' ) eq 'blog' ) );

    my ( $cb, $param ) = @_;
    my $ts_id = $param->{blog}->template_set;

    # Set the template's language. If the theme has defined languages, then
    # this may be different from the user preferred language.
    my $template_set_language = $q->param('template_set_language')
      || $app->user->preferred_language;
    my $blog = $param->{blog};
    $blog->template_set_language($template_set_language);
}

# In Designer Mode, all of the templates in a theme should be linked to their
# counterparts on the filesystem.
sub _link_templates {
    my ( $cb, $param ) = @_;
    my $blog_id = $param->{blog}->id;
    my $ts_id   = $param->{blog}->template_set;

    my $cur_ts_plugin = find_theme_plugin($ts_id);

    # If translations are offered for this theme, just give up. We don't
    # want to try to link a theme that has translations because the
    # linking process will throw away the "__trans phrase" wrappers.
    return if eval { $cur_ts_plugin->registry('l10n_class') };

    # Grab all of the templates except the Widget Sets, because the user
    # should be able to edit (drag-drop) those all the time.
    my $iter = MT->model('template')
      ->load_iter( { blog_id => $blog_id, type => { not => 'backup' }, } );

    while ( my $tmpl = $iter->() ) {
        _link_template({
            tmpl    => $tmpl,
            plugin  => $cur_ts_plugin,
            blog_id => $blog_id,
            ts_id   => $ts_id,
        });
    }
} ## end sub _link_templates

# Link a template from the DB to the filesystem.
sub _link_template {
    my ($arg_ref) = @_;
    my $tmpl    = $arg_ref->{tmpl};
    my $plugin  = $arg_ref->{plugin};
    my $blog_id = $arg_ref->{blog_id};
    my $ts_id   = $arg_ref->{ts_id};

    # If no plugin object is supplied then give up because the template set
    # can't be found later. A missing plugin object is most likely the result
    # of trying to use the old Classic Blog (`mt_blog`) template set which is
    # core to MT but incomplete in many ways... plus, we probably don't want
    # to encourage linking to and modifying these templates because the
    # ramifications could be quite significant.
    return if !defined($plugin);

    # If translations are offered for this theme, just give up. We don't
    # want to try to link a theme that has translations because the
    # linking process will throw away the "__trans phrase" wrappers.
    # Yes, this is also checked in _link_templates, above. But if 
    # _link_template is called during the theme upgrade we need to make sure
    # to only link templates that should be linked.
    return if eval { $plugin->registry('l10n_class') };

    my $cur_ts_widgets
      = eval {$plugin->registry('template_sets', $ts_id, 'templates', 'widget')};

    if (
         ( ( $tmpl->type ne 'widgetset' ) && ( $tmpl->type ne 'widget' ) )
         || (    ( $tmpl->type eq 'widget' )
              && ( $cur_ts_widgets->{ $tmpl->identifier } ) )
      )
    {

        # Link the template to the source file in the theme. This has to
        # be crafted from several pieces.

        # The base_path is specified in the theme.
        my $base_path = $plugin->registry( 'template_sets', $ts_id,
                                           'base_path' );

        # The $tmpl->type needs to be fixed. Within the DB, "template
        # modules" have the template type of "custom," not "module" as
        # you might expect. Similarly, all of the system templates have
        # unique identifiers. We need to use the type that config.yaml
        # supplies so that the template identifier can be properly
        # looked-up, and therefore the correct path can be crafted.
        my ($config_yaml_tmpl_type)
          = grep { ( $tmpl->type || '' ) eq $_ }
          qw( index archive individual custom widget widgetset);

        # Template modules are called "custom" in the DB
        $config_yaml_tmpl_type = 'module'
          if $config_yaml_tmpl_type eq 'custom';

        # If none of the above, it must be a system template b/c they
        # each have a unique $tmpl->type.
        $config_yaml_tmpl_type ||= 'system';    # Default fallback value

        # Get the filename of the template. We need to check if the
        # "filename" key was used in the theme YAML and use that, or
        # just make up the filename based on identifier.
        my $tmpl_filename;
        if (
             $plugin->registry(
                                'template_sets',   $ts_id,
                                'templates',       $config_yaml_tmpl_type,
                                $tmpl->identifier, 'filename'
             )
          )
        {
            $tmpl_filename = 
              $plugin->registry( 'template_sets', $ts_id,
                   'templates', $config_yaml_tmpl_type, $tmpl->identifier,
                   'filename' );
        }
        else {
            # Theme Manager didn't find a "filename" key in the 
            # config.yaml for this template. That's not actually a problem 
            # because the template identifier can be used instead, and is
            # actually the more likely scenario.
            # require Carp;
            # my $warn = "Failed Theme Manager registry lookup for: "
            #   . join( ' > ',
            #           $cur_ts_plugin->name,   'template_sets',
            #           $ts_id,                 'templates',
            #           $config_yaml_tmpl_type, $tmpl->identifier, 
            #           'filename' )
            #   . ' '
            #   . Carp::longmess();
            # warn $warn;
            # MT->log($warn);

            # Use the template identifier as the file name.
            $tmpl_filename = $tmpl->identifier . '.mtml';
        }

        # Assemble the path to the source template.
        my $path = File::Spec->catfile( $plugin->path, $base_path,
                                        $tmpl_filename, );

        # Try to set the linked file to the source template path. First,
        # check to see if the path is writable. If not, complain in the
        # Activity Log.
        if ( -w $path ) {
            $tmpl->linked_file($path);
        }
        else {
            my $tm = MT->component('ThemeManager');
            MT->log( {
                   level   => MT->model('log')->ERROR(),
                   blog_id => $blog_id,
                   message =>
                     $tm->translate(
                       "The template \"[_1]\" could not be linked to the "
                         . "source template. Check permissions of \"[_2]\" "
                         . "(the source template file must be writable).",
                       $tmpl->name,
                       $path
                     ),
                }
            );
        }
    } ## end if ( ( ( $tmpl->type ne...)))
    else {

        # Just in case Widget Sets were previously linked,
        # now forcefully unlink!
        $tmpl->linked_file(undef);
    }

    # Lastly, save the linked (or unlinked) template.
    $tmpl->save or die 'Error saving template: '.$tmpl->errstr;
}

# Forcibly turn on module caching at the blog level, so that any theme cache
# options actually work.
sub _override_publishing_settings {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;
    $blog->include_cache(1);
    $blog->save
        or die 'Error saving blog: '.$blog->errstr;
}

sub _set_module_caching_prefs {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;
    my $app = MT->instance;

    my $ts_id = $blog->template_set or return;
    my $set = $app->registry( 'template_sets', $ts_id ) or return;
    my $tmpls = $app->registry( 'template_sets', $ts_id, 'templates' );
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

                $tmpl->save
                    or die 'Error saving blog: '.$tmpl->errstr;
            }
        }
    } ## end foreach my $t (qw( module widget ))
} ## end sub _set_module_caching_prefs

sub _parse_build_type {
    my ($type) = @_;
    return $type if ( $type =~ /^[0-4]$/ );
    require MT::PublishOption;
    if ( $type =~ /^disable/i ) {
        return MT::PublishOption::DISABLED();
    }
    elsif ( $type =~ /^static/i ) {
        return MT::PublishOption::ONDEMAND();
    }
    elsif ( $type =~ /^manual/i ) {
        return MT::PublishOption::MANUALLY();
    }
    elsif ( $type =~ /^dynamic/i ) {
        return MT::PublishOption::DYNAMIC();
    }
    elsif ( $type =~ /^async/i ) {
        return MT::PublishOption::ASYNC();
    }
    else {
        my $tm = MT->component('ThemeManager');
        MT->log( {
               level => MT->model('log')->WARNING(),
               message =>
                 $tm->translate(
                   "Unrecognized build_type parameter found in theme's config.yaml: [_1].",
                   $type
                 ),
            }
        );
    }

    # Default
    return MT::PublishOption::ONDEMAND();
} ## end sub _parse_build_type

sub _set_archive_map_publish_types {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;
    my $app = MT->instance;

    my $ts_id = $blog->template_set or return;
    my $set   = $app->registry( 'template_sets', $ts_id ) or return;
    my $tmpls = $app->registry( 'template_sets', $ts_id, 'templates' );
    my $tm    = MT->component('ThemeManager');
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
                    $tm->build_type(
                                    _parse_build_type( $map->{build_type} ) );
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
    my $app = MT->instance;

    my $ts_id = $blog->template_set or return;
    my $set   = $app->registry( 'template_sets', $ts_id ) or return;
    my $tmpls = $app->registry( 'template_sets', $ts_id, 'templates' );

    # Give up if there are no templates that match
    return unless eval { %{ $tmpls->{index} } };

    my $tm = MT->component('ThemeManager');

    foreach my $t ( keys %{ $tmpls->{index} } ) {
        if ( $tmpls->{index}->{$t}->{build_type} ) {
            my $tmpl = MT->model('template')
              ->load( { blog_id => $blog->id, identifier => $t, } );
            return unless $tmpl;
            $tmpl->build_type(
                   _parse_build_type( $tmpls->{index}->{$t}->{build_type} ) );
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
    _refresh_system_custom_fields($blog);
    _refresh_fd_fields($blog);
}

sub _refresh_system_custom_fields {
    my ($blog) = @_;
    return unless MT->component('Commercial');

    my $app   = MT->instance;
    my $tm    = MT->component('ThemeManager');
    my $ts_id = $blog->template_set or return;
    my $set   = $app->registry( 'template_sets', $ts_id ) or return;

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
    return unless $fields;

  FIELD: while ( my ( $field_id, $field_data ) = each %$fields ) {
        next if UNIVERSAL::isa( $field_data, 'MT::Component' );    # plugin
        my %field = %$field_data;
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
        my $field_obj = MT->model('field')->load( {
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
            $field_obj = MT->model('field')->new;
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
} ## end sub _refresh_system_custom_fields

sub _refresh_fd_fields {
    my ($blog) = @_;
    return unless MT->component('FieldDay');

    my $app   = MT->instance;
    my $ts_id = $blog->template_set or return;
    my $set   = $app->registry( 'template_sets', $ts_id ) or return;

    # Field Day fields are all defined under the fd_fields key. Install groups
    # first (in the group key), then install fields (in the fields key). That
    # way, if a field is in a group, the group already exists.
    while ( my ( $field_id, $field_data ) = each %{ $set->{fd_fields}->{group} } ) {
        _refresh_fd_field({
            field_id   => $field_id,
            field_data => $field_data,
            field_type => 'group',
            blog       => $blog,
        });
    }

    # Groups are created; now create fields.
    while ( my ( $field_id, $field_data ) = each %{ $set->{fd_fields}->{field} } ) {
        _refresh_fd_field({
            field_id   => $field_id,
            field_data => $field_data,
            field_type => 'field',
            blog       => $blog,
        });
    }
} ## end sub _refresh_fd_fields

# Process the individual Field Day group or field, installing or updating as
# needed.
sub _refresh_fd_field {
    my ($arg_ref) = @_;
    my $field_id   = $arg_ref->{field_id};
    my $field_data = $arg_ref->{field_data};
    my $field_type = $arg_ref->{field_type};
    my $blog       = $arg_ref->{blog};
    my $tm = MT->component('ThemeManager');

    return if UNIVERSAL::isa( $field_data, 'MT::Component' );    # plugin

    my $field_scope = ( $field_data->{scope}
                      && delete $field_data->{scope} eq 'system' ? 0 : $blog->id );

    # If the Field Day field definition is missing the required basic 
    # field definitions then we should report that problem immediately. In
    # Production Mode, just die immediately; in Designer Mode save the 
    # error to the Activity Log.
  REQUIRED: for my $required (qw( obj_type )) {
        next REQUIRED if $field_data->{$required};

        if ($blog->theme_mode eq 'designer') {
            MT->log( {
                       level   => MT->model('log')->ERROR(),
                       blog_id => $field_scope,
                       message => $tm->translate(
                               'Could not install Field Day field [_1]: '
                                 . 'field attribute [_2] is required',
                               $field_id,
                               $required,
                           ),
                     }
            );
            return;
        }
        else {
            die "Could not install Field Day field $field_id: field "
                . "attribute $required is required.";
        }
    }

    # Does the blog have a field with this basename?
    my $field_obj = MT->model('fdsetting')->load( {
                           blog_id     => $field_scope,
                           name        => $field_id,
                           object_type => $field_data->{obj_type} || q{},
                           type        => $field_data->{type} || 'field',
                         }
    );

    # This field exists already. Verify the type before proceeding.
    if ($field_obj) {

        # The field data type can't just be changed willy-nilly. Because
        # different data types store data in different formats and in 
        # different fields we can't expect to change to another field type
        # and just see things continue to work. Again, in Production Mode
        # the user should be notified immediately, while in Designer Mode
        # the error is written to the Activity Log.
        if ( $field_obj->type ne $field_type ) {
            if ($blog->theme_mode eq 'designer') {
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
            else {
                die "Could not install Field Day field $field_id on blog "
                    . $blog->name . ": the blog already has a field "
                    . "$field_id with a conflicting type.";
            }
        }
    }

    # This field doesn't exist yet.
    else {
        $field_obj = MT->model('fdsetting')->new;
    }

    my $data = $field_data->{data};

    # The label field needs to be dereferenced.
    $data->{label} = &{ $data->{label} };

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

    $field_obj->set_values( {
                              blog_id     => $field_scope,
                              name        => $field_id,
                              object_type => $field_data->{obj_type},
                              order       => $field_data->{order},
                              type        => $field_type,
                              data        => $data,
                            }
    );
    $field_obj->save()
        or die 'Error saving Field Day field: '.$field_obj->errstr;
}

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
            $obj->save
                or die 'Error saving '.$obj->class_type.': '.$obj->errstr;
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
            $obj->save
                or die 'Error saving '.$obj->class_type.': '.$obj->errstr;

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
                    $placement->save
                        or die 'Error saving category placement: '
                                .$placement->errstr;
                }
            } ## end if ( $p->{folder} )
        } ## end unless ($obj)
    } ## end foreach my $basename ( keys...)
} ## end sub _install_pages_or_entries

sub _install_default_content {
    my ( $cb, $param ) = @_;
    my $blog    = $param->{blog}      or return;
    my $ts_id   = $blog->template_set or return;
    my $set     = MT->instance->registry( 'template_sets', $ts_id ) or return;
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
    my $set = MT->instance->registry( 'template_sets', $ts_id ) or return;

    # Save the data to the theme_meta meta field.
    my $meta = prepare_theme_meta($ts_id);
    my $yaml = YAML::Tiny->new;
    $yaml->[0] = $meta;

    # Turn that YAML into a plain old string and save it.
    $blog->theme_meta( $yaml->write_string() );
    $blog->save or die 'Error saving blog: '.$blog->errstr;
}

sub xfrm_add_language {

    # When a user is creating a new blog, we need to get in and update the
    # selections with language options. (and maybe others, in the future?) This
    # works by setting the mt_blog.blog_language field to the desired language.
    my ( $cb, $app, $tmpl ) = @_;

    my $old = q{<mt:setvarblock name="html_head" append="1">};
    my $add = <<'HTML';
<mt:unless tag="ProductName" eq="Melody">
<script src="<mt:Var name="static_uri">jquery/jquery.js" type="text/javascript"></script>
</mt:unless>
<script type="text/javascript">
jQuery(document).ready( function($) {
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
        my $ts_plugin = MT->component( $theme->plugin_sig );
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

# The user wants to switch an applied theme's mode: from Designer to 
# Production mode, or from Production to Designer mode.
sub theme_mode_switch {
    my $app = shift;
    my $q   = $app->query;
    
    # Which mode do we want to switch to? Possible values are "designer" and
    # "production."
    my $switch_to = $q->param('switch_to');
    
    my $blog = MT->model('blog')->load( $q->param('blog_id') )
        or die 'Could not load the specified blog.';

    # Set the theme mode to the selected value. This will be used as a flag
    # for handling upgrades.
    $blog->theme_mode( $switch_to );
    $blog->save or die 'Error saving blog: '.$blog->errstr;
    
    # Change whether templates are linked.
    # Switching from Designer to Production mode, so unlink templates.
    if ($switch_to eq 'production') {

        # Unlink all templates.
        my $iter = MT->model('template')->load_iter({ blog_id => $blog->id });
        while ( my $tmpl = $iter->() ) {
            $tmpl->linked_file(undef);
            $tmpl->linked_file_mtime(undef);
            $tmpl->linked_file_size(undef);
            $tmpl->save
                or die 'Error saving template: '.$tmpl->errstr;
        }
    }
    
    # Switching from Production to Designer mode: link templates.
    else {
        _link_templates(undef, { blog => $blog });
    }
    
    # Go back to the theme dashbaord, displaying a success message.
    $app->redirect(
        $app->uri . '?__mode=theme_dashboard&blog_id=' . $blog->id
        . '&mode_switched=1'
    );
}

# A newer version of the installed theme is available. The user has clicked
# the "Upgrade theme to version x.x" button, and a pop-up appears, built by
# this method.
sub theme_upgrade_proposal {
    my $app   = shift;
    my $q     = $app->query;
    my $param = {};
    
    my ($blog) = MT->model('blog')->load( $q->param('blog_id') );
    $param->{blog_name} = $blog->name;

    my $plugin  = find_theme_plugin( $blog->template_set );
    my $new_theme_meta = $app->registry( 'template_sets', $blog->template_set);
    my $installed_theme_meta 
        = eval { YAML::Tiny->read_string( $blog->theme_meta )->[0] };

    # Populate the screen with brief version information.
    $param->{theme_upgrade_version_num} 
        = $new_theme_meta->{version} || $plugin->version;
    $param->{theme_label} 
        = theme_label( $installed_theme_meta->{label}, $plugin );
    $param->{theme_version}
        = theme_version( $installed_theme_meta->{version}, $plugin );

    # Check which templates are new and which existing templates need 
    # updating.
    $param = _upgrade_check_templates({
        param  => $param,
        blog   => $blog,
        plugin => $plugin,
    });

    # Check if Custom Fields and Field Day fields exist with this theme and
    # note that should will be (potentially) updated. These should be more
    # thoroughly checked, like the templates...
    $param = _upgrade_check_fields({
        param          => $param,
        new_theme_meta => $new_theme_meta,
    });
    
    # Check if there is anything to upgrade based on the above results. If
    # nothing has changed then the theme can't be upgraded because there's
    # nothing to do. Supply a notice to the user about this state.
    if (
        !@{ $param->{new_templates} }
        && !@{ $param->{changed_templates} }
        && !$param->{updated_cf_fields}
        && !$param->{updated_fd_fields}
    ) {
        $param->{no_change} = 1;
    }

    return $app->load_tmpl( 'theme_upgrade.mtml', $param);
}

# Determine what needs to be done to upgrade a theme. This will check if any
# new templates need to be installed or if any existing templates need to be
# updated. The param hash is used to inform the user of what is changing.
sub _upgrade_check_templates {
    my ($arg_ref) = @_;
    my $param  = $arg_ref->{param};
    my $blog   = $arg_ref->{blog};
    my $plugin = $arg_ref->{plugin};
    my $app    = MT->instance;

    # Create a list of the changed and new templates to be updated.
    my (@changed_templates, @new_templates);

    # Compare the on-disk templates to the in-DB templates so that we can know
    # if they are being updated, and which ones.
    require MT::DefaultTemplates;
    my $tmpl_list = MT::DefaultTemplates->templates( $blog->template_set );
    if ( !$tmpl_list || ( ref($tmpl_list) ne 'ARRAY' ) || ( !@$tmpl_list ) ) {
        return $blog->error(
                         $app->translate("No default templates were found.") );
    }

    foreach my $disk_tmpl (@$tmpl_list) {

        # Look at this template to determine if any new templates should
        # be installed. If a template is listed in config.yaml but not found
        # in the DB, then tell the user a new template(s) will be installed.
        my ($db_tmpl) = MT->model('template')->load({ 
            blog_id    => $blog->id,
            identifier => $disk_tmpl->{identifier},
        });
        
        # This template was not found in the DB.
        if (!$db_tmpl) {

            # Tell the user about the new templates being installed
            push @new_templates,
                {
                    name       => $disk_tmpl->{label},
                    type       => $disk_tmpl->{type},
                    identifier => $disk_tmpl->{identifier},
                };
            
            next; # Go to the next template because there's nothing more to do.
        }

        # Look at this template to determine if any existing templates need 
        # to be updated. Compare the actual template (text) to determine if 
        # anything changed. Don't compare the template meta (build type or 
        # caching, for example) because that's something that may have been 
        # purposefully customized, and we don't want to overwrite that.
        # The source template should be translated before trying to compare it 
        # to the already-translated template in the DB.
        my $disk_tmpl_trans = $disk_tmpl->{text} || '';
        eval {
            $disk_tmpl_trans = $plugin->translate_templatized($disk_tmpl_trans);
            1;
        };
        
        # Compare an MD5 hash of the templates to tell if they changed. Skip
        # over any 'widgetset' template type because these have likely changed
        # and we don't want to check them.

	my ($disk_tmpl_md5, $db_tmpl_md5);
	{
	    # Fixes 'wide character in print' error thrown by md5_hex when its
            # argument contains a wide character (e.g. Unicode).
            # See http://onkeypress.blogspot.com/2011/07/perl-wide-character-in-subroutine-entry.html
	    use bytes;
	    $disk_tmpl_md5 = md5_hex( $disk_tmpl_trans ."" );
	    $db_tmpl_md5   = md5_hex( $db_tmpl->text   ."" );
	}
        if (     $disk_tmpl->{type} ne 'widgetset'
             and $disk_tmpl_md5 ne $db_tmpl_md5
        ) {

            # This template is going to be updated. We want to warn the user
            # of this, so let's compile a list of changed templates
            push @changed_templates,
                {
                    name       => $db_tmpl->name,
                    identifier => $db_tmpl->identifier,
                    id         => $db_tmpl->id,
                };

            next;
        }
    }

    # Add the above collected information to the parameter hash.
    $param->{new_templates}     = \@new_templates;
    $param->{changed_templates} = \@changed_templates;

    return $param;
}

# Determine what needs to be done to upgrade a theme. This will check if any
# Custom Fields or Field Day fields need to be installed/updated and updates
# the param hash to inform the user of this.
sub _upgrade_check_fields {
    my ($arg_ref) = @_;
    my $param          = $arg_ref->{param};
    my $new_theme_meta = $arg_ref->{new_theme_meta};

    # This really isn't a test to tell if CF of FD fields have *changed*, it
    # just notes if they exist. This could be much more comprehensive!
    if ( $new_theme_meta->{fields} ) {
        $param->{updated_cf_fields} = 1;
    }

    if ( $new_theme_meta->{fd_fields} ) {
        $param->{updated_fd_fields} = 1;
    }

    return $param;
}

# An upgrade to this theme is available. The user has clicked to learn about 
# the upgrade and the changes that will occur, and has chosen to proceed. Now,
# actually do the upgrade!
sub theme_upgrade_action {
    my $app    = shift;
    my $q      = $app->query;
    my $param  = {};
    my $blog   = MT->model('blog')->load( $q->param('blog_id') );
    my $plugin = find_theme_plugin( $blog->template_set );

    # In the theme_upgrade_proposal we set some variables to save some effort 
    # here: If an item is marked then it should be upgraded; no need to 
    # recheck everything.
    my $updated_cf_fields = $q->param('updated_cf_fields') || '';
    my $updated_fd_fields = $q->param('updated_fd_fields') || '';
    my @new_templates     = $q->param('new_templates')
        ? $q->param('new_templates')
        : (); # An empty array if no new templates.

    # Only upgrade the changed templates if the user has acknowledged that
    # they may be overwriting manually-added changes.
    my @changed_templates = $q->param('upgrade_existing_templates')
        ? $q->param('changed_templates') 
        : (); # An empty array if no new templates.

    # Actually do the upgrade, based on all of the above submitted info.
    my $results = _do_theme_upgrade({
        blog              => $blog,
        plugin            => $plugin,
        updated_cf_fields => $updated_cf_fields,
        updated_fd_fields => $updated_fd_fields,
        new_templates     => \@new_templates,
        changed_templates => \@changed_templates,
    });

    # Report the success/fail messages to the user. This basically just tells
    # them what was upgraded, because fail messages should cause the app to 
    # die, hopefully forcing a theme designer to ensure their theme 100% works
    # before making it available.
    $param->{theme_upgrade_results_messages} = $results->{messages};

    # The theme upgrade has completed. Tell the user.
    $param->{theme_upgrade_complete} = 1;

    my $theme_meta 
        = eval { YAML::Tiny->read_string( $blog->theme_meta )->[0] };

    # Populate the screen with brief version information.
    $param->{theme_label} 
        = theme_label( $theme_meta->{label}, $plugin );
    $param->{theme_version}
        = theme_version( $theme_meta->{version}, $plugin );

    # Report that the upgrade was successful!
    return $app->load_tmpl( 'theme_upgrade.mtml', $param );
}

# This function is responsible for completing the theme upgrade. It is used
# for manual, user-initiated upgrades (in Production Mode) and automatic 
# upgrades (in Designer Mode). Returns a results hash with messages about the
# upgrade success/failure.
sub _do_theme_upgrade {
    my ($arg_ref) = @_;
    my $blog              = $arg_ref->{blog};
    my $plugin            = $arg_ref->{plugin};
    my $updated_cf_fields = $arg_ref->{updated_cf_fields};
    my $updated_fd_fields = $arg_ref->{updated_fd_fields};
    my @new_templates     = @{$arg_ref->{new_templates}};
    my @changed_templates = @{$arg_ref->{changed_templates}};
    my $app = MT->instance;
    my @results; # Return success/fail messages.

    # Update the Custom Fields and Field Day fields, if necessary.
    if ($updated_cf_fields) {
        _refresh_system_custom_fields($blog);
        push @results, { message => 'Custom Fields have been refreshed.' };
    }
    if ($updated_fd_fields) {
        _refresh_fd_fields($blog) if $updated_fd_fields;
        push @results, { message => 'Field Day fields have been refreshed.' };
    }

    # Does anything need to be done with templates?
    if (@new_templates || @changed_templates) {
        require MT::DefaultTemplates;
        my $tmpl_list = MT::DefaultTemplates->templates( $blog->template_set );
        if ( !$tmpl_list || ( ref($tmpl_list) ne 'ARRAY' ) || ( !@$tmpl_list ) ) {
            return $blog->error(
                             $app->translate("No default templates were found.") );
        }

        # Any upgraded templates also get a backup of the original created.
        # Create a timestamp to apply to the backup, which can be applied to
        # all of the templates backups created.
        my @ts = offset_time_list( time, $blog->id );
        my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $ts[5] + 1900,
          $ts[4] + 1, @ts[ 3, 2, 1, 0 ];

        foreach my $new_tmpl (@$tmpl_list) {

            # New templates need to be installed. Look for the current 
            # template identifier in the @new_templates array. If found, add
            # the template.
            if ( grep $_ eq $new_tmpl->{identifier}, @new_templates ) {

                # This is a new template that needs to be installed. Before
                # installing, just do a quick check to ensure it doesn't 
                # exist, though.
                if (
                    ! MT->model('template')->exist({ 
                        blog_id    => $blog->id,
                        identifier => $new_tmpl->{identifier},
                    })
                ) {
                    # Is there a manually created version of this template in
                    # the theme? If so it needs to be retired so that the new
                    # template can be installed.
                    my $message = _retire_template({
                        blog_id  => $blog->id,
                        new_tmpl => $new_tmpl,
                    });

                    push @results, { message => $message }
                        if $message;

                    # This template does not exist, so create it!
                    my $tmpl = _create_template($new_tmpl, $blog, $plugin);

                    if ($tmpl) {
                        $message = 'A new template, "' . $tmpl->name 
                            . '," has been installed.';
                        push @results, { message => $message };
                        MT->log({
                            level   => MT->model('log')->INFO(),
                            blog_id => $blog->id,
                            message => 'Theme upgrade: ' . $message,
                        });
                    }

                    # Move on to the next template; there's nothing more to
                    # with this one!
                    next;
                }
            }

            # Existing templates need to be updated. The parameter 
            # "upgrade_existing_templates" is a checkbox the user has 
            # previously selected, acknowledging that upgrading templates 
            # could overwrite any of their manually added changes. Also, look
            # for the current template identifier in the @changed_templates 
            # array. If found, we need to upgrade the template. Update the 
            # actual template text only, not any of the template meta because 
            # the user may have purposefully changed that.
            elsif ( grep $_ eq $new_tmpl->{identifier}, @changed_templates ) {
                my ($db_tmpl) = MT->model('template')->load({
                    blog_id    => $blog->id,
                    identifier => $new_tmpl->{identifier},
                })
                    or die 'Can not find a template with the identifer '
                        . $new_tmpl->{identifier} . ' in blog ' . $blog->name;

                # Create a backup of the existing template.
                my $tmpl_backup = MT->model('template')->new();
                $tmpl_backup->name(   $db_tmpl->name
                             . " (Backup from $ts) "
                             . $db_tmpl->type );
                $tmpl_backup->text( $db_tmpl->text );
                $tmpl_backup->type('backup');
                $tmpl_backup->blog_id( $blog->id );
                $tmpl_backup->save
                    or die 'Error saving template: '.$tmpl_backup->errstr;

                # Translate the template to another language, if translations 
                # were provided.
                my $trans = $new_tmpl->{text};
                eval {
                    $trans = $plugin->translate_templatized($trans);
                    1;
                  }
                  or die "There was an error translating the template '"
                        . $new_tmpl->{name} . ".' Error: " . $@;

                $db_tmpl->text( $trans );
                $db_tmpl->save
                    or die 'Error saving template: '.$db_tmpl->errstr;

                my $message = 'The template "' . $db_tmpl->name 
                    . '" has been upgraded.';
                push @results, { message => $message };
                MT->log({
                    level   => MT->model('log')->INFO(),
                    blog_id => $blog->id,
                    message => 'Theme upgrade: ' . $message,
                });

                # Delete any caching for this template.
                my $key = 'blog::' . $blog->id . '::template_' 
                    . $db_tmpl->type . '::' . $db_tmpl->name;
                MT->model('session')->remove( { id => $key });
            }
        }
    }

    # Update the theme meta in the DB so that the new version number is 
    # reflected (as well as any other changes to the theme meta, too, of 
    # course)
    _save_theme_meta( undef, {blog => $blog} );

    # Return the results array, which is populated with success/fail messages.
    return { messages => \@results};
}

# Before installing a new template, check for a manually created template with
# the same name (but no identifier because it was manually created). Check for
# an existing template with the name name, which could have been created
# manually and therefore doesn't have the template identifier assigned to it.
sub _retire_template {
    my ($arg_ref) = @_;
    my $new_tmpl = $arg_ref->{new_tmpl};
    my $blog_id  = $arg_ref->{blog_id};

    my $existing_tmpl = MT->model('template')->load({
        blog_id => $blog_id,
        type    => $new_tmpl->{type},
        name    => $new_tmpl->{name},
    })
        or return;

    # Build a timestamp to append to the retired tempalte.
    my @ts = offset_time_list( time, $blog_id );
    my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d",
        $ts[5] + 1900, $ts[4] + 1, @ts[ 3, 2, 1, 0 ];

    # Rename the template to something unique so that the new template can be
    # installed.
    $existing_tmpl->name( $new_tmpl->{name} . " [Retired $ts]" );
    $existing_tmpl->save
        or die 'Error saving template: '.$existing_tmpl->errstr;


    # Notify the user about this fringe case.
    return 'A template named "' . $new_tmpl->{name} . '" already exists '
        . '(perhaps it was manually created?) and has been retired. You may '
        . 'wish to review the changes between the current and retired '
        . 'templates.'
}

1;

__END__
