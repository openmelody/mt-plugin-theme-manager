package ThemeManager::Plugin;

use strict;
use ConfigAssistant::Util qw( find_theme_plugin );
use ThemeManager::Util qw( theme_label theme_thumbnail_url theme_preview_url
  theme_description theme_author_name theme_author_link
  theme_paypal_email theme_version theme_link theme_doc_link
  theme_about_designer theme_documentation theme_thumb_path theme_thumb_url
  prepare_theme_meta );
use MT::Util qw(caturl dirify offset_time_list);
use MT;


sub update_menus {
    my $app = MT->instance;
    my $q = $app->query;

    # Theme Manager is turning the Design menu into a friendlier, more useful
    # area than it used to be, and the first step to that is removing the
    # Templates option. Templates can now be found within the Theme Dashboard
    # We only want to remove the Templates menu at the blog-level. We don't
    # know for sure what templates are at the system-level, so just blanket
    # denying access is probably not best.
    my $blog_id = $q->param('blog_id');
    if ($blog_id) {

        # FIXME This should be done in a pre_run or init_request callback like so:
        #           my $a = $app->registry('menus');
        #           delete $a->{'design:template'};
        #       but don't do that here or else you'll get into a loop
        my $core = MT->component('Core');
        my $tmpl_menu_item
            = $core->{registry}{applications}{cms}{menus}{'design:template'};
        # use Data::Dumper;     warn Dumper([keys %$tmpl_menu_item]);                                                                                                                                                                                         
        $tmpl_menu_item->{view}      = 'system';
        $tmpl_menu_item->{condition} = sub { ! eval { MT->instance->query->param('blog_id') } };
    }

    # Now just add the Theme Dashboard menu item.
    # TODO Move to config.yaml
    return {
        'design:theme_dashboard' => {
                                      label      => 'Theme Dashboard',
                                      order      => 1,
                                      mode       => 'theme_dashboard',
                                      view       => 'blog',
        },

        # Add the theme documentation to the menu to make it more prominent,
        # if documentation is provided with this theme.
        'design:theme_documentation' => {
            label => 'Theme Documentation',
            order => 2,
            view => 'blog',
            condition => sub {
                my $blog = $app->blog          or return 0;
                my $bts  = $blog->template_set or return 0;
                return eval {
                    $app->registry('template_sets', $bts, 'documentation')
                }; # Non-null evals to true value
            },
            link       => sub {
                return
                  $app->uri(
                             mode => 'theme_dashboard',
                             args => { blog_id => $app->blog->id, },
                  ) . '#docs';    # Go to Documentation.
            },
        },

        # Add the new template menu option, which is actually a link to the
        # Theme Dashboard > Templates screen.
        'design:templates' => {
            label      => 'Templates',
            order      => 1000,
            view       => 'blog',
            permission => 'edit_templates',
            link       => sub {
                return
                  $app->uri(
                             mode => 'theme_dashboard',
                             args => { blog_id => $app->blog->id, },
                  ) . '#templates';    # Go to Manage Templates.
            },
        },
    };
} ## end sub update_menus

sub update_page_actions {
    my $app     = MT->instance;
    my $q       = $app->query;
    my $blog_id = $q->param('blog_id');
    my $blog    = eval { $app->blog };
    
    if ($blog_id) {

        # FIXME This should be done in a pre_run or init_request callback like so:
        #       and it should just be:
        #           my $a = $app->registry('page_actions', 'list_templates');
        #           delete $a->{refresh_all_blog_templates};
        #       but don't do that here or else you'll get into a loop
        my $core = MT->component('Core');

        # Delete the Refresh Blog Templates page action because we don't want
        # people to use this page action--they can apply a theme, instead.
        delete $core->{registry}->{applications}->{cms}->{page_actions}
          ->{list_templates}->{refresh_all_blog_templates};
    }

    # TODO Move these to the config.yaml but break out the perl code into methods
    return {
        list_templates => {
            refresh_fields => {
                label      => "Refresh Custom Fields",
                order      => 1,
                permission => 'edit_templates',
                condition  => sub {
                    MT->component('Commercial') && $blog;
                },
                code => sub {
                    $app->validate_magic or return;
                    ThemeManager::TemplateInstall::_refresh_system_custom_fields(
                                                                       $blog);
                    $app->add_return_arg( custom_fields_refreshed => 1 );
                    $app->call_return;
                },
            },
            refresh_fd_fields => {
                label      => "Refresh Field Day fields",
                order      => 2,
                permission => 'edit_templates',
                condition  => sub {
                    MT->component('FieldDay') && $blog;
                },
                code => sub {
                    $app->validate_magic or return;
                    ThemeManager::TemplateInstall::_refresh_fd_fields($blog);
                    $app->add_return_arg( fd_fields_refreshed => 1 );
                    $app->call_return;
                },
            },
            template_backups => {
                label      => 'View Template Backup Sets',
                order      => 10,
                permission => 'edit_templates',
                condition  => sub {
                    # Don't display on the Global Templates screen.
                    return 1 if $blog
                            and MT->model('template')->exist({
                                    type => 'backup',
                                    blog_id => $blog->id,
                                });
                    return 0;
                },
                mode => 'list_template_backups',
            },
            theme_upgrade => {
                label => 'Upgrade Theme',
                order => 20,
                permission => 'edit_templates',
                condition => sub {
                    # Designer Mode doesn't need the ability to upgrade, since
                    # it happens automatically.
                    my $theme_mode = eval { $blog->theme_mode } || '';
                    return $theme_mode eq 'designer' ? 0 : 1;
                                            # Must be production mode, right?
                },
                dialog => 'theme_upgrade',
            },
        },
        list_template_backups => {
            delete_all_backups => {
                label => 'Delete all Template Backup Sets',
                order => 1,
                permission => 'edit_templates',
                dialog => 'delete_tmpl_backups',
            },
        },
        theme_dashboard => {
            theme_options => {
                label     => 'Edit Theme Options',
                order     => 100,
                mode      => 'theme_options',
                condition => sub {
                    my $ts_id = eval { $blog->template_set };
                    if ( MT->component('ConfigAssistant') and $ts_id ) {
                        return 1 if
                          eval {
                            $app->registry('template_sets')->{$ts_id}->{options}
                          }
                    }
                    return 0;
                },
            },
            edit_widgets => {
                label     => 'Create Widgets and organize Widget Sets',
                order     => 101,
                mode      => 'list_widget',
                condition => sub {
                    if ( my $ts_id = eval { $blog->template_set } ) {
                        return 1 if
                          eval {
                            $app->registry( 'template_sets', $ts_id,
                                            'templates',     'widgetset' );
                          };
                    }
                    return 0;
                },
            },
        },
    };
} ## end sub update_page_actions

