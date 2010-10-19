package ThemeManager::Plugin;

use strict;
use ConfigAssistant::Util qw( find_theme_plugin );
use ThemeManager::Util qw( theme_label theme_thumbnail_url theme_preview_url
        theme_description theme_author_name theme_author_link 
        theme_paypal_email theme_version theme_link theme_doc_link 
        about_designer theme_docs _theme_thumb_path _theme_thumb_url );
use MT::Util qw(caturl dirify offset_time_list);
use MT;

sub update_menus {
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    # Theme Manager is turning the Design menu into a friendlier, more useful
    # area than it used to be, and the first step to that is removing the 
    # Templates option. Templates can now be found within the Theme Dashboard
    # We only want to remove the Templates menu at the blog-level. We don't
    # know for sure what templates are at the system-level, so just blanket
    # denying access is probably not best.
    my $blog_id = $q->param('blog_id');
    if ($blog_id) {
        my $core = MT->component('Core');
        delete $core->{registry}->{applications}->{cms}->{menus}->{'design:template'};
    }
    # Now just add the Theme Dashboard menu item.
    return {
        'design:theme_dashboard' => {
            label      => 'Theme Dashboard',
            order      => 1,
            mode       => 'theme_dashboard',
            view       => 'blog',
            permission => 'edit_templates',
        },
    };
}

sub update_page_actions {
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $blog_id = $q->param('blog_id');
    if ($blog_id) {
        my $core = MT->component('Core');
        # Delete the Refresh Blog Templates page action because we don't want
        # people to use this page action--they can apply a theme, instead.
        delete $core->{registry}->{applications}->{cms}->{page_actions}->{list_templates}->{refresh_all_blog_templates};
    }
    return {
        list_templates => {
            refresh_fields => {
                label => "Refresh Custom Fields",
                order => 1010,
                permission => 'edit_templates',
                condition => sub {
                    MT->component('Commercial') && MT->app->blog; 
                },
                code => sub {
                    my ($app) = @_;
                    $app->validate_magic or return;
                    my $blog = $app->blog;
                    _refresh_system_custom_fields($blog);
                    $app->add_return_arg( fields_refreshed => 1 );
                    $app->call_return;
                },
            },
        },
        theme_dashboard => {
            theme_options => {
                label => 'Edit Theme Options',
                order => 100,
                mode => 'theme_options',
                condition => sub {
                    return 0 unless MT->component('ConfigAssistant');
                    my $blog = MT->instance->blog;
                    return 0 if !$blog;
                    my $ts_id = MT->instance->blog->template_set;
                    return 0 if !$ts_id;
                    my $app = MT::App->instance;
                    return 1 if eval {$app->registry('template_sets')->{$ts_id}->{options}};
                    return 0;
                },
            },
            edit_widgets => {
                label => 'Create Widgets and organize Widget Sets',
                order => 101,
                mode => 'list_widget',
                condition => sub {
                    my $blog = MT->instance->blog;
                    return 0 if !$blog;
                    my $ts_id = MT->instance->blog->template_set;
                    return 0 if !$ts_id;
                    my $app = MT::App->instance;
                    return 1 if eval {$app->registry('template_sets',$ts_id,'templates','widgetset')};
                    return 0;
                },
            },
        },
    };
}

