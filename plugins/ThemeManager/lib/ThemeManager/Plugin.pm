package ThemeManager::Plugin;

use strict;
use MT;

sub update_menus {
    my $app = MT->instance;
    # We only want to remove the Templates menu at the blog-level. We don't
    # know for sure what templates are at the system-level, so just blanket
    # denying access is probably not best.
    my $blog_id = $app->param('blog_id');
    if ($blog_id) {
        # Any linked templates?
        use MT::Template;
        my $linked_tmpl = MT::Template->load(
                            { blog_id     => $blog_id,
                              linked_file => '*', });
        # If there are linked templates, then remove the Templates menu.
        if ($linked_tmpl) {
            my $core = MT->component('Core');
            delete $core->{registry}->{applications}->{cms}->{menus}->{'design:template'};
        }
    }
    # Now just add the Theme Options menu item.
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
    # Override the blog-level "Refresh Blog Templates" page action, causing
    # a popup to start the theme selection process. We want to keep the
    # Refresh Blog Templates link because it's familiar at this point.
    return {
        list_templates => {
            refresh_all_blog_templates => {
                label     => "Refresh Blog Templates",
                dialog    => 'select_theme',
                condition => sub {
                                MT->app->blog;
                             },
                order => 1000,
            },
        },
        theme_dashboard => {
            theme_options => {
                label => 'Edit Theme Options',
                order => 100,
                mode => 'theme_options',
                condition => sub {
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
                    return 1 if eval {$app->registry('template_sets')->{$ts_id}->{templates}->{widgetset}};
                    return 0;
                },
            },
            custom_css => {
                label => 'Customize Stylesheet',
                order => 102,
                mode => 'custom_css_edit',
                condition => sub {
                    my $plugin = MT->component('CustomCSS');
                    return 0 if !$plugin;
                    require CustomCSS::Plugin;
                    return CustomCSS::Plugin::uses_custom_css();
                },
            },
        },
    };
}