sub theme_dashboard {
    my $app = shift;
    my $q = $app->query;

    # Since there is no Theme Dashboard at the system level, capture and
    # redirect to the System Dashboard, if necessary.
    my $blog = $app->blog
      or $app->redirect( $app->uri . '?__mode=dashboard&blog_id=0' );

    my $ts_id  = $blog->template_set;
    my $tm     = MT->component('ThemeManager');
    my $plugin = find_theme_plugin($ts_id);
    my $param  = {};

    # Populate the theme dashboard with all sort of info about the theme:
    # label, description, author, etc.
    $param = _populate_theme_dashboard($blog, $param, $plugin);

    # Grab the template set language, or fall back to the blog language.
    my $template_set_language = $blog->template_set_language
                             || $blog->language;
    $param->{template_set_language} = $template_set_language
        if $blog->language ne $template_set_language;

    # TODO This kind of construct indicates that we need to be our own app class
    _populate_list_templates_context( $app, $param );

    # The user probably wants to apply a new theme; we start by browsing the
    # available themes.
    # Save themes to the theme table, so that we can build a listing screen from them.
    _theme_check();

    # Set the number of themes to appear per page. We set it to 999 just so
    # that there is no pagination, because paginating through themes kind
    # of sucks. However, if unset, it defaults to 25!
    my $list_pref = $app->list_pref('theme') if $app->can('list_pref');
    $list_pref->{rows} = 999;

    $param->{theme_dashboard_page_actions}
      = $app->page_actions('theme_dashboard');
    $param->{template_page_actions} = $app->page_actions('list_templates');

    # System messages for the user
    $param->{new_theme}               = $q->param('new_theme');
    $param->{custom_fields_refreshed} = $q->param('custom_fields_refreshed');
    $param->{fd_fields_refreshed}     = $q->param('fd_fields_refreshed');
    $param->{mode_switched}           = $q->param('mode_switched');

    # Grab the user's permissions to decide what tabs and content to display 
    # on the theme dashboard.
    my $perms = $app->blog ? $app->permissions : $app->user->permissions;
    return $app->return_to_dashboard( redirect => 1 )
        unless $perms || $app->user->is_superuser;
    
    # If adequate permissions, return true; else false.
    $param->{has_permission} = ( $perms && $perms->can_edit_templates )
        ? 1 : 0;


    my $tmpl = $tm->load_tmpl('theme_dashboard.mtml');
    return $app->listing( {
           type     => 'theme',
           template => $tmpl,
           args     => { sort => 'ts_label', direction => 'ascend', },
           params   => $param,
           code     => sub {
               my ( $theme, $row ) = @_;

               # Use the plugin sig to grab the plugin.
               my $plugin = MT->component( $theme->plugin_sig );

               # This plugin couldn't be loaded! That must mean the theme has
               # been uninstalled, so remove the entry in the table.
               if ( !$plugin ) {
                   $theme->remove;
                   $theme->save or die $theme->errstr;
                   return;
               }
               $row->{id}         = $theme->ts_id;
               $row->{plugin_sig} = $theme->plugin_sig;
               $row->{label}      = theme_label( $theme->ts_label, $plugin );

               # Convert the saved YAML back into a hash.
               my $theme_meta = YAML::Tiny->read_string( $theme->theme_meta );
               $theme_meta = $theme_meta->[0];

               $row->{thumbnail_url}
                 = theme_thumbnail_url( $theme_meta->{thumbnail},
                                        $plugin->id );

               return $row;
           },
        }
    );
} ## end sub theme_dashboard

sub select_theme {
    my $app = shift;
    my $q = $app->query;

    # The user probably wants to apply a new theme; we start by browsing the
    # available themes.
    # Save themes to the theme table, so that we can build a listing screen from them.
    _theme_check();

    # If the user is applying a theme to many blogs, they've come from a list
    # action, and the ID parameter is full of blog IDs. Pass these along to
    # the template.
    my $blog_ids = join( ',', $q->param('id') );

    # Terms may be supplied if the user is searching.
    my $search_terms = $q->param('search');

    # Unset the search parameter to that the $app->listing won't try to build
    # a search result.
    $q->param( 'search', '' );
    my @terms;
    if ($search_terms) {

        # Create an array of the search terms. "Like" lets us do the actual
        # search portion, while the "=> -or =>" lets us match any field.
        @terms
          = ( { ts_label => { like => '%' . $search_terms . '%' } } => -or =>
              { ts_desc => { like => '%' . $search_terms . '%' } } => -or =>
              { ts_id   => { like => '%' . $search_terms . '%' } } => -or =>
              { plugin_sig => { like => '%' . $search_terms . '%' } } );
    }
    else {

        # Terms needs to be filled with something, otherwise it throws an
        # error. Apparently, *if* an array is used for terms, MT expects
        # there to be something in it, so undef'ing the @terms doesn't
        # help. This should match anything.
        @terms = ( { ts_label => { like => "%%" } } );
    }

    # Set the number of items to appear on the theme grid. 6 fit, so that's
    # what it's set to here. However, if unset, it defaults to 25!
    my $list_pref = $app->list_pref('theme') if $app->can('list_pref');
    $list_pref->{rows} = 999;


    my $tm   = MT->component('ThemeManager');
    my $tmpl = $tm->load_tmpl('theme_select.mtml');
    return $app->listing( {
           type     => 'theme',
           template => $tmpl,
           terms    => \@terms,
           args     => { sort => 'ts_label', direction => 'ascend', },
           params   => {
               search   => $search_terms,
               blog_ids => $blog_ids,
               blog_id =>
                 $blog_ids,  # If there's only one blog ID, it gets used here.
           },
           code => sub {
               my ( $theme, $row ) = @_;

               # Use the plugin sig to grab the plugin.
               my $plugin = MT->component( $theme->plugin_sig );
               if ( !$plugin ) {

                   # This plugin couldn't be loaded! That must mean the theme has
                   # been uninstalled, so remove the entry in the table.
                   $theme->remove;
                   $theme->save or die $theme->errstr;
                   next;
               }

               # Convert the saved YAML back into a hash.
               my $yaml       = YAML::Tiny->new;
               my $theme_meta = YAML::Tiny->read_string( $theme->theme_meta );
               $theme_meta = $theme_meta->[0];

               $row->{thumbnail_url}
                 = theme_thumbnail_url( $theme_meta->{thumbnail},
                                        $plugin->id );
               $row->{preview_url}
                 = theme_preview_url( $theme_meta->{preview}, $plugin->id );

               $row->{id} = $theme->ts_id;
               $row->{label} = theme_label( $theme_meta->{label}, $plugin );
               $row->{description}
                 = theme_description( $theme_meta->{description}, $plugin );
               $row->{author_name}
                 = theme_author_name( $theme_meta->{author_name}, $plugin );
               $row->{version}
                 = theme_version( $theme_meta->{version}, $plugin );
               $row->{theme_link}
                 = theme_link( $theme_meta->{link}, $plugin );
               $row->{theme_doc_link}
                 = theme_doc_link( $theme_meta->{doc_link}, $plugin );
               $row->{about_designer}
                 = theme_about_designer( $theme_meta->{about_designer},
                                         $plugin );
               $row->{plugin_sig} = $theme->plugin_sig;
               $row->{theme_details}
                 = $app->load_tmpl( 'theme_details.mtml', $row );

               return $row;
           },
        }
    );
} ## end sub select_theme