sub theme_dashboard {
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    # Since there is no Theme Dashboard at the system level, capture and
    # redirect to the System Dashboard, if necessary.
    if ( !eval {$app->blog->id} && ($q->param('__mode') eq 'theme_dashboard') ) {
        $app->redirect( $app->uri.'?__mode=dashboard&blog_id=0' );
    }

    my $ts_id  = $app->blog->template_set;
    my $tm     = MT->component('ThemeManager');
    my $plugin = find_theme_plugin($ts_id);

    my $param = {};
    # Build the theme dashboard links
    $param->{theme_label}       = theme_label($ts_id, $plugin);
    $param->{theme_description} = theme_description($ts_id, $plugin);
    $param->{theme_author_name} = theme_author_name($ts_id, $plugin);
    $param->{theme_author_link} = theme_author_link($ts_id, $plugin);
    $param->{theme_link}        = theme_link($ts_id, $plugin);
    $param->{theme_doc_link}    = theme_doc_link($ts_id, $plugin);
    $param->{theme_version}     = theme_version($ts_id, $plugin);
    $param->{paypal_email}      = theme_paypal_email($ts_id, $plugin);
    $param->{about_designer}    = about_designer($ts_id, $plugin);
    $param->{theme_docs}        = theme_docs($ts_id, $plugin);
    if ( $app->blog->language ne $app->blog->template_set_language ) {
        $param->{template_set_language} = $app->blog->template_set_language;
    }

    my $dest_path = _theme_thumb_path();
    if ( -w $dest_path ) {
        $param->{theme_thumb_url} = _make_thumbnail($ts_id, $plugin);
    }
    else {
        $param->{theme_thumbs_path} = $dest_path;
    }
    $param->{theme_mini} = _make_mini();

    # Are the templates linked? We use this to show/hide the Edit/View
    # Templates links.
    my $linked = MT->model('template')->load({ blog_id     => $app->blog->id,
                                               linked_file => '*', });
    if ($linked) {
        # These templates *are* linked.
        $param->{linked_theme} = 1;
    }
    else {
        # These templates are *not* linked. Because they are not linked,
        # it's possible the user has edited them. Return a message saying
        # that. We can figure out which templates are edited by comparing
        # the created_on and modified_on dates.
        # So, first grab templates in the current blog that are not 
        # backups and that have had modifications made (modified_on col).
        my $iter = MT->model('template')->load_iter({
                blog_id     => $app->blog->id,
                type        => {not_like => 'backup'},
                modified_on => {not_null => 1},
            });
        while ( my $tmpl = $iter->() ) { 
            if ($tmpl->modified_on > $tmpl->created_on) {
                $param->{templates_modified} = 1;
                # Once a single modified template has been found there's
                # no reason to search anymore.
                last;
            }
        }
    }
    $param->{new_theme} = $q->param('new_theme');

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
    
    $param->{theme_dashboard_page_actions} = $app->page_actions('theme_dashboard');
    $param->{template_page_actions} = $app->page_actions('list_templates');

    my $tmpl = $tm->load_tmpl('theme_dashboard.mtml');
    return $app->listing({
        type     => 'theme',
        template => $tmpl,
        #terms    => \@terms,
        params   => $param,
        code     => sub {
            my ($theme, $row) = @_;
            # Use the plugin sig to grab the plugin.
            my $plugin = $MT::Plugins{$theme->plugin_sig}->{object};
            if (!$plugin) {
                # This plugin couldn't be loaded! That must mean the theme has 
                # been uninstalled, so remove the entry in the table.
                $theme->remove;
                $theme->save;
                next;
            }
            $row->{id}            = $theme->ts_id;
            $row->{label}         = theme_label($theme->ts_id, $plugin);
            $row->{thumbnail_url} = theme_thumbnail_url($theme->ts_id, $plugin);
            $row->{plugin_sig}    = $theme->plugin_sig;

            return $row;
        },
    });
}

sub select_theme {
    # The user probably wants to apply a new theme; we start by browsing the
    # available themes.
    # Save themes to the theme table, so that we can build a listing screen from them.
    _theme_check();

    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;
    
    # If the user is applying a theme to many blogs, they've come from a list 
    # action, and the ID parameter is full of blog IDs. Pass these along to
    # the template.
    my $blog_ids = join( ',', $q->param('id') );
    
    # Terms may be supplied if the user is searching.
    my $search_terms = $q->param('search');
    # Unset the search parameter to that the $app->listing won't try to build
    # a search result.
    $q->param('search', '');
    my @terms;
    if ($search_terms) {
        # Create an array of the search terms. "Like" lets us do the actual
        # search portion, while the "=> -or =>" lets us match any field.
        @terms = ({ts_label =>{like => '%'.$search_terms.'%'}} 
                    => -or => 
                  {ts_desc => {like => '%'.$search_terms.'%'}}
                    => -or => 
                  {ts_id => {like => '%'.$search_terms.'%'}}
                    => -or => 
                  {plugin_sig => {like => '%'.$search_terms.'%'}});
    }
    else {
        # Terms needs to be filled with something, otherwise it throws an 
        # error. Apparently, *if* an array is used for terms, MT expects 
        # there to be something in it, so undef'ing the @terms doesn't
        # help. This should match anything.
        @terms = ( { ts_label => {like => "%%"}} );
    }

    # Set the number of items to appear on the theme grid. 6 fit, so that's
    # what it's set to here. However, if unset, it defaults to 25!
    my $list_pref = $app->list_pref('theme') if $app->can('list_pref');
    $list_pref->{rows} = 999;


    my $plugin = MT->component('ThemeManager');
    my $tmpl = $plugin->load_tmpl('theme_select.mtml');
    return $app->listing({
        type     => 'theme',
        template => $tmpl,
        terms    => \@terms,
        params   => {
            search   => $search_terms,
            blog_ids => $blog_ids,
            blog_id  => $blog_ids, # If there's only one blog ID, it gets used here.
        },
        code => sub {
            my ($theme, $row) = @_;
            # Use the plugin sig to grab the plugin.
            my $plugin = $MT::Plugins{$theme->plugin_sig}->{object};
            if (!$plugin) {
                # This plugin couldn't be loaded! That must mean the theme has 
                # been uninstalled, so remove the entry in the table.
                $theme->remove;
                $theme->save;
                next;
            }
            $row->{id}             = $theme->ts_id;
            $row->{label}          = theme_label($theme->ts_id, $plugin);
            $row->{thumbnail_url}  = theme_thumbnail_url($theme->ts_id, $plugin);
            $row->{preview_url}    = theme_preview_url($theme->ts_id, $plugin);
            $row->{description}    = theme_description($theme->ts_id, $plugin);
            $row->{author_name}    = theme_author_name($theme->ts_id, $plugin);
            $row->{version}        = theme_version($theme->ts_id, $plugin);
            $row->{theme_link}     = theme_link($theme->ts_id, $plugin);
            $row->{theme_doc_link} = theme_doc_link($theme->ts_id, $plugin);
            $row->{about_designer} = about_designer($theme->ts_id, $plugin);
            $row->{plugin_sig}     = $theme->plugin_sig;
            $row->{theme_details}  = $app->load_tmpl('theme_details.mtml', $row);
            
            return $row;
        },
    });
}