sub theme_dashboard {
    my $app    = MT->instance;
    my $ts     = $app->blog->template_set;
    use ConfigAssistant::Plugin;
    my $plugin = ConfigAssistant::Plugin::find_theme_plugin($ts);

    my $param = {};
    # Build the theme dashboard links
    use ThemeManager::Util;
    $param->{theme_label}       = ThemeManager::Util::theme_label($ts, $plugin);
    $param->{theme_description} = ThemeManager::Util::theme_description($ts, $plugin);
    $param->{theme_author_name} = ThemeManager::Util::theme_author_name($ts, $plugin);
    $param->{theme_author_link} = ThemeManager::Util::theme_author_link($ts, $plugin);
    $param->{theme_link}        = ThemeManager::Util::theme_link($ts, $plugin);
    $param->{theme_doc_link}    = ThemeManager::Util::theme_docs($ts, $plugin);
    $param->{theme_version}     = ThemeManager::Util::theme_version($ts, $plugin);
    $param->{paypal_email}      = ThemeManager::Util::theme_paypal_email($ts, $plugin);
    $param->{about_designer}    = ThemeManager::Util::about_designer($ts, $plugin);
    $param->{theme_thumb_url}   = _make_thumbnail();
    $param->{theme_mini}        = _make_mini();
    

    # Are the templates linked? We use this to show/hide the Edit/View
    # Templates links.
    use MT::Template;
    my $linked = MT::Template->load(
                        { blog_id     => $app->blog->id,
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
        my $iter = MT::Template->load_iter(
                        { blog_id    => $app->blog->id,
                          type => {not_like => 'backup'},
                          modified_on => {not_null => 1}, });
        while ( my $tmpl = $iter->() ) { 
            if ($tmpl->modified_on > $tmpl->created_on) {
                $param->{templates_modified} = 1;
                # Once a single modified template has been found there's
                # no reason to search anymore.
                last;
            }
        }
    }
    $param->{new_theme} = $app->param('new_theme');
    
    # The user probably wants to apply a new theme; we start by browsing the
    # available themes.
    # Save themes to the theme table, so that we can build a listing screen from them.
    _theme_check();

    # Set the number of items to appear on the theme grid. 6 fit, so that's
    # what it's set to here. However, if unset, it defaults to 25!
    my $list_pref = $app->list_pref('theme') if $app->can('list_pref');
    $list_pref->{rows} = 12;

    my $tm_plugin = MT->component('ThemeManager');
    my $tmpl = $tm_plugin->load_tmpl('theme_dashboard.mtml');
    return $app->listing({
        type     => 'theme',
        template => $tmpl,
#        terms    => \@terms,
        params   => $param,
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
            $row->{id}            = $theme->ts_id;
            $row->{label}         = ThemeManager::Util::theme_label($theme->ts_id, $plugin);
            $row->{thumbnail_url} = ThemeManager::Util::theme_thumbnail_url($theme->ts_id, $plugin);
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
    
    # If the user is applying a theme to many blogs, they've come from a list 
    # action, and the ID parameter is full of blog IDs. Pass these along to
    # the template.
    my $blog_ids = join( ',', $app->param('id') );
    
    # Terms may be supplied if the user is searching.
    my $search_terms = $app->param('search');
    # Unset the search parameter to that the $app->listing won't try to build
    # a search result.
    $app->param('search', '');
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
    $list_pref->{rows} = 6;

    use ThemeManager::Util;

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
            $row->{label}          = ThemeManager::Util::theme_label($theme->ts_id, $plugin);
            $row->{thumbnail_url}  = ThemeManager::Util::theme_thumbnail_url($theme->ts_id, $plugin);
            $row->{preview_url}    = ThemeManager::Util::theme_preview_url($theme->ts_id, $plugin);
            $row->{description}    = ThemeManager::Util::theme_description($theme->ts_id, $plugin);
            $row->{author_name}    = ThemeManager::Util::theme_author_name($theme->ts_id, $plugin);
            $row->{version}        = ThemeManager::Util::theme_version($theme->ts_id, $plugin);
            $row->{theme_link}     = ThemeManager::Util::theme_link($theme->ts_id, $plugin);
            $row->{theme_docs}     = ThemeManager::Util::theme_docs($theme->ts_id, $plugin);
            $row->{about_designer} = ThemeManager::Util::about_designer($theme->ts_id, $plugin);
            $row->{plugin_sig}     = $theme->plugin_sig;
            $row->{theme_details}  = $app->load_tmpl('theme_details.mtml', $row);
            
            return $row;
        },
    });
}