# The user has selected a theme and wants to apply it to the current blog.
sub setup_theme {
    my $app = shift;
    my $q   = $app->query;
    my $tm  = MT->component('ThemeManager');

    my $ts_id      = $q->param('theme_id');
    my $plugin_sig = $q->param('plugin_sig');

    # Theme data is cached so that we can load and just display as necessary.
    my $theme = MT->model('theme')
      ->load( { ts_id => $ts_id, plugin_sig => $plugin_sig, } );

    my @blog_ids;
    if ( $q->param('blog_ids') ) {
        @blog_ids = split( /,/, $q->param('blog_ids') );
    }
    else {
        @blog_ids = ( $q->param('blog_id') );
    }

    my $param = {};
    $param->{ts_id}      = $ts_id;
    $param->{plugin_sig} = $plugin_sig;
    if ( scalar @blog_ids > 1 ) {
        $param->{blog_ids} = join( ',', @blog_ids );
    }
    else {
        $param->{blog_id} = $blog_ids[0];
    }

    # Find the template set and grab the options associated with it, so that
    # we can determine if there are any "required" fields to make the user
    # set up. If there are, we want them to look good (including being sorted)
    # into alphabeticized fieldsets and to be ordered correctly with in each
    # fieldset, just like on the Theme Options page.
    my $plugin = MT->component($plugin_sig);

    my $ts = $plugin->registry('template_sets', $ts_id);

    # Convert the saved YAML back into a hash.
    my $theme_meta
      = eval { YAML::Tiny->read_string( $theme->theme_meta )->[0] };
    $param->{ts_label} = theme_label( $theme_meta->{label}, $plugin );

    # We need to give the user a chance to install the theme in either
    # Production Mode or Designer Mode.
    $param->{theme_mode} = $q->param('theme_mode');
    if ( $q->param('theme_mode') ) {

        # Save the theme mode selection
        foreach my $blog_id (@blog_ids) {
            my $blog = MT->model('blog')->load($blog_id);
            $blog->theme_mode( $q->param('theme_mode') );
            $blog->save or die $blog->errstr;
        }
    }
    
    # If the System-level Default Mode option was set to Production, then we
    # should always use Production mode for this install.
    elsif ( $tm->get_config_value('theme_mode') eq 'Production' ) {

        # Save the theme mode selection
        foreach my $blog_id (@blog_ids) {
            my $blog = MT->model('blog')->load($blog_id);
            $blog->theme_mode('production');
            $blog->save or die $blog->errstr;
        }
    }

    # The desired theme mode hasn't been selected yet.
    else {
        return $app->load_tmpl( 'theme_mode.mtml', $param );
    }

    # Check for the widgetsets beacon. It will be set after visiting the
    # "Save Widgets" screen. Or, we may bypass it because we don't always
    # need to show the "Save Widgets" screen.
    # Also, bypass the option to save widgets if we are mass-applying themes.
    # Bulk applying means we probably are just trying to wipe everything back
    # to a clean slate.
    if ( ( scalar @blog_ids == 1 ) && !$q->param('save_widgetsets_beacon') ) {

        # Because the beacon hasn't been set, we need to first determine if
        # we should show the Save Widgets screen.
        foreach my $blog_id (@blog_ids) {

            # Check the currently-used template set against the returned
            # widgetsets to determine if we need to give the user a chance
            # to save things.
            my $blog          = MT->model('blog')->load($blog_id);
            my $cur_ts_id     = $blog->template_set;
            my $cur_ts_plugin = find_theme_plugin($cur_ts_id);
            unless ($cur_ts_plugin) {
                MT->log( {
                       level   => MT->model('log')->ERROR(),
                       blog_id => $blog_id,
                       message =>
                         $tm->translate(
                               'Theme Manager could not '
                             . 'find a plugin corresponding to the template set '
                             . 'currently applied to this blog. Skipping this '
                             . 'blog for saving widget sets.'
                         ),
                    }
                );
                next;
            }

            # Grab the templates for the theme that the user selected, so that
            # they can be used to inspect the Widget Sets and Widgets.
            require MT::DefaultTemplates;
            my $tmpl_list = MT::DefaultTemplates->templates( $ts_id );
            if ( !$tmpl_list || ( ref($tmpl_list) ne 'ARRAY' ) || ( !@$tmpl_list ) ) {
                return $app->errtrans( "No default templates were found." );
            }

            foreach my $new_tmpl (@$tmpl_list) {
                next unless (
                    $new_tmpl->{type} eq 'widgetset' 
                    || $new_tmpl->{type} eq 'widget'
                );

                # Look at the Widget Sets in the selected theme, and compare
                # them to the Widget Sets in the currently-installed theme.
                if (
                    $new_tmpl->{type} eq 'widgetset'
                    && (
                        # Any installed Widget Sets with this identifier?
                        MT->model('template')->exist({
                            blog_id    => $blog_id,
                            type       => 'widgetset',
                            identifier => $new_tmpl->{identifier},
                        })
                        # Or, any installed Widget Sets with this name?
                        || MT->model('template')->exist({
                            blog_id => $blog_id,
                            type    => 'widgetset',
                            name    => $new_tmpl->{name},
                        })
                    )
                ) {
                    # Yes, there are. Ask the user if they want to keep them.
                    $param->{if_save_widgetsets} = 1;
                }

                # Now compare the Widgets in the selected theme, and compare
                # them to the Widget in the currently-installed theme.
                if (
                    $new_tmpl->{type} eq 'widget'
                    && (
                        # Any installed Widget Sets with this identifier?
                        MT->model('template')->exist({
                            blog_id    => $blog_id,
                            type       => 'widget',
                            identifier => $new_tmpl->{identifier},
                        })
                        # Or, any installed Widget Sets with this name?
                        || MT->model('template')->exist({
                            blog_id => $blog_id,
                            type    => 'widget',
                            name    => $new_tmpl->{name},
                        })
                    )
                ) {
                    # Yes, there are. Ask the user if they want to keep them.
                    $param->{if_save_widgets} = 1;
                }

                # If widgets are saved at least once and widget sets are saved
                # at least once, then we can just give up checking. Once is
                # enough to flag the Widget or Widget Set for the user to make
                # a choice about how to handle them.
                last if (
                    $param->{if_save_widgetsets}
                    && $param->{if_save_widgets}
                );
            }
        } ## end foreach my $blog_id (@blog_ids)

        # Is it possible the user may want to save widget sets and/or widgets?
        # If yes, we want to direct them to a screen where they can make that
        # choice.
        if ( $param->{if_save_widgetsets} || $param->{if_save_widgets} ) {
            return $app->load_tmpl( 'save_widgetsets.mtml', $param );
        }
    } ## end if ( ( scalar @blog_ids...))

    # Language support.
    # If there is more than one language supplied for the theme, we want to
    # offer the opportunity to select a language to apply to the templates
    # during installation.

    my @languages = _find_supported_languages($ts_id);
    if ( !$q->param('language') && ( scalar @languages > 1 ) ) {

        # Languages and Designer Mode don't play too well together. Designer
        # Mode will link templates, making it easy to edit templates from the
        # filesystem (or GUI). When a template is installed, it is translated
        # into the requested language. After the template is installed it is
        # re-synced to the filesystem; this writes the translated template
        # over the source template, effectively deleting all "__trans phrase"
        # wrappers. We get around this by not linking templates for any theme
        # that provides languages. But, if the user has seleted Designer Mode
        # *and* if Languages are available, we should warn them about this
        # limitation.

        if ( $q->param('theme_mode') eq 'designer' ) {
            $param->{designer_mode_warning} = 1;
        }

        my @param_langs;

        # Load the specified plugin/theme.
        my $c = $plugin;
        eval "require " . $c->l10n_class . ";";
        my $handles = MT->request('l10n_handle') || {};
        my $h = $handles->{ $c->id };

        foreach my $language (@languages) {
            push @param_langs,
              { lang_tag => $language, lang_name => $language };

        }
        $param->{languages} = \@param_langs;

        return $app->load_tmpl( 'select_language.mtml', $param );
    } ## end if ( !$q->param('language'...))
    else {

        # Either a language has been set, or there is only one language: english.
        my $selected_lang
          = $q->param('language') ? $q->param('language') : $languages[0];

        # If this theme is being applied to many blogs, assign the language to them all!
        foreach my $blog_id (@blog_ids) {
            my $blog = MT->model('blog')->load($blog_id);
            $blog->template_set_language($selected_lang);
            $blog->save or die $blog->errstr;
        }
    }

    # As you may guess, this applies the template set to the current blog.
    use ThemeManager::TemplateInstall;
    foreach my $blog_id (@blog_ids) {
        ThemeManager::TemplateInstall::_refresh_all_templates( $ts_id,
                                                             $blog_id, $app );
    }

    my @loop;

    # This is for any required fields that the user may not have filled in.
    my @missing_required;

    # There's no reason to build options for blogs at the system level. If they
    # have any fields to set, they almost definitely need to be set on a
    # per-blog basis (otherwise what's the point of separate blogs or separate
    # theme options?), so we can just skip this.
    unless ( $q->param('blog_ids') ) {
        my $blog = MT->model('blog')->load( $param->{blog_id} );
        if ( my $optnames = $ts->{options} ) {
            my $types     = $app->registry('config_types');
            my $fieldsets = $ts->{options}->{fieldsets};

            $fieldsets->{__global} = {
                label => sub {
                    $tm->translate("Global Options");
                  }
            };

            require MT::Template::Context;
            my $ctx = MT::Template::Context->new();

            # This is a localized stash for field HTML
            my $fields;

            my $cfg_obj = $plugin->get_config_hash( 'blog:' . $blog->id );

            foreach my $optname (
                sort {
                    ( $optnames->{$a}->{order} || 999 )
                      <=> ( $optnames->{$b}->{order} || 999 )
                } keys %{$optnames}
              )
            {

                # Don't bother to look at the fieldsets.
                next if $optname eq 'fieldsets';

                my $field = $ts->{options}->{$optname};
                if ( $field->{required} && $field->{required} == 1 ) {
                    if ( my $cond = $field->{condition} ) {
                        if ( !ref($cond) ) {
                            $cond = $field->{condition}
                              = $app->handler_to_coderef($cond);
                        }
                        next unless $cond->();
                    }

                    my $field_id = $ts_id . '_' . $optname;
                    if ( $types->{ $field->{'type'} } ) {
                        my $value;
                        $value = delete $cfg_obj->{$field_id};
                        my $out;
                        $field->{fieldset} = '__global'
                          unless defined $field->{fieldset};
                        my $show_label
                          = defined $field->{show_label}
                          ? $field->{show_label}
                          : 1;
                        my $label
                          = $field->{label} ne '' ? &{ $field->{label} } : '';

                        # If there is no value for this required field (whether a
                        # "default" value or a user-supplied value), we need to
                        # complain and make the user fill it in. But, only complain
                        # if the user has tried to save already! We don't want to be
                        # annoying.
                        if ( !$value && $q->param('saved') ) {

                            # There is no value for this field, and it's a required
                            # field, so we need to tell the user to fix it!
                            push @missing_required, { label => $label };
                        }
                        $out
                          .= '  <div id="field-'
                          . $field_id
                          . '" class="field field-left-label pkg field-type-'
                          . $field->{type} . '">' . "\n";
                        $out .= "    <div class=\"field-header\">\n";
                        $out
                          .= "      <label for=\"$field_id\">" 
                          . $label
                          . "</label>\n"
                          if $show_label;
                        $out .= "    </div>\n";
                        $out .= "    <div class=\"field-content\">\n";
                        my $hdlr = MT->handler_to_coderef(
                                    $types->{ $field->{'type'} }->{handler} );
                        $out
                          .= $hdlr->( $app, $ctx, $field_id, $field, $value );

                        if ( $field->{hint} ) {
                            $out
                              .= "      <div class=\"hint\">"
                              . $field->{hint}
                              . "</div>\n";
                        }
                        $out .= "    </div>\n";
                        $out .= "  </div>\n";
                        my $fs = $field->{fieldset};
                        push @{ $fields->{$fs} }, $out;
                    } ## end if ( $types->{ $field->...})
                    else {
                        MT->log( {
                                 level   => MT->model('log')->ERROR(),
                                 blog_id => $blog->id,
                                 message =>
                                   $tm->translate(
                                      'Unknown config type encountered: [_1]',
                                      $field->{'type'}
                                   ),
                               }
                        );
                    }
                } ## end if ( $field->{required...})
            } ## end foreach my $optname ( sort ...)
            my $count = 0;
            my $html;
            foreach my $set (
                sort {
                    ( $fieldsets->{$a}->{order} || 999 )
                      <=> ( $fieldsets->{$b}->{order} || 999 )
                } keys %$fieldsets
              )
            {
                next unless $fields->{$set} || $fieldsets->{$set}->{template};
                my $label     = $fieldsets->{$set}->{label};
                my $innerhtml = '';
                if ( my $tmpl = $fieldsets->{$set}->{template} ) {
                    my $txt = $plugin->load_tmpl($tmpl);
                    my $filter
                      = $fieldsets->{$set}->{format}
                      ? $fieldsets->{$set}->{format}
                      : '__default__';
                    $txt = MT->instancely_text_filters( $txt->text(), [$filter] );
                    $innerhtml = $txt;
                    $html .= $txt;
                }
                else {
                    $html .= "<fieldset>";
                    $html .= "<h3>" . $label . "</h3>";
                    foreach ( @{ $fields->{$set} } ) {
                        $innerhtml .= $_;
                    }
                    $html .= $innerhtml;
                    $html .= "</fieldset>";
                }
                push @loop,
                  {
                    '__first__' => ( $count++ == 0 ),
                    id          => dirify($label),
                    label       => $label,
                    content     => $innerhtml,
                  };
            } ## end foreach my $set ( sort { ( ...)})
            my @leftovers;
            foreach my $field_id ( keys %$cfg_obj ) {
                push @leftovers,
                  { name => $field_id, value => $cfg_obj->{$field_id}, };
            }
        } ## end if ( my $optnames = $ts...)
    } ## end unless ( $q->param('blog_ids'...))

    $param->{fields_loop}      = \@loop;
    $param->{saved}            = $q->param('saved');
    $param->{missing_required} = \@missing_required;

    # If this theme is being applied at the blog level, offer a "home" link.
    # Otherwise, themes are being mass-applied to many blogs at the system
    # level and we don't want to offer a single home page link.
    unless ( $q->param('blog_ids') ) {
        my @options;
        push @options, 'Theme Options'
          if eval { $app->registry('template_sets')->{$ts_id}->{options} };
        push @options, 'Widgets'
          if eval {
            $app->registry( 'template_sets', $ts_id,
                            'templates',     'widgetset' );
          };
        $param->{options} = join( ' and ', @options );
    }

    # If there are *no* missing required fields, and the options *have*
    # been saved, that means we've completed everything that needs to be
    # done for the theme setup. So, *don't* return the fields_loop
    # contents, and the "Theme Applied" completion message will show.
    if ( !$missing_required[0] && $q->param('saved') ) {
        $param->{fields_loop} = '';
    }

    $app->load_tmpl( 'theme_setup.mtml', $param );
} ## end sub setup_theme