sub setup_theme {
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;

    my $ts_id      = $q->param('theme_id');
    my $plugin_sig = $q->param('plugin_sig');
    
    my @blog_ids;
    if ( $q->param('blog_ids') ) {
        @blog_ids = split(/,/, $q->param('blog_ids'));
    }
    else {
        @blog_ids = ( $q->param('blog_id') );
    }

    my $param = {};
    $param->{ts_id}      = $ts_id;
    $param->{plugin_sig} = $plugin_sig;
    if (scalar @blog_ids > 1) {
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
    my $plugin = $MT::Plugins{$plugin_sig}->{object};
    my $ts     = $plugin->{registry}->{'template_sets'}->{$ts_id};
    $param->{ts_label} = theme_label($ts_id, $plugin);

    # Check for the widgetsets beacon. It will be set after visiting the 
    # "Save Widgets" screen. Or, we may bypass it because we don't always
    # need to show the "Save Widgets" screen.
    # Also, bypass the option to save widgets if we are mass-applying themes.
    # Bulk applying means we probably are just trying to wipe everything back
    # to a clean slate.
    if ( (scalar @blog_ids == 1) && !$q->param('save_widgetsets_beacon') ) {
        # Because the beacon hasn't been set, we need to first determine if
        # we should show the Save Widgets screen.
        foreach my $blog_id (@blog_ids) {
            # Check the currently-used template set against the returned
            # widgetsets to determine if we need to give the user a chance
            # to save things.
            my $blog = MT->model('blog')->load($blog_id);
            my $cur_ts_id = $blog->template_set;
            my $cur_ts_plugin = find_theme_plugin($cur_ts_id);
            unless ($cur_ts_plugin) {
                MT->log({ blog_id => $blog_id,
                          message => MT->translate('Theme Manager could not find a plugin corresponding to the template set currently applied to this blog. Skipping this blog for saving widget sets.') });
                next;
            }
            my $cur_ts_widgetsets = 
                $cur_ts_plugin->registry('template_sets',$cur_ts_id,'templates','widgetset');

            my @widgetsets = MT->model('template')->load({
                    type    => 'widgetset',
                    blog_id => $blog_id,
                });
            foreach my $widgetset (@widgetsets) {
                # Widget Sets from the currently-used template set need to be built.
                my $cur_ts_widgetset = $cur_ts_widgetsets->{$widgetset->identifier}->{'widgets'};
                my $ws_mtml;
                foreach my $widget (@$cur_ts_widgetset) {
                    $ws_mtml .= '<mt:include widget="'.$widget.'">';
                }
                # Now, compare the currently-used template set's Widget Sets
                # against the current template Widget Sets. If they match,
                # this means the user hasn't changed anything, and therefore
                # we don't need to ask if they want to save anything.
                if ($widgetset->text ne $ws_mtml) {
                    $param->{if_save_widgetsets} = 1;
                }
            }

            # Now we need to check the Widgets. Here we can just look for
            # unlinked templates. *Any* unlinked template will definitely
            # be replaced, and the user may want to save them.
            my @widgets = MT->model('template')->load({
                    type    => 'widget',
                    blog_id => $blog_id,
                });

            # We've got to test the results to determine if it's linked or not.
            # We're looking for any widgets that aren't linked (not "*") _or_
            # is NULL. (There's no way to do a null test during the object load.)
            foreach my $widget (@widgets) {
                if ( ($widget->linked_file ne '*') || !defined($widget->linked_file)  ) {
                    $param->{if_save_widgets} = 1;
                }
            }
        }
        # Is it possible the user may want to save widget sets and/or widgets?
        # If yes, we want to direct them to a screen where they can make that
        # choice. 
        if ( $param->{if_save_widgetsets} || $param->{if_save_widgets} ) {
            return $app->load_tmpl('save_widgetsets.mtml', $param);
        }
    }
    
    # Language support.
    # If there is more than one language supplied for the theme, we want to
    # offer the opportunity to select a language to apply to the templates
    # during installation.
    my @languages = _find_supported_languages($ts_id);
    if ( !$q->param('language') && (scalar @languages > 1) ) {
        my @param_langs;

        # Load the specified plugin/theme.
        my $c = $plugin;
        eval "require " . $c->l10n_class . ";";
        my $handles = MT->request('l10n_handle') || {};
        my $h       = $handles->{ $c->id };

        foreach my $language (@languages) {
            push @param_langs, { lang_tag  => $language,
                                 lang_name => $language };

        }
        $param->{languages} = \@param_langs;
        return $app->load_tmpl('select_language.mtml', $param);
    }
    else {
        # Either a language has been set, or there is only one language: english.
        my $selected_lang = $q->param('language') ? $q->param('language') : $languages[0];
        # If this theme is being applied to many blogs, assign the language to them all!
        foreach my $blog_id (@blog_ids) {
            my $blog = MT->model('blog')->load($blog_id);
            $blog->template_set_language($selected_lang);
            $blog->save;
        }
    }
    

    # As you may guess, this applies the template set to the current blog.
    use ThemeManager::TemplateInstall;
    foreach my $blog_id (@blog_ids) {
        ThemeManager::TemplateInstall::_refresh_all_templates($ts_id, $blog_id, $app);
    }


    my @loop;

    # This is for any required fields that the user may not have filled in.
    my @missing_required;
    # There's no reason to build options for blogs at the system level. If they
    # have any fields to set, they almost definitely need to be set on a
    # per-blog basis (otherwise what's the point of separate blogs or separate
    # theme options?), so we can just skip this.
    unless ($q->param('blog_ids')) {
        my $blog = MT->model('blog')->load( $param->{blog_id} );
        if (my $optnames = $ts->{options}) {
            my $types = $app->registry('config_types');
            my $fieldsets = $ts->{options}->{fieldsets};

            $fieldsets->{__global} = {
                label => sub { "Global Options"; }
            };

            require MT::Template::Context;
            my $ctx = MT::Template::Context->new();

            # This is a localized stash for field HTML
            my $fields;

            my $cfg_obj = $plugin->get_config_hash('blog:'.$blog->id);

            foreach my $optname (
                sort {
                    ( $optnames->{$a}->{order} || 999 ) <=> ( $optnames->{$b}->{order} || 999 )
                } keys %{$optnames}
              )
            {
                # Don't bother to look at the fieldsets.
                next if $optname eq 'fieldsets';

                my $field = $ts->{options}->{$optname};
                if ( $field->{required} && $field->{required} == 1 ) {
                    if ( my $cond = $field->{condition} ) {
                        if ( !ref($cond) ) {
                            $cond = $field->{condition} = $app->handler_to_coderef($cond);
                        }
                        next unless $cond->();
                    }

                    my $field_id = $ts_id . '_' . $optname;
                    if ( $types->{ $field->{'type'} } ) {
                        my $value;
                        $value = delete $cfg_obj->{$field_id};
                        my $out;
                        $field->{fieldset} = '__global' unless defined $field->{fieldset};
                        my $show_label =
                            defined $field->{show_label} ? $field->{show_label} : 1;
                        my $label = $field->{label} ne '' ? &{$field->{label}} : '';
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
                        $out .=
                            '  <div id="field-'
                            . $field_id
                            . '" class="field field-left-label pkg field-type-'
                            . $field->{type} . '">' . "\n";
                        $out .= "    <div class=\"field-header\">\n";
                        $out .=
                            "      <label for=\"$field_id\">"
                            . $label
                            . "</label>\n"
                                if $show_label;
                        $out .= "    </div>\n";
                        $out .= "    <div class=\"field-content\">\n";
                        my $hdlr =
                            MT->handler_to_coderef( $types->{ $field->{'type'} }->{handler} );
                        $out .= $hdlr->( $app, $ctx, $field_id, $field, $value );

                        if ( $field->{hint} ) {
                            $out .=
                              "      <div class=\"hint\">" . $field->{hint} . "</div>\n";
                        }
                        $out .= "    </div>\n";
                        $out .= "  </div>\n";
                        my $fs = $field->{fieldset};
                        push @{ $fields->{$fs} }, $out;
                    }
                    else {
                        MT->log(
                            {
                                message => 'Unknown config type encountered: '
                                  . $field->{'type'}
                            }
                        );
                    }
                }
            }
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
                    my $filter =
                        $fieldsets->{$set}->{format}
                      ? $fieldsets->{$set}->{format}
                      : '__default__';
                    $txt = MT->apply_text_filters( $txt->text(), [$filter] );
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
            }
            my @leftovers;
            foreach my $field_id ( keys %$cfg_obj ) {
                push @leftovers,
                  {
                    name  => $field_id,
                    value => $cfg_obj->{$field_id},
                  };
            }
        }
    }

    $param->{fields_loop}      = \@loop;
    $param->{saved}            = $q->param('saved');
    $param->{missing_required} = \@missing_required;
    
    # If this theme is being applied at the blog level, offer a "home" link.
    # Otherwise, themes are being mass-applied to many blogs at the system
    # level and we don't want to offer a single home page link.
    unless ( $q->param('blog_ids') ) {
        my @options;
        push @options, 'Theme Options'
            if eval {$app->registry('template_sets')->{$ts_id}->{options}};
        push @options, 'Widgets'
            if eval {$app->registry('template_sets',$ts_id,'templates','widgetset')};
        $param->{options} = join(' and ', @options);
    }
    
    # If there are *no* missing required fields, and the options *have*
    # been saved, that means we've completed everything that needs to be
    # done for the theme setup. So, *don't* return the fields_loop 
    # contents, and the "Theme Applied" completion message will show.
    if ( !$missing_required[0] && $q->param('saved') ) {
        $param->{fields_loop} = '';
    }

    $app->load_tmpl('theme_setup.mtml', $param);
}