sub setup_theme {
    my $app = shift;
    my $ts_id      = $app->param('theme_id');
    my $plugin_sig = $app->param('plugin_sig');
    my @blog_ids;
    if ( $app->param('blog_ids') ) {
        @blog_ids = split(/,/, $app->param('blog_ids'));
    }
    else {
        @blog_ids = ( $app->param('blog_id') );
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
    $param->{ts_label} = ThemeManager::Util::theme_label($ts_id, $plugin);

    use ConfigAssistant::Util;

    # Check for the widgetsets beacon. It will be set after visiting the 
    # "Save Widgets" screen. Or, we may bypass it because we don't always
    # need to show the "Save Widgets" screen.
    if ( !$app->param('save_widgetsets_beacon') ) {
        # Because the beacon hasn't been set, we need to first determine if
        # we should show the Save Widgets screen.
        foreach my $blog_id (@blog_ids) {
            # Check the currently-used template set against the returned
            # widgetsets to determine if we need to give the user a chance
            # to save things.
            use MT::Blog;
            my $blog = MT::Blog->load($blog_id);
            my $cur_ts_id = $blog->template_set;
            my $cur_ts_plugin = ConfigAssistant::Util::find_theme_plugin($cur_ts_id);
            my $cur_ts_widgetsets = 
                $cur_ts_plugin->{registry}->{'template_sets'}->{$cur_ts_id}->{'templates'}->{'widgetset'};

            use MT::Template;
            my @widgetsets = MT::Template->load({ type    => 'widgetset', 
                                                  blog_id => $blog_id, });
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
            my @widgets = MT::Template->load(
                                     { type        => 'widget',
                                       blog_id     => $blog_id, }
                                    );

            # We've got to test the results to determine if it's linked or not.
            # We're looking for any widgets that aren't linked (not "*") _or_
            # is NULL. (There's no way to do a null test during the object load.)
            foreach my $widget (@widgets) {
                if ( ($widget->linked_file ne '*') || ( !defined($widget->linked_file) ) ) {
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

    # As you may guess, this applies the template set to the current blog.
    foreach my $blog_id (@blog_ids) {
        _refresh_all_templates($ts_id, $blog_id, $app);
    }


    my @loop;

    # This is for any required fields that the user may not have filled in.
    my @missing_required;
    # There's no reason to build options for blogs at the system level. If they
    # have any fields to set, they almost definitely need to be set on a
    # per-blog basis (otherwise what's the point of separate blogs or separate
    # theme options?), so we can just skip this.
    if ($app->param('blog_id') ne '0') {
        if (my $optnames = $ts->{options}) {
            use MT::Util qw( dirify );

            my $types = $app->registry('config_types');
            my $fieldsets = $ts->{options}->{fieldsets};

            $fieldsets->{__global} = {
                label => sub { "Global Options"; }
            };

            require MT::Template::Context;
            my $ctx = MT::Template::Context->new();

            # This is a localized stash for field HTML
            my $fields;

            my $cfg_obj = $plugin->get_config_hash('blog:'.$app->blog->id);

            foreach my $optname (
                sort {
                    ( $optnames->{$a}->{order} || 999 ) <=> ( $optnames->{$b}->{order} || 999 )
                } keys %{$optnames}
              )
            {
                # Don't bother to look at the fieldsets.
                next if $optname eq 'fieldsets';

                my $field = $ts->{options}->{$optname};
                if ($field->{required} == 1) {
                    if ( my $cond = $field->{condition} ) {
                        if ( !ref($cond) ) {
                            $cond = $field->{condition} = $app->handler_to_coderef($cond);
                        }
                        next unless $cond->();
                    }

                    my $field_id = $ts_id . '_' . $optname;
                    if ( $types->{ $field->{'type'} } ) {
                        my $value;
                        my $value = delete $cfg_obj->{$field_id};
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
                        if ( !$value && $app->param('saved') ) {
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
    $param->{saved}            = $app->param('saved');
    $param->{missing_required} = \@missing_required;
    
    # If this theme is being applied at the blog level, offer a "home" link.
    # Otherwise, themes are being mass-applied to many blogs at the system
    # level and we don't want to offer a single home page link.
    if ( !$app->param('blog_ids') ) {
        my @options;
        push @options, 'Theme Options'
            if eval {$app->registry('template_sets')->{$ts_id}->{options}};
        push @options, 'Widgets'
            if eval {$app->registry('template_sets')->{$ts_id}->{templates}->{widgetset}};
        $param->{options} = join(' and ', @options);
    }
    
    # If there are *no* missing required fields, and the options *have*
    # been saved, that means we've completed everything that needs to be
    # done for the theme setup. So, *don't* return the fields_loop 
    # contents, and the "Theme Applied" completion message will show.
    if ( !$missing_required[0] && $app->param('saved') ) {
        $param->{fields_loop} = '';
        
    }

    $app->load_tmpl('theme_setup.mtml', $param);
}

sub template_set_change {
    # Link the templates to the theme.
    my ($cb, $param) = @_;
    my $blog_id = $param->{blog}->id;
    my $ts_id   = $param->{blog}->template_set;
    
    use ConfigAssistant::Util;
    my $cur_ts_plugin = ConfigAssistant::Util::find_theme_plugin($ts_id);
    my $cur_ts_widgets = 
        $cur_ts_plugin->{registry}->{'template_sets'}->{$ts_id}->{'templates'}->{'widget'};
    
    # Grab all of the templates except the Widget Sets, because the user
    # should be able to edit (drag-drop) those all the time.
    use MT::Template;
    my $iter = MT::Template->load_iter({ blog_id => $blog_id,
                                         type    => {not => 'backup'}, });
    while ( my $tmpl = $iter->() ) {
        if (
            ( ($tmpl->type ne 'widgetset') && ($tmpl->type ne 'widget') )
            || ( ($tmpl->type eq 'widget') && ($cur_ts_widgets->{$tmpl->identifier}) )
        ) {
            $tmpl->linked_file('*');
        }
        else {
            # Just in case Widget Sets were previously linked,
            # now forcefully unlink!
            $tmpl->linked_file(undef);
        }
        $tmpl->save;
    }
}

sub template_filter {
    my ($cb, $templates) = @_;
    my $app = MT->instance;
    my $blog_id = $app->blog 
        ? $app->blog->id 
        : return; # Only work on blog-specific widgets and widget sets

    # Give up if the user didn't ask for anything to be saved.
    unless ( $app->param('save_widgets') || $app->param('save_widgetsets') ) {
        return;
    }

    my $index = 0; # To grab the current array item index.
    my $tmpl_count = scalar @$templates;

    while ($index <= $tmpl_count) {
        my $tmpl = @$templates[$index];
        if ( $tmpl->{'type'} eq 'widgetset' ) {
            if ( $app->param('save_widgetsets') ) {
                # Try to count a Widget Set in this blog with the same identifier.
                use MT::Template;
                my $installed = MT::Template->load( { blog_id    => $blog_id,
                                                       type       => 'widgetset',
                                                       identifier => $tmpl->{'identifier'}, } );
                # If a Widget Set by this name was found, remove the template from the
                # array of those templates to be installed.
                if ($installed) {
                    # Delete the Widget Set so it doesn't overwrite our existing Widget Set!
                    splice(@$templates, $index, 1);
                    next;
                }
            }
        }
        elsif ( $app->param('save_widgets') && $tmpl->{'type'} eq 'widget' ) {
            # Try to count a Widget in this blog with the same identifier.
            use MT::Template;
            my $installed = MT::Template->count( { blog_id    => $blog_id,
                                                   type       => 'widget',
                                                   identifier => $tmpl->{'identifier'}, } );
            # If a Widget by this name was found, remove the template from the
            # array of those templates to be installed.
            if ($installed) {
                # Delete the Widget so it doesn't overwrite our existing Widget!
                splice(@$templates, $index, 1);
                next;
            }
        }
        $index++;
    }
}

sub _make_thumbnail {
    # We want a custom thumbnail to display on the Theme Options About tab.
    my $app = MT->instance;
    
    # Craft the destination path and URL.
    use File::Spec;
    my $dest_path = File::Spec->catfile( 
        $app->config('StaticFilePath'), 'support', 'plugins', 'ThemeManager', 
            'theme_thumbs', $app->blog->id.'.jpg' 
    );
    my $dest_url = $app->static_path.'support/plugins/ThemeManager/theme_thumbs/'.$app->blog->id.'.jpg';

    # Check if the thumbnail is cached (exists) and is less than 1 day old. 
    # If it's older, we want a new thumb to be created.
    if ( (-e $dest_path) && (-M $dest_path <= 1) ) {
        # We've found a cached image! No need to grab a new screenshot; just 
        # use the existing one.
        return '<img src="'.$dest_url.'" width="300" height="240" title="'
            .$app->blog->name.' on '.$app->blog->site_url.'" />';
    }
    else {
        # No screenshot was found, or it's too old--so create one.
        # First, create the destination directory, if necessary.
        my $dir = File::Spec->catfile( 
            $app->config('StaticFilePath'), 'support', 'plugins', 'ThemeManager', 
                'theme_thumbs' 
        );
        if (!-d $dir) {
            my $fmgr = MT::FileMgr->new('Local')
                or return MT::FileMgr->errstr;
            $fmgr->mkpath($dir)
                or return MT::FileMgr->errstr;
        }
        # Now build and cache the thumbnail URL
        # This is done with thumbalizr.com, a free online screenshot service.
        # Their API is completely http based, so this is all we need to do to
        # get an image from them.
        my $thumb_url = 'http://api.thumbalizr.com/?url='.$app->blog->site_url.'&width=300';
        use LWP::Simple;
        my $http_response = LWP::Simple::getstore($thumb_url, $dest_path);
        if ($http_response == 200) {
            # success!
            return '<img src="'.$dest_url.'" width="300" height="240" title="'
                .$app->blog->name.' on '.$app->blog->site_url.'" />';
        }
    }
}

sub _make_mini {
    my $app = MT->instance;
    
    use File::Spec;
    my $dest_path = File::Spec->catfile( 
        $app->config('StaticFilePath'), 'support', 'plugins', 'ThemeManager', 
            'theme_thumbs', $app->blog->id.'-mini.jpg' 
    );
    my $dest_url = $app->static_path.'support/plugins/ThemeManager/theme_thumbs/'
                    .$app->blog->id.'-mini.jpg';
    # Decide if we need to create a new mini or not.
    unless ( (-e $dest_path) && (-M $dest_path <= 1) ) {
        my $source_path = File::Spec->catfile( 
            $app->config('StaticFilePath'), 'support', 'plugins', 'ThemeManager', 
                'theme_thumbs', $app->blog->id.'.jpg' 
        );
        use MT::Image;
        my $img = MT::Image->new( Filename => $source_path );
        my $resized_img = $img->scale( Width => 138 );
        my $fmgr = MT::FileMgr->new('Local')
            or return MT::FileMgr->errstr;
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
    my $param = {};
    $param->{theme_label}  = $app->param('theme_label');
    $param->{paypal_email} = $app->param('paypal_email');
    return $app->load_tmpl( 'paypal_donate.mtml', $param );
}

sub edit_templates {
    # Pop up the warning dialog about what it really means to "edit templates."
    my $app = shift;
    my $param->{blog_id} = $app->param('blog_id');
    return $app->load_tmpl( 'edit_templates.mtml', $param );
}

sub unlink_templates {
    # Unlink all templates.
    my $app = shift;
    my $blog_id = $app->param('blog_id');
    use MT::Template;
    my $iter = MT::Template->load_iter({ blog_id     => $blog_id,
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
    my $param = {};
    
    my $plugin_sig = $app->param('plugin_sig');
    my $plugin = $MT::Plugins{$plugin_sig}->{object};
    
    my $ts_id = $app->param('ts_id');
    
    $param->{id}             = $ts_id;
    $param->{label}          = ThemeManager::Util::theme_label($ts_id, $plugin);
    $param->{thumbnail_url}  = ThemeManager::Util::theme_thumbnail_url($ts_id, $plugin);
    $param->{preview_url}    = ThemeManager::Util::theme_preview_url($ts_id, $plugin);
    $param->{description}    = ThemeManager::Util::theme_description($ts_id, $plugin);
    $param->{author_name}    = ThemeManager::Util::theme_author_name($ts_id, $plugin);
    $param->{version}        = ThemeManager::Util::theme_version($ts_id, $plugin);
    $param->{theme_link}     = ThemeManager::Util::theme_link($ts_id, $plugin);
    $param->{theme_docs}     = ThemeManager::Util::theme_docs($ts_id, $plugin);
    $param->{about_designer} = ThemeManager::Util::about_designer($ts_id, $plugin);
    $param->{plugin_sig}     = $plugin_sig;
    my $ts_count = keys %{ $plugin->{registry}->{'template_sets'} };
    $param->{plugin_label}   = $ts_count > 1 ? $plugin->label : 0;
    
    $param->{theme_details} = $app->load_tmpl('theme_details.mtml', $param);
    
    return $app->load_tmpl('theme_info.mtml', $param);
}

sub _refresh_all_templates {
    # This is basically lifted right from MT::CMS::Template (from Movable Type
    # version 4.261), with some necessary changes to work with Theme Manager.
    my ($template_set, $blog_id, $app) = @_;

    my $t = time;

    my @id = ( scalar $blog_id );
    
    require MT::Template;
    require MT::DefaultTemplates;
    require MT::Blog;
    require MT::Permission;
    require MT::Util;

    my $user = $app->user;
    my @blogs_not_refreshed;
    my $can_refresh_system = $user->is_superuser() ? 1 : 0;
    BLOG: 
    for my $blog_id (@id) {
        my $blog;
        if ($blog_id) {
            $blog = MT::Blog->load($blog_id);
            next BLOG unless $blog;
        }

        if (!$can_refresh_system) {  # system refreshers can refresh all blogs
            my $perms = MT::Permission->load(
                { blog_id => $blog_id, author_id => $user->id } );
            my $can_refresh_blog = !$perms                       ? 0
                                 : $perms->can_edit_templates()  ? 1
                                 : $perms->can_administer_blog() ? 1
                                 :                                 0
                                 ;
            if (!$can_refresh_blog) {
                push @blogs_not_refreshed, $blog->id;
                next BLOG;
            }
        }

        my $tmpl_list;

        # the user wants to back up all templates and
        # install the new ones
        my @ts = MT::Util::offset_time_list( $t, $blog_id );
        my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d",
            $ts[5] + 1900, $ts[4] + 1, @ts[ 3, 2, 1, 0 ];

        # Backup/delete all the existing templates.
        my $tmpl_iter = MT::Template->load_iter({
            blog_id => $blog_id,
            type    => { not => 'backup' },
        });
        while (my $tmpl = $tmpl_iter->()) {
            # Don't backup Widgets or Widget Sets if the user asked
            # that they be saved.
            my $skip = 0;
            # Because Widget Sets reference Widgets, we don't want to backup
            # widgets, either, because that will change their "type" and
            # therefore not be widgets anymore--potentially breaking the
            # Widget Set.
            if ( $app->param('save_widgetsets') 
                && ( ($tmpl->type eq 'widgetset') || ($tmpl->type eq 'widget') ) 
                && ( ($tmpl->linked_file ne '*') || !defined($tmpl->linked_file) )
            ) {
                $skip = 1;
            }
            if ( $app->param('save_widgets') 
                && ($tmpl->type eq 'widget') 
                && ( ($tmpl->linked_file ne '*') || !defined($tmpl->linked_file) )
            ) {
                $skip = 1;
            }
            if ($skip == 0) {
                # zap all template maps
                require MT::TemplateMap;
                MT::TemplateMap->remove({
                    template_id => $tmpl->id,
                });
                $tmpl->name( $tmpl->name
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
        }

        if ($blog_id) {
            # Create the default templates and mappings for the selected
            # set here, instead of below.
            $blog->create_default_templates( $template_set );

            if ($template_set) {
                $blog->template_set( $template_set );
                $blog->save;
                $app->run_callbacks( 'blog_template_set_change', { blog => $blog } );
            }

            next BLOG;
        }
        # Now that a new theme has been applied, we want to be sure the correct
        # thumbnail gets displayed on the Theme Dashboard, which means we should
        # delete the existing thumb (if there is one), so that it gets recreated
        # when the user visits the dashboard.
        my $thumb_path = File::Spec->catfile( 
            $app->config('StaticFilePath'), 'support', 'plugins', 'ThemeManager', 
                'theme_thumbs', $blog_id.'.jpg'
        );
        if (-e $thumb_path) {
            unlink $thumb_path;
        }
    }
    if (@blogs_not_refreshed) {
        # Failed!
        return 0;
    }
    
    
    # Success!
    return 1;
}

sub xfrm_disable_tmpl_link {
    # If templates are linked, we don't want users to be able to simply unlink
    # them, because that "breaks the seal" and lets them modify the template,
    # so upgrades are no longer easy. 
    my ($cb, $app, $tmpl) = @_;
    use MT::Template;
    my $linked = MT::Template->load(
                        { id          => $app->param('id'),
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
        # Now finally update the Theme Options template
        my $old = '<mt:setvarblock name="content_nav">';
        my $new = $old . '<div style="margin-bottom: 8px; border: 1px solid #ddd;"><a href="<mt:Var name="script_uri">?__mode=theme_dashboard&blog_id=<mt:Var name="blog_id">" title="Visit the Theme Dashboard"><img src="'.$dest_url.'" width="138" height="112" /></a></div>';
        $$tmpl =~ s/$old/$new/mgi;
    }
}

sub _theme_check {
    # We need to store templates in the DB so that we can do the
    # $app->listing thing to build the page.
    
    # Look through all the plugins and find the template sets.
    for my $sig ( keys %MT::Plugins ) {
        use ThemeManager::Util;
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
                $theme->ts_label( ThemeManager::Util::theme_label($set, $obj) );
                $theme->ts_desc(  ThemeManager::Util::theme_description($set, $obj) );
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

1;

__END__