sub site_preview_image {

    # We want a custom thumbnail to display on the Theme Dashboard "About this Theme" tab.
    my $tm = MT->component('ThemeManager');
    use File::Spec;
    use LWP::Simple;

    # Grab all blogs, then build previews for each.
    my $iter = MT->model('blog')->load_iter();
    while ( my $blog = $iter->() ) {

        # Craft the destination path.
        my $dest_path
          = File::Spec->catfile( theme_thumb_path(), $blog->id . '.jpg' );

        # If this blog is running on localhost Thumbalizr isn't going to
        # be able to make a thumbnail of this site, so no need to make it
        # try. Return the theme-supplied preview.
        if ( $blog->site_url =~ m/localhost/ ) {
            my $preview_url = _get_local_preview($blog);

            # Now that we have the preview URL, save it to the $dest_path,
            # so it's available for display.
            my $http_response
              = LWP::Simple::getstore( $preview_url, $dest_path );
            if ( $http_response != 200 ) {
                MT->log( {
                           level   => MT->model('log')->ERROR(),
                           blog_id => $blog->id,
                           message =>
                             $tm->translate(
                                 'Theme Manager could not save the Theme '
                                   . 'Dashboard preview image. Source: [_1], '
                                   . 'Destination: [_2]',
                                 $preview_url,
                                 $dest_path
                             ),
                         }
                );
            }
        } ## end if ( $blog->site_url =~...)

        # This blog is not on localhost. Use Thumbalizr to grab a screenshot
        # of the current blog with the theme applied.
        else {

            # Now build and cache the thumbnail URL. This is done with
            # thumbalizr.com, a free online screenshot service. Their API is
            # completely http based, so this is all we need to do to get an
            # image from them.
            my $preview_url
              = 'http://api.thumbalizr.com/?url='
              . $blog->site_url
              . '&width=300';

            # Save the resulting thumbnail for display.
            my $http_response
              = LWP::Simple::getstore( $preview_url, $dest_path );

            # If the thumbalizr preview was successfully retrieved and saved,
            # then check it to be sure it's a "real" preview. No point in
            # showing the "Failed" or "Queued" image on the Theme Dashboard.
            if ( $http_response == 200 ) {
                my $fmgr    = $blog->file_mgr;
                my $content = $fmgr->get_data($dest_path);

                # Create an MD5 hash of the content. This provides us with
                # something unique to compare against.
                use Digest::MD5;
                my $md5 = Digest::MD5->new;
                $md5->add($content);

                # The "unreachable" image has an MD5 hash of:
                # f43e0452d20ecfc12a3bd785e6b9c831
                # The "queued" image has an MD5 hash of:
                # eb433ad65b8aa50047e6f2de1530d6cf
                # The "failed" image has an MD5 hash of:
                # ac47a999e5ce1769d480a66b0554343d
                # If it matches either, use the local preview.
                if ( ( $md5->hexdigest eq 'f43e0452d20ecfc12a3bd785e6b9c831' )
                     || ( $md5->hexdigest eq
                          'eb433ad65b8aa50047e6f2de1530d6cf' )
                     || ( $md5->hexdigest eq
                          'ac47a999e5ce1769d480a66b0554343d' ) )
                {
                    $preview_url = _get_local_preview($blog);
                    LWP::Simple::getstore( $preview_url, $dest_path );
                }
            } ## end if ( $http_response ==...)

            # If $http_response isn't 200 (Success), we need to fall back to
            # something else: either the theme-supplied preview or Theme
            # Manager's default preview.
            else {
                $http_response
                  = LWP::Simple::getstore( $preview_url, $dest_path );
                if ( $http_response != 200 ) {
                    MT->log( {
                            level   => MT->model('log')->ERROR(),
                            blog_id => $blog->id,
                            message =>
                              $tm->translate(
                                 'Theme Manager could not save the Theme '
                                   . 'Dashboard preview image. Source: [_1], '
                                   . 'Destination: [_2]',
                                 $preview_url,
                                 $dest_path
                              ),
                          }
                    );
                }
            }
        } ## end else [ if ( $blog->site_url =~...)]
    } ## end while ( my $blog = $iter->...)
} ## end sub site_preview_image