sub _make_thumbnail {
    # We want a custom thumbnail to display on the Theme Options About tab.
    my ($ts_id, $plugin) = @_;
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    
    # Craft the destination path and URL.
    use File::Spec;
    my $dest_path = File::Spec->catfile( _theme_thumb_path(), $app->blog->id.'.jpg' );
    my $dest_url  = _theme_thumb_url();

    # Check if the thumbnail is cached (exists) and is less than 1 day old. 
    # If it's older, we want a new thumb to be created.
    my $fmgr = MT::FileMgr->new('Local')
        or return $app->error( MT::FileMgr->errstr );
    if ( ($fmgr->exists($dest_path)) && (-M $dest_path <= 1) ) {
        # We've found a cached image! Now we need to check that it's usable.
        return _check_thumbalizr_result($dest_path, $dest_url, $ts_id, $plugin);
    }
    else {
        # No screenshot was found, or it's too old--so create one.
        # First, create the destination directory, if necessary.
        my $dir = _theme_thumb_path();
        if (!-d $dir) {
            $fmgr->mkpath($dir)
                or return $app->error( MT::FileMgr->errstr );
        }
        # Now build and cache the thumbnail URL
        # This is done with thumbalizr.com, a free online screenshot service.
        # Their API is completely http based, so this is all we need to do to
        # get an image from them.
        my $thumb_url = 'http://api.thumbalizr.com/?url='.$app->blog->site_url.'&width=300';
        use LWP::Simple;
        my $http_response = LWP::Simple::getstore($thumb_url, $dest_path);
        
        # Finally, check that the saved image is actually usable.
        return _check_thumbalizr_result($dest_path, $dest_url, $ts_id, $plugin);
    }
}

sub _check_thumbalizr_result {
    # We need to figure out if the returned image is actually a thumbnail, or
    # if it's the "queued" or "failed" image from thumbalizr.
    my ($dest_path, $dest_url, $ts_id, $plugin) = @_;

    my $fmgr = MT::FileMgr->new('Local')
        or die MT::FileMgr->errstr;
    my $content = $fmgr->get_data($dest_path);

    # Create an MD5 hash of the content. This provides us with
    # something unique to compare against.
    use Digest::MD5;
    my $md5 = Digest::MD5->new;
    $md5->add( $content );
    
    # The "queued" image has an MD5 hash of:
    # eb433ad65b8aa50047e6f2de1530d6cf
    # The "failed" image has an MD5 hash of:
    # ac47a999e5ce1769d480a66b0554343d
    if ( ($md5->hexdigest eq 'eb433ad65b8aa50047e6f2de1530d6cf')
            || ($md5->hexdigest eq 'ac47a999e5ce1769d480a66b0554343d') ) {
        # This is the "queued" image being displayed. Instead of this, we
        # want to show the "preview" image defined by the template set.
        return theme_preview_url($ts_id, $plugin);
    }
    else {
        return $dest_url;
    }
}

sub _make_mini {
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $tm = MT->component('ThemeManager');

    use File::Spec;
    my $dest_path = File::Spec->catfile( _theme_thumb_path(), $app->blog->id.'-mini.jpg' );
    my $dest_url = caturl($app->static_path,'support','plugins',$tm->id,'theme_thumbs',
            $app->blog->id.'-mini.jpg');
    # Decide if we need to create a new mini or not.
    my $fmgr = MT::FileMgr->new('Local')
        or return MT::FileMgr->errstr;
    unless ( ($fmgr->exists($dest_path)) && (-M $dest_path <= 1) ) {
        my $source_path = File::Spec->catfile( _theme_thumb_path(), $app->blog->id.'.jpg' );
        use MT::Image;
        my $img = MT::Image->new( Filename => $source_path )
            or return 0;
        my $resized_img = $img->scale( Width => 138 );
        $fmgr->put_data($resized_img, $dest_path)
            or return MT::FileMgr->errstr;
    }
    return $dest_url;
}