sub _get_local_preview {
    my ($blog) = @_;

    # Grab the theme's plugin assigned to this blog.
    my $plugin = find_theme_plugin( $blog->template_set );

    # If the theme's plugin was found, look up the theme meta to
    # grab the theme-supplied preview. If no plugin, just use the
    # Theme Manager default.
    if ($plugin) {

        # Convert the saved YAML back into a hash.
        my $yaml       = YAML::Tiny->new;
        my $theme_meta = YAML::Tiny->read_string( $blog->theme_meta );
        $theme_meta = $theme_meta->[0];
        return theme_preview_url( $theme_meta->{preview}, $plugin->id );
    }
    else {
        return theme_preview_url();
    }
} ## end sub _get_local_preview

sub _make_mini {
    my $app = MT->instance;
    my $q   = $app->query;
    my $tm  = MT->component('ThemeManager');

    use File::Spec;
    my $dest_path = File::Spec->catfile( theme_thumb_path(),
                                         $app->blog->id . '-mini.jpg' );
    my $dest_url = caturl( $app->static_path, 'support', 'plugins', $tm->id,
                           'theme_thumbs', $app->blog->id . '-mini.jpg' );

    # Decide if we need to create a new mini or not.
    my $fmgr = MT::FileMgr->new('Local') or return MT::FileMgr->errstr;
    unless ( ( $fmgr->exists($dest_path) ) && ( -M $dest_path <= 1 ) ) {
        my $source_path = File::Spec->catfile( theme_thumb_path(),
                                               $app->blog->id . '.jpg' );

        # Look for the source image. If there is no source image, we can't
        # make a mini, and therefore should just give up.
        return unless $fmgr->exists($source_path);
        use MT::Image;
        my $img = MT::Image->new( Filename => $source_path ) or return;

        # If no width has been defined, this is an invalid image; just give
        # up. This may happen if the $source_path image is corrupt.
        return unless defined $img->{'width'};
        my $resized_img = $img->scale( Width => 138 );
        $fmgr->put_data( $resized_img, $dest_path )
          or return MT::FileMgr->errstr;
    }
    return $dest_url;
} ## end sub _make_mini

sub paypal_donate {
    my $app = shift;
    my $q = $app->query;

    # Donating through PayPal requires a pop-up dialog so that we can break
    # out of MT and the normal button handling. (That is, clicking a PayPal
    # button on Theme Options causes MT to try to save Theme Options, not
    # launch the PayPal link. Creating a dialog breaks out of that
    # requirement.)
    my $param = {};
    $param->{theme_label}  = $q->param('theme_label');
    $param->{paypal_email} = $q->param('paypal_email');
    return $app->load_tmpl( 'paypal_donate.mtml', $param );
}

sub theme_info {
    my $app = shift;
    my $q = $app->query;

    # Theme info is displayed when a user clicks to select a theme (from the
    # Change Theme tab).
    my $param = {};

    my $plugin_sig = $q->param('plugin_sig');
    my $plugin     = MT->component( $plugin_sig );

    my $ts_id = $q->param('ts_id');

    # Theme data is cached so that we can load and just display as necessary.
    my $theme = MT->model('theme')
      ->load( { ts_id => $ts_id, plugin_sig => $plugin_sig, } );

    # Convert the saved YAML back into a hash.
    my $yaml       = YAML::Tiny->new;
    my $theme_meta = YAML::Tiny->read_string( $theme->theme_meta );
    $theme_meta = $theme_meta->[0];

    $param->{id} = $ts_id;
    $param->{label} = theme_label( $theme_meta->{label}, $plugin );
    $param->{preview_url}
      = theme_preview_url( $theme_meta->{preview}, $plugin->id );
    $param->{description}
      = theme_description( $theme_meta->{description}, $plugin );
    $param->{author_name}
      = theme_author_name( $theme_meta->{author_name}, $plugin );
    $param->{version} = theme_version( $theme_meta->{version}, $plugin );
    $param->{theme_link} = theme_link( $theme_meta->{link}, $plugin );
    $param->{theme_doc_link}
      = theme_doc_link( $theme_meta->{doc_link}, $plugin );
    $param->{about_designer}
      = theme_about_designer( $theme_meta->{about_designer}, $plugin );
    $param->{plugin_sig} = $plugin_sig;
    my $ts_count = keys %{ $plugin->{registry}->{'template_sets'} };
    $param->{plugin_label} = $ts_count > 1 ? $plugin->label : 0;

    $param->{theme_details} = $app->load_tmpl( 'theme_details.mtml', $param );

    return $app->load_tmpl( 'theme_info.mtml', $param );
} ## end sub theme_info

sub xfrm_add_thumb {

    # Add a small thumbnail and link above the content nav area of Theme
    # Options, to help better tie the Theme Options and Theme Dashboard
    # together.
    my ( $cb, $app, $tmpl ) = @_;

    # I can't target the theme_options template, probably because it's a
    # plugin. So, check here to be sure we are working with the correct
    # template only.
    my $result = index $$tmpl, '<__trans phrase="Theme Options"> &gt; ';
    if ( $result ne '-1' ) {
        my $dest_url = _make_mini();

        # $dest_url will be emtpy if no image handler is installed/enabled,
        # so we want to just fail silently.
        if ($dest_url) {

            # Now finally update the Theme Options template
            my $old = '<mt:setvarblock name="content_nav">';
            my $new
              = $old
              . '<div style="margin-bottom: 8px; border: 1px solid #ddd;"><a href="<mt:Var name="script_uri">?__mode=theme_dashboard&blog_id=<mt:Var name="blog_id">" title="<__trans phrase="Visit the Theme Dashboard">"><img src="'
              . $dest_url
              . '" width="138" height="112" /></a></div>';
            $$tmpl =~ s/$old/$new/mgi;
        }
    }
} ## end sub xfrm_add_thumb