sub paypal_donate {
    # Donating through PayPal requires a pop-up dialog so that we can break 
    # out of MT and the normal button handling. (That is, clicking a PayPal
    # button on Theme Options causes MT to try to save Theme Options, not 
    # launch the PayPal link. Creating a dialog breaks out of that
    # requirement.)
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $param = {};
    $param->{theme_label}  = $q->param('theme_label');
    $param->{paypal_email} = $q->param('paypal_email');
    return $app->load_tmpl( 'paypal_donate.mtml', $param );
}

sub edit_templates {
    # Pop up the warning dialog about what it really means to "edit templates."
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $param = {};
    $param->{blog_id} = $q->param('blog_id');
    return $app->load_tmpl( 'edit_templates.mtml', $param );
}

sub unlink_templates {
    # Unlink all templates.
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $blog_id = $q->param('blog_id');
    my $iter = MT->model('template')->load_iter({ blog_id     => $blog_id,
                                                  linked_file => '*', });
    while ( my $tmpl = $iter->() ) {
        $tmpl->linked_file(undef);
        $tmpl->linked_file_mtime(undef);
        $tmpl->linked_file_size(undef);
        $tmpl->save;
    }
    my $return_url = $app->uri.'?__mode=theme_dashboard&blog_id='.$blog_id
        .'&unlinked=1';
    my $param = { return_url => $return_url };
    return $app->load_tmpl( 'templates_unlinked.mtml', $param );
}

sub theme_info {
    my $app = MT->instance;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $param = {};
    
    my $plugin_sig = $q->param('plugin_sig');
    my $plugin = $MT::Plugins{$plugin_sig}->{object};
    
    my $ts_id = $q->param('ts_id');
    
    $param->{id}             = $ts_id;
    $param->{label}          = theme_label($ts_id, $plugin);
    $param->{thumbnail_url}  = theme_thumbnail_url($ts_id, $plugin);
    $param->{preview_url}    = theme_preview_url($ts_id, $plugin);
    $param->{description}    = theme_description($ts_id, $plugin);
    $param->{author_name}    = theme_author_name($ts_id, $plugin);
    $param->{version}        = theme_version($ts_id, $plugin);
    $param->{theme_link}     = theme_link($ts_id, $plugin);
    $param->{theme_doc_link} = theme_doc_link($ts_id, $plugin);
    $param->{about_designer} = about_designer($ts_id, $plugin);
    $param->{plugin_sig}     = $plugin_sig;
    my $ts_count = keys %{ $plugin->{registry}->{'template_sets'} };
    $param->{plugin_label}   = $ts_count > 1 ? $plugin->label : 0;
    
    $param->{theme_details} = $app->load_tmpl('theme_details.mtml', $param);
    
    return $app->load_tmpl('theme_info.mtml', $param);
}