sub _theme_check {

    # We need to store templates in the DB so that we can do the
    # $app->listing thing to build the page.

    # Look through all the plugins and find the template sets.
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @ts_ids = keys %{ $r->{'template_sets'} };
        foreach my $ts_id (@ts_ids) {

            # Does this theme already exist? If so just load the record and
            # update it.
            my $theme = MT->model('theme')
              ->get_by_key( { ts_id => $ts_id, plugin_sig => $obj->{id}, } );

            # Prepare the theme_meta so that the hash can be written to
            # the database.
            my $meta = prepare_theme_meta($ts_id);
            my $yaml = YAML::Tiny->new;
            $yaml->[0] = $meta;

            # Turn that YAML into a plain old string and save it.
            $theme->theme_meta( $yaml->write_string() );

            # Save the theme label in a separate column. We use this to
            # sort the themes for display on the Change Theme page. Use the
            # theme meta label that we already calculated fallbacks for.
            $theme->ts_label( theme_label( $meta->{label}, $plugin ) );

            $theme->save or die 'Error saving theme:' . $theme->errstr;
        } ## end foreach my $ts_id (@ts_ids)
    } ## end for my $sig ( keys %MT::Plugins)

    # Should we delete any themes from the db?
    my $iter = MT->model('theme')->load_iter( {}, { sort_by => 'ts_id', } );
    while ( my $theme = $iter->() ) {

        # Use the plugin sig to grab the plugin.
        my $plugin = MT->component( $theme->plugin_sig );
        if ( !$plugin ) {

            # This plugin couldn't be loaded! That must mean the theme has
            # been uninstalled, so remove the entry in the table.
            $theme->remove;
            next;
        }
        else {
            if ( !$plugin->{registry}->{'template_sets'}->{ $theme->ts_id } )
            {

                # This template set couldn't be loaded! That must mean the theme
                # has been uninstalled, so remove the entry in the table.
                $theme->remove;
                next;
            }
        }
    } ## end while ( my $theme = $iter...)
} ## end sub _theme_check

sub rebuild_tmpl {
    my $app        = shift;
    my $q          = $app->query;
    my $blog       = $app->blog;
    my $return_val = { success => 0 };
    my $templates
      = MT->model('template')->lookup_multi( [ $q->param('id') ] );
  TEMPLATE: for my $tmpl (@$templates) {
        next TEMPLATE if !defined $tmpl;
        next TEMPLATE if $tmpl->blog_id != $blog->id;
        next TEMPLATE unless $tmpl->build_type;

        $return_val->{success} =
          $app->rebuild_indexes(
                                 Blog     => $blog,
                                 Template => $tmpl,
                                 Force    => 1,
          );
        unless ( $return_val->{success} ) {
            $return_val->{errstr} = $app->errstr;
        }
    }
    return _send_json_response( $app, $return_val );
} ## end sub rebuild_tmpl


sub _send_json_response {
    my ( $app, $result ) = @_;
    require JSON;
    my $json = JSON::objToJson($result);
    $app->send_http_header("");
    $app->print($json);
    return $app->{no_print_body} = 1;
    return undef;
}

sub _populate_list_templates_context {
    my $app      = shift;
    my $tm       = MT->component('ThemeManager');
    my $q        = $app->query;
    my ($params) = @_;

#    my ($params_ref) = @_;
#    $params = $$params_ref;

    my $blog = $app->blog;
    require MT::Template;
    my $blog_id = $q->param('blog_id') || 0;
    my $terms = { blog_id => $blog_id };
    my $args  = { sort    => 'name' };

    my $hasher = sub {
        my ( $obj, $row ) = @_;
        my $template_type;
        my $type = $row->{type} || '';
        if ( $type =~ m/^(individual|page|category|archive)$/ ) {
            $template_type = 'archive';

            # populate context with templatemap loop
            my $tblog
              = $obj->blog_id == $blog->id
              ? $blog
              : MT->model('blog')->load( $obj->blog_id );
            if ($tblog) {
                require MT::CMS::Template;
                $row->{archive_types}
                  = MT::CMS::Template::_populate_archive_loop( $app, $tblog,
                                                               $obj );
            }
        }
        elsif ( $type eq 'widget' ) {
            $template_type = 'widget';
        }
        elsif ( $type eq 'index' ) {
            $template_type = 'index';
        }
        elsif ( $type eq 'custom' ) {
            $template_type = 'module';
        }
        elsif ( $type eq 'email' ) {
            $template_type = 'email';
        }
        elsif ( $type eq 'backup' ) {
            $template_type = 'backup';
        }
        else {
            $template_type = 'system';
        }
        $row->{use_cache} = ( ( $obj->cache_expire_type || 0 ) != 0 ) ? 1 : 0;
        $row->{template_type} = $template_type;
        $row->{type}          = 'entry' if $type eq 'individual';
        $row->{status}        = 'Foo';

        my $published_url = $obj->published_url;
        $row->{published_url} = $published_url if $published_url;
    };

    my $filter = $q->param('filter_key');
    my $template_type = $filter || '';
    $template_type =~ s/_templates//;

    $params->{screen_class}   = "list-template";
    $params->{listing_screen} = 1;

    $app->load_list_actions( 'template', $params );
    $params->{page_actions}    = $app->page_actions('list_templates');
    $params->{search_label}    = $tm->translate("Templates");
    $params->{object_type}     = 'template';
    $params->{blog_view}       = 1;
    $params->{refreshed}       = $q->param('refreshed');
    $params->{published}       = $q->param('published');
    $params->{saved_copied}    = $q->param('saved_copied');
    $params->{saved_deleted}   = $q->param('saved_deleted');
    $params->{profile_updated} = $q->param('profile_updated');
    $params->{saved}           = $q->param('saved');

    # determine list of system template types:
    my $scope;
    my $set;
    if ($blog) {
        $set   = $blog->template_set;
        $scope = 'system';
    }
    else {
        $scope = 'global:system';
    }
    my @tmpl_path
      = ( $set && ( $set ne 'mt_blog' ) )
      ? ( "template_sets", $set, 'templates', $scope )
      : ( "default_templates", $scope );
    my $sys_tmpl = MT->registry(@tmpl_path) || {};

    my @tmpl_loop;
    my %types;
    if ( $template_type ne 'backup' ) {
        if ($blog) {

            # blog template listings
            %types = (
                  'index' => {
                               label => $tm->translate("Index Templates"),
                               type  => 'index',
                               order => 100,
                  },
                  'archive' => {
                      label => $tm->translate("Archive Templates"),
                      type => [ 'archive', 'individual', 'page', 'category' ],
                      order => 200,
                  },
                  'module' => {
                                label => $tm->translate("Template Modules"),
                                type  => 'custom',
                                order => 300,
                  },
            );

            # If any email templates are part of this theme, display them under
            # an "Email Templates" template area. Only show this area if a
            # theme requires it, because email templates can't be manually
            # created anyway.
            if (
                eval {
                    MT->registry( 'template_sets', $set, 'templates', 'email' ) 
                }
            ) {
                $types{'email'} = {
                                   label => $tm->translate("Email Templates"),
                                   type  => 'email',
                                   order => 400,
                };
            }

            # If any system templates are part of this theme, display them
            # under a "System Templates" template area. Only show this area if
            # a theme requires it, because system templates can't be manually
            # created anyway.
            if (
                eval {
                    MT->registry( 'template_sets', $set, 'templates', 'system' )
                }
            ) {
                $types{'system'} = {
                                  label => $tm->translate("System Templates"),
                                  type  => [ keys %$sys_tmpl ],
                                  order => 401,
                };
            }

        } ## end if ($blog)
        else {

            # global template listings
            %types = (
                       'module' => {
                                  label => $tm->translate("Template Modules"),
                                  type  => 'custom',
                                  order => 100,
                       },
                       'email' => {
                                   label => $tm->translate("Email Templates"),
                                   type  => 'email',
                                   order => 200,
                       },
                       'system' => {
                                  label => $tm->translate("System Templates"),
                                  type  => [ keys %$sys_tmpl ],
                                  order => 300,
                       },
            );
        } ## end else [ if ($blog) ]
    } ## end if ( $template_type ne...)
    else {

        # global template listings
        %types = (
                   'backup' => {
                                 label => $tm->translate("Template Backups"),
                                 type  => 'backup',
                                 order => 100,
                   },
        );
    }
    my @types
      = sort { $types{$a}->{order} <=> $types{$b}->{order} } keys %types;
    if ($template_type) {
        @types = ($template_type);
    }
    $app->delete_param('filter_key') if $filter;
    foreach my $tmpl_type (@types) {
        if ( $tmpl_type eq 'index' ) {
            $q->param( 'filter_key', 'index_templates' );
        }
        elsif ( $tmpl_type eq 'archive' ) {
            $q->param( 'filter_key', 'archive_templates' );
        }
        elsif ( $tmpl_type eq 'system' ) {
            $q->param( 'filter_key', 'system_templates' );
        }
        elsif ( $tmpl_type eq 'email' ) {
            $q->param( 'filter_key', 'email_templates' );
        }
        elsif ( $tmpl_type eq 'module' ) {
            $q->param( 'filter_key', 'module_templates' );
        }
        my $tmpl_param = {};
        unless (    exists( $types{$tmpl_type}->{type} )
                 && 'ARRAY' eq ref( $types{$tmpl_type}->{type} )
                 && 0 == scalar( @{ $types{$tmpl_type}->{type} } ) )
        {
            $terms->{type} = $types{$tmpl_type}->{type};
            $tmpl_param = $app->listing( {
                                           type     => 'template',
                                           terms    => $terms,
                                           args     => $args,
                                           no_limit => 1,
                                           no_html  => 1,
                                           code     => $hasher,
                                         }
            );
        }
        my $template_type_label = $types{$tmpl_type}->{label};
        $tmpl_param->{template_type}       = $tmpl_type;
        $tmpl_param->{template_type_label} = $template_type_label;
        push @tmpl_loop, $tmpl_param;
    } ## end foreach my $tmpl_type (@types)
    if ($filter) {
        $params->{filter_key}   = $filter;
        $params->{filter_label} = $types{$template_type}{label}
          if exists $types{$template_type};
        $q->param( 'filter_key', $filter );
    }
    else {

        # restore filter_key param (we modified it for the
        # sake of the individual table listings)
        $app->delete_param('filter_key');
    }

    $params->{template_type_loop} = \@tmpl_loop;
    $params->{screen_id}          = "list-template";
} ## end sub _populate_list_templates_context

# Copied from MT::CMS::Template::list
sub list_templates {
    my $app = shift;

    my $perms = $app->blog ? $app->permissions : $app->user->permissions;
    return $app->return_to_dashboard( redirect => 1 )
      unless $perms || $app->user->is_superuser;
    if ( $perms && !$perms->can_edit_templates ) {
        return $app->return_to_dashboard( permission => 1 );
    }

    my $params = {};
    _populate_list_templates_context( $app, $params );

    return $app->load_tmpl( 'list_template.tmpl', $params );
}

# List template backups. Templates are sorted and organized by date based on
# the contents of the template name.
sub list_template_backups {
    my $app      = shift;
    my $q        = $app->param;
    my ($params) = @_;

    return $app->translate('Permission denied.')
        unless $app->user->is_superuser() 
            || (
                $app->blog 
                && $app->user->permissions($app->blog->id)->can_edit_templates()
            );

    my $code = sub {
        my ($tmpl, $row) = @_;
        $row->{id} = $tmpl->id;

        # The template name is formatted with lots of info:
        # [tmpl name] [backup date] [tmpl type]
        # Extract the name and type to display on this listing screen.
        my $tmpl_name = $tmpl->name;
        $tmpl_name =~ s/(.*)\s\(Backup.*/$1/;
        $row->{name} = $tmpl_name;

        # Provide a little formatting to the template type display with 
        # proper case and a "system" identifier.
        my $tmpl_type = $tmpl->name;
        $tmpl_type =~ s/.*\(Backup.*\)\s(.*)/$1/;
        if ($tmpl_type eq 'custom') {
            $tmpl_type = 'Module';
        }
        elsif ($tmpl_type eq 'widgetset') {
            $tmpl_type = 'Widget Set';
        }
        elsif ($tmpl_type =~ /(index|archive|widget|individual)/) {
            $tmpl_type = ucfirst($tmpl_type);
        }
        else {
            $tmpl_type = "System: $tmpl_type";
        }
        $row->{was_type} = $tmpl_type;
        $row->{template_type} = 'backup'; # These are all backup templates
    };

    my $terms = {
        blog_id => $app->blog->id,
        type    => 'backup',
    };

    my $args = {
        sort      => 'modified_on',
        direction => 'descend',
    };

    # We want to display the backup templates sorted by date. To do that we 
    # can use the "template_type" sorting capability already in use on the
    # Template Listing screen, which is responsible for dividing index and 
    # archive templates, for example.
    my @tmpl_loop;
    my $tmpl_param = {};
    my $saved_date = 0;
    my $currently_displaying = 1;
    my $display_history = ($q->param('limit') && $q->param('limit') eq 'all')
        ? '999999' # A really huge number, effectively all backup sets.
        : $q->param('limit') || 5; # 5 is safely small but useful.

    my $iter = MT->model('template')->load_iter( $terms, $args, );
    while ( my $tmpl = $iter->() ) {
        last if ($currently_displaying > $display_history);

        # We can't just use the modified_on date to sort by because that 
        # doesn't necessarily reflect when the backup was created nore does
        # it account for the possiblity that the backup template is unedited.
        # Extract the backup date/time from the template name, and use that
        # for sorting.
        my $date = $tmpl->name;
        $date =~ s/.*\(Backup from (.*)\).*/$1/;

        # If the current template should be grouped with the previous template
        # (according to the date it was marked as a backup) then just skip
        # to the next template.
        next if $date eq $saved_date;

        # Grab the templates that match the selected date to create a "backup 
        # set."
        $terms->{name} = { like => "%$date%" };
        $args->{sort}      = 'name';
        $args->{direction} = 'ascend';

        $tmpl_param = $app->listing({
            type     => 'template',
            terms    => $terms,
            args     => $args,
            no_limit => 1,
            no_html  => 1,
            code     => $code,
        });

        $tmpl_param->{template_type} = 'backup';
        $tmpl_param->{template_type_label} = "Templates Backups from $date";

        push @tmpl_loop, $tmpl_param;

        $saved_date = $date;
        $currently_displaying++;
    }

    $params->{template_type_loop} = \@tmpl_loop;

    $params->{saved_deleted}  = $q->param('saved_deleted');
    $params->{search_label}   = $app->translate("Templates");
    $params->{screen_class}   = "list-template";
    $params->{screen_id}      = "list-template";
    $params->{listing_screen} = 1;
    $params->{page_actions}   = $app->page_actions('list_template_backups');

    return $app->load_tmpl('list_template_backups.mtml', $params);
}

sub _find_supported_languages {
    my $ts_id     = shift;
    my $ts_plugin = find_theme_plugin($ts_id);

    # Languages need to be specified for each template set. We can't just
    # search for all available languages because if the plugin is a theme
    # pack (that is, contains many themes), it's possible that only some
    # themes may contain tranlations.
    my $langs = $ts_plugin->registry( 'template_sets', $ts_id, 'languages' );
    my @ts_langs;
    foreach my $lang (@$langs) {

        # A quick check to see if the $lang is formatted as a language tag. If
        # it is, then we can use it.
#        if ( I18N::LangTags::is_language_tag($lang) ) {
        push @ts_langs, $lang;

#        }
#        else {
#            # Not a valid language tag!
#            my $app = MT->instance;
#            my $blog_id = $app->blog->id;
#            MT->log(
#                {
#                    level   => MT->model('log')->ERROR(),
#                    blog_id => $blog_id,
#                    message => MT->translate(
#                        'The language "[_1]" specified in the theme [_2] is invalid.',
#                        $lang,
#                        $ts_plugin->registry('template_sets',$ts_id,'label'),
#                    ),
#                }
#            );
#        }
    } ## end foreach my $lang (@$langs)
    if ( !@ts_langs ) {

        # No languages were specified. So, lets default to english.
        $ts_langs[0] = 'en-us';
    }
    return @ts_langs;
} ## end sub _find_supported_languages

# Add all the necessary values to $param to populate the theme dashboard.
sub _populate_theme_dashboard {
    my ($blog)     = shift;
    my ($param)    = shift;
    my ($plugin)   = shift;
    my $theme_meta = {};

    $param->{theme_mode} = $blog->theme_mode;

    # In Production Mode, read the cached theme meta from the DB.
    # In Designer Mode, load the YAML from the plugin and use that.
    if ( $blog->theme_mode && $blog->theme_mode eq 'designer' ) {

        # We don't want to load the cached theme meta here (saved to the DB), 
        # because we want it to be dynamically loaded from the plugin, which 
        # is what the fallback values are anyway.
        $theme_meta = MT->registry( 'template_sets', $blog->template_set );
    }
    else {

        # This is Production Mode.
        # By "else"-ing to Production Mode, we aren't relying upon the
        # theme_mode meta field to be set, which may be true for those who
        # have upgraded an existing site built without a theme, or when a
        # theme hasn't been re-selected.
        if ( !$blog->theme_mode ) {
            $blog->theme_mode('production');
            $blog->save or die $blog->errstr;
        }

        # If the blog has theme_meta, convert the saved YAML back into a hash.
        $theme_meta
          = eval { YAML::Tiny->read_string( $blog->theme_meta )->[0] };

        # If theme meta isn't found, it wasn't set when the theme was
        # applied (a very likely scenario for upgraders, who likely haven't
        # applied a new theme). Go ahead and just create the theme meta.
        if ( !$theme_meta ) {
            $theme_meta = prepare_theme_meta($blog->template_set);
            my $yaml = YAML::Tiny->new;
            $yaml->[0] = $theme_meta;

            # Turn that YAML into a plain old string and save it.
            $blog->theme_meta( $yaml->write_string() );

            # Upgraders likely also don't have the theme_mode switch set
            $blog->theme_mode('production');
            $blog->save or die $blog->errstr;
        }
    } ## end else [ if ( $blog->theme_mode...)]

    # Build the theme dashboard links.
    # Each of these utility functions will set the parameter based on the 
    # cached theme meta YAML (in production mode) or will fall back to the 
    # plugin's YAML (in designer mode).
    $param->{theme_label} = theme_label( $theme_meta->{label}, $plugin );
    $param->{theme_description}
      = theme_description( $theme_meta->{description}, $plugin );
    $param->{theme_author_name}
      = theme_author_name( $theme_meta->{author_name}, $plugin );
    $param->{theme_author_link}
      = theme_author_link( $theme_meta->{author_link}, $plugin );
    $param->{theme_link} = theme_link( $theme_meta->{link}, $plugin );
    $param->{theme_doc_link}
      = theme_doc_link( $theme_meta->{doc_link}, $plugin );
    $param->{theme_version}
      = theme_version( $theme_meta->{version}, $plugin );
    $param->{theme_paypal_email}
      = theme_paypal_email( $theme_meta->{paypal_email}, $plugin );
    $param->{theme_about_designer}
      = theme_about_designer( $theme_meta->{about_designer}, $plugin );
    $param->{theme_documentation}
      = theme_documentation( $theme_meta->{documentation}, $plugin );

    # Add the theme thumbnail to the theme dashboard.
    my $dest_path = theme_thumb_path();
    if ( -w $dest_path ) {
        $param->{theme_thumb_url} = theme_thumb_url();
    }
    else {

        # A system message for the user that the theme thumbnail destination
        # path couldn't be read.
        $param->{theme_thumbs_path} = $dest_path;
    }

    $param = _theme_upgrade_check($blog, $param, $plugin, $theme_meta->{version});

    return $param;
}

sub _theme_upgrade_check {
    my ($blog)   = shift;
    my ($param)  = shift;
    my ($plugin) = shift;

    # The installed theme's version.
    my $installed_version = shift;

    # If no installed version was supplied, just give up because we certainly 
    # can't tell if there's an upgrade without knowing what version we started
    # with.
    return $param if !$installed_version;

    # Upgrades are automatic with Designer Mode, so no need to provide the 
    # upgrade option.
    return $param if $blog->theme_mode eq 'designer';

    # Grab the "latest" version number of the theme. This will use the version
    # of the theme from the plugin or the version of the plugin, or a default.
    my $ts = {};
    if ( my $ts_id = $blog->template_set ) {
        $ts = eval { MT->registry( 'template_sets', $ts_id ) } || {};
    }
    my $latest_version = theme_version( $ts->{version}, $plugin );

    # Compare the latest version and installed version of the theme.
    # version needs to be compiled to be used, so we can't supply it with 
    # Theme Manager, and because it's not in Perl's core prior to 5.10 we
    # can't rely on it being available. (Plus, 0.77 isn't in all versions of 
    # Perl 5.10.x, so we can't rely on 5.10 being correct anyway.)
    #use version 0.77;
    use Perl::Version;
    $latest_version = Perl::Version->new( $latest_version );
    $installed_version = Perl::Version->new( $installed_version );

    # Return true if a newer version is available than the installed version
    # of the theme.
    if ( $latest_version > $installed_version ) {
        $param->{theme_upgrade_available} = 1;
        $param->{theme_upgrade_version_num} = $latest_version->stringify;
    }
    
    return $param;
}

# Delete all of the backup templates in this blog.
sub delete_tmpl_backups {
    my ($app) = @_;
    my $q     = $app->param;
    my $param = {};
    
    if ( $q->param('delete_confirm') ) {
        MT->model('template')->remove({
            type => 'backup',
            blog_id => $q->param('blog_id'),
        });
    }

    $param->{delete_confirm} = $q->param('delete_confirm');

    return $app->load_tmpl('delete_tmpl_backups.mtml', $param);
}

sub itemset_handler {
    my ($app,$link) = @_;
    $app->validate_magic or return;
    my @ids = $app->param('id');
    for my $tmpl_id (@ids) {
        my $tmpl = MT->model('template')->load($tmpl_id) or next;
        MT->log({
            blog_id => $tmpl->blog_id,
            message => ($link eq '*' ? "Linking" : "Unlinking") . " " . $tmpl->name . " to theme file."
                });
        $tmpl->linked_file($link);
        $tmpl->save();
    }
    $app->add_return_arg( link_changed => 1 );
    $app->call_return;
}

sub itemset_link { 
    return itemset_handler(@_, '*'); 
}
sub itemset_unlink { 
    return itemset_handler(@_, ''); 
}

1;

__END__