sub xfrm_disable_tmpl_link {
    # If templates are linked, we don't want users to be able to simply unlink
    # them, because that "breaks the seal" and lets them modify the template,
    # so upgrades are no longer easy. 
    my ($cb, $app, $tmpl) = @_;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $linked = MT->model('template')->load(
                        { id          => $q->param('id'),
                          linked_file => '*', });
    if ( $linked ) {
        my $old = 'name="linked_file"';
        my $new = 'name="linked_file" disabled="disabled"';
        $$tmpl =~ s/$old/$new/mgi;
        
        $old = 'name="outfile"';
        $new = 'name="outfile" disabled="disabled"';
        $$tmpl =~ s/$old/$new/mgi;

        $old = 'name="identifier"';
        $new = 'name="identifier" disabled="disabled"';
        $$tmpl =~ s/$old/$new/mgi;
    }
}

sub xfrm_add_thumb {
    # Add a small thumbnail and link above the content nav area of Theme
    # Options, to help better tie the Theme Options and Theme Dashboard
    # together.
    my ($cb, $app, $tmpl) = @_;
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
            my $new = $old . '<div style="margin-bottom: 8px; border: 1px solid #ddd;"><a href="<mt:Var name="script_uri">?__mode=theme_dashboard&blog_id=<mt:Var name="blog_id">" title="Visit the Theme Dashboard"><img src="'.$dest_url.'" width="138" height="112" /></a></div>';
            $$tmpl =~ s/$old/$new/mgi;
        }
    }
}

sub _theme_check {
    # We need to store templates in the DB so that we can do the
    # $app->listing thing to build the page.
    
    # Look through all the plugins and find the template sets.
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @sets   = keys %{ $r->{'template_sets'} };
        foreach my $set (@sets) {
            # Has this theme already been saved?
            use ThemeManager::Theme;
            my $theme = ThemeManager::Theme->load({
                    ts_id      => $set,
                    plugin_sig => $sig,
                });
            if (!$theme) {
                # Not saved, so save it.
                $theme = ThemeManager::Theme->new();
                $theme->plugin_sig( $sig );
                $theme->ts_id( $set );
                $theme->ts_label( theme_label($set, $obj) );
                $theme->ts_desc(  theme_description($set, $obj) );
                $theme->save;
            }
        }
    }
    # Should we delete any themes from the db?
    my $iter = ThemeManager::Theme->load_iter({},{sort_by => 'ts_id',});
    while (my $theme = $iter->()) {
        # Use the plugin sig to grab the plugin.
        my $plugin = $MT::Plugins{$theme->plugin_sig}->{object};
        if (!$plugin) {
            # This plugin couldn't be loaded! That must mean the theme has 
            # been uninstalled, so remove the entry in the table.
            $theme->remove;
            $theme->save;
            next;
        }
        else {
            if (!$plugin->{registry}->{'template_sets'}->{$theme->ts_id}) {
                # This template set couldn't be loaded! That must mean the theme
                # has been uninstalled, so remove the entry in the table.
                $theme->remove;
                $theme->save;
                next;
            }
        }
    }
}

sub rebuild_tmpl {
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;
    my $blog = $app->blog;
    my $return_val = {
        success => 0
    };
    my $templates = MT->model('template')->lookup_multi([ $q->param('id') ]);
  TEMPLATE: for my $tmpl (@$templates) {
      next TEMPLATE if !defined $tmpl;
      next TEMPLATE if $tmpl->blog_id != $blog->id;
      next TEMPLATE unless $tmpl->build_type;
      
      $return_val->{success} = $app->rebuild_indexes(
          Blog     => $blog,
          Template => $tmpl,
          Force    => 1,
      );
      unless ($return_val->{success}) {
          $return_val->{errstr} = $app->errstr;
      }
    }
    return _send_json_response( $app, $return_val );
}


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
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;
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
            my $tblog = $obj->blog_id == $blog->id ? $blog : MT->model('blog')->load( $obj->blog_id );
            if ($tblog) {
                require MT::CMS::Template;
                $row->{archive_types} = MT::CMS::Template::_populate_archive_loop( $app, $tblog, $obj );
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
        $row->{use_cache} = ( ($obj->cache_expire_type || 0) != 0 ) ? 1 : 0;
        $row->{template_type} = $template_type;
        $row->{type} = 'entry' if $type eq 'individual';
        $row->{status} = 'Foo';

        if (my $lfile = $obj->linked_file) { 
            # TODO - Change use to require
            use String::CRC::Cksum qw(cksum);
            my ($cksum1, $size1) = cksum( $obj->MT::Object::text() ); 
            my ($cksum2, $size2) = cksum( $obj->_sync_from_disk() );
            $row->{has_changed} = ($cksum1 ne $cksum2);
#            $row->{has_changed} = ($obj->text eq $obj->MT::Object::text());
        }
        
        my $published_url = $obj->published_url;
        $row->{published_url} = $published_url if $published_url;
    };

    my $filter = $q->param('filter_key');
    my $template_type = $filter || '';
    $template_type =~ s/_templates//;

    $params->{screen_class} = "list-template";
    $params->{listing_screen} = 1;

    $app->load_list_actions( 'template', $params );
    $params->{page_actions} = $app->page_actions('list_templates');
    $params->{search_label} = $app->translate("Templates");
    $params->{object_type} = 'template';
    $params->{blog_view} = 1;
    $params->{refreshed} = $q->param('refreshed');
    $params->{published} = $q->param('published');
    $params->{saved_copied} = $q->param('saved_copied');
    $params->{saved_deleted} = $q->param('saved_deleted');
    $params->{saved} = $q->param('saved');

    # determine list of system template types:
    my $scope;
    my $set;
    if ( $blog ) {
        $set   = $blog->template_set;
        $scope = 'system';
    }
    else {
        $scope = 'global:system';
    }
    my @tmpl_path = ( $set && ($set ne 'mt_blog')) ? ("template_sets", $set, 'templates', $scope) : ("default_templates", $scope);
    my $sys_tmpl = MT->registry(@tmpl_path) || {};

    my @tmpl_loop;
    my %types;
    if ($template_type ne 'backup') {
        if ($blog) {
            # blog template listings
            %types = ( 
                'index' => {
                    label => $app->translate("Index Templates"),
                    type => 'index',
                    order => 100,
                },
                'archive' => {
                    label => $app->translate("Archive Templates"),
                    type => ['archive', 'individual', 'page', 'category'],
                    order => 200,
                },
                'module' => {
                    label => $app->translate("Template Modules"),
                    type => 'custom',
                    order => 300,
                },
                'system' => {
                    label => $app->translate("System Templates"),
                    type => [ keys %$sys_tmpl ],
                    order => 400,
                },
            );
        } else {
            # global template listings
            %types = ( 
                'module' => {
                    label => $app->translate("Template Modules"),
                    type => 'custom',
                    order => 100,
                },
                'email' => {
                    label => $app->translate("Email Templates"),
                    type => 'email',
                    order => 200,
                },
                'system' => {
                    label => $app->translate("System Templates"),
                    type => [ keys %$sys_tmpl ],
                    order => 300,
                },
            );
        }
    } else {
        # global template listings
        %types = ( 
            'backup' => {
                label => $app->translate("Template Backups"),
                type => 'backup',
                order => 100,
            },
        );
    }
    my @types = sort { $types{$a}->{order} <=> $types{$b}->{order} } keys %types;
    if ($template_type) {
        @types = ( $template_type );
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
        unless ( exists($types{$tmpl_type}->{type})
          && 'ARRAY' eq ref($types{$tmpl_type}->{type})
          && 0 == scalar(@{$types{$tmpl_type}->{type}}) )
        {
            $terms->{type} = $types{$tmpl_type}->{type};
            $tmpl_param = $app->listing(
                {
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
        $tmpl_param->{template_type} = $tmpl_type;
        $tmpl_param->{template_type_label} = $template_type_label;
        push @tmpl_loop, $tmpl_param;
    }
    if ($filter) {
        $params->{filter_key} = $filter;
        $params->{filter_label} = $types{$template_type}{label}
            if exists $types{$template_type};
        $q->param('filter_key', $filter);
    } else {
        # restore filter_key param (we modified it for the
        # sake of the individual table listings)
        $app->delete_param('filter_key');
    }

    $params->{template_type_loop} = \@tmpl_loop;
    $params->{screen_id} = "list-template";
}

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

    return $app->load_tmpl('list_template.tmpl', $params);
}

sub _find_supported_languages {
    my $ts_id = shift;
    my $ts_plugin = find_theme_plugin($ts_id);
    # Languages need to be specified for each template set. We can't just
    # search for all available languages because if the plugin is a theme
    # pack (that is, contains many themes), it's possible that only some
    # themes may contain tranlations.
    my $langs = $ts_plugin->registry('template_sets',$ts_id,'languages');
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
    }
    if (!@ts_langs) {
        # No languages were specified. So, lets default to english.
        $ts_langs[0] = 'en-us';
    }
    return @ts_langs;
}

1;

__END__
