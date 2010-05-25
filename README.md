# About the Theme Manager plugin for Movable Type and Melody

The Theme Manager plugin has two components:

* A Theme Chooser to help users install and set up a theme, provides theme 
  designers with ways to communicate their theme capabilities and requirements, 
  and makes upgrading themes easier.
* A Theme Dashboard for at-a-glance detail of the theme being used and links 
  to work with the installed theme.

# Prerequisites

* Movable Type 4.1 or higher
* Config Assistant 1.8 or higher

# Installation

This plugin is installed [just like any other Movable Type Plugin](http://www.majordojo.com/2008/12/the-ultimate-guide-to-installing-movable-type-plugins.php).

# Reference and Documentation

A user can visit the Design menu and choose Theme Dashboard to interact with 
their current theme or apply a new theme. The Theme Dashboard is populated with 
information about the current theme and links to work with the theme, all of 
which can be specified by the theme designer.

Apply a new theme by visiting the Theme Dashboard and clicking the "Apply a 
New Theme" link to get started. A paginated view of the installed themes 
appears. Here the user can see more detail about the theme (click the 
thumbnail) and select a theme to apply. After selecting a theme the user 
will be required to fill-in any fields marked "required" by the theme 
designer to finish the process.

(Need to apply a theme to many blogs? Visit System Overview > Blogs and use 
the Apply Theme list action.)

Keep reading for details on creating a theme that takes full advantage of all 
that Theme Manager offers!

## Designers: Specifying Your Theme's Details

First, you'll need to build a theme. A theme is a combination of images, 
Javascript, CSS, and templates -- all of which are packaged into a plugin and 
organized by a `config.yaml` file. Theme Manager adds several keys to the 
`config.yaml` of your theme to  help you populate the Theme Dashboard.

Tip: use Config Assistant to add user-fillable fields to your theme, as well 
as for the static file copy feature, negating the need to include an 
`mt-static` folder with your theme distribution!

The following keys are available:

* `author_name` - Your name. If unspecified, this falls back to the plugin's
  `author_name` value, if specified.
* `author_link` - The URL to your web site. If unspecified, this falls back to 
  the plugin's `author_link` value, if specified.
* `theme_link` - The URL to your theme. If unspecified, this falls back to the
  plugin's `plugin_link` value, if specified.
* `doc_link` - The URL to the documentation of your theme. If unspecified,
  this falls back to the plugin's `doc_link` value, if specified.
* `documentation` - Yes, the `documentation` key is different from the 
  `doc_link` key. Use this key to supply documentation right in your theme. A
  "Documentation" tab will appear on the Theme Dashboard where your 
  documentation is displayed.
* `description` - A description of your theme. If unspecified, this falls back
  to the plugin's `description` value, if specified.
* `version` - The version number of your theme. If unspecified, this falls back
  to the plugin's `version` value, if specified.
* `paypal_email` - A valid email address that users can donate through PayPal
  to you. If unspecified, this falls back to the root key `paypal_email` value.
* `about_designer` - A description of you! If unspecified, this falls back
    to the plugin's `about_designer` value, if specified.

Notice that each value has a fallback value that is defined by your plugin. The
real benefit of this is that you can have multiple template sets in your theme.
Each template set may have its own `version` and `description`, but may fall 
back to the plugin-level `doc_link` for both themes, for example. See their use
in the example below.

The `description`, `documentation` and `about_designer` keys are special, in 
that you can supply text to them in a variety of ways. This gives you the 
opportunity to include simple or complex HTML along with inline CSS. Examples:

* Inline, formatted as HTML:

    `description: "<p>This is my great theme!</p>"
    documentation: "<p>How to use this theme.</p>"
    about_designer: "<p>I am the bestest designer <em>evar</em>!</p>"`

* As a file reference, which contains HTML. The file you specify should be
  placed in your plugin's envelope, or in a folder named `tmpl` within your
  plugin's envelope.

    `description: description.html
    documentation: documentation.html
    about_designer: about.html`

Additionally, the Theme Chooser will display images to help the user select a 
theme.

* `thumbnail` - a thumbnail image of your theme, measuring 175 x 140 pixels. This 
  image is displayed in the Theme Chooser selection grid. A generic theme image 
  will be displayed if none is supplied.
* `preview` - a larger thumbnail image of your theme, measuring 300 x 240 pixels.
  This image is displayed in the "details" of the Theme Chooser. A generic theme 
  image will be displayed if none is supplied.
* Any option marked with the `required: 1` key:value pair will be displayed after
  the user has selected a theme.

In the below `config.yaml` example, notice that within the template set ID 
(`my_awesome_theme`), the above keys are used. Also note the `options` and 
`posts_for_frontdoor` keys -- these are additions that are recognized by 
Config Assistant. Notice that the last key is `required: 1`: that marks this 
field as "required" for this theme. When a user selects this theme with the 
Theme Chooser, they will need to populate this field in order to complete the 
theme installation.


    name: Awesomeness
    version: 1.0
    template_sets:
        my_awesome_theme:
            base_path: 'templates'
            label: 'My Awesome Theme'
            author_name: 'Mr Designer, Jr'
            author_link: 'http://example.com'
            theme_link: 'http://example.com/my_awesome_theme/'
            doc_link: 'http://example.com/my_awesome_theme/docs/'
            description: "<p>This is my awesome theme! It's full of colors and nifty features and <em>so much awesome</em>!</p>"
            version: '1.0'
            paypal_email: donate@example.com
            thumbnail: awesome-theme-small.png
            preview: awesome-theme-large.png
            about_designer: about.html
            options:
                fieldsets:
                    homepage:
                        label: 'Homepage Options'
                posts_for_frontfoor:
                    type: text
                    label: "Entries on Frontdoor"
                    hint: 'The number of entries to show on the front door.'
                    tag: 'FrontdoorEntryCount'
                    fieldset: homepage
                    condition: > 
                      sub { return 1; }
                    required: 1


The Theme Dashboard can display links to customize the current theme, if the 
theme has been created with such flexibility:

* A link to "Edit Theme Options" will appear if any `options` recognized by 
  Config Assistant are found in the `config.yaml`
* A link to "Create Widgets and edit Widget Sets" will appear if the 
  `widgetset` key is found in the `config.yaml`
* A link to "Customize Stylesheet" will appear if the Custom CSS plugin is 
  installed and enabled for the current theme.

Additional options can be added to the customize section of the Theme 
Dashboard, too, by specifying the additions as Page Actions targeted to the 
`theme_dashboard`
([Page Actions documentation](http://www.movabletype.org/documentation/developer/apps/page-actions.html)). 
Of course, the code, mode or dialog being added needs to be created, but 
that's beyond the scope of this document.

## Designers: Additional Template Settings

Theme Manager allows you to specify some additional keys for templates: 
providing the ability to specify the publishing type, caching preferences for 
modules, and better handling of custom fields. Refer to the example YAML below 
to use these keys.

* `build_type` - the build type (or publishing method) can be specified 
  for both index and archive templates. Specifying the `build_type` of 
  templates is a great way to control what is republished when; look at the 
  Publishing Profiles (in Design > Templates) for inspiration about the 
  benefits of specifying this option for each template. Numerals 0-4 are valid 
  `build_type` values, corresponding to the options listed below:
    * 0: Do Not Publish
    * 1: Static (the default method)
    * 2: Manually
    * 3: Dynamically
    * 4: Publish Queue

Caching options can also be specified for Template Modules and Widgets with 
the following keys (if you've used the UI to set caching, these options should 
all be familiar). Module Caching must be enabled at the blog level (check this 
in Preferences > Publishing).

* `cache` - the parent key to the below options
* `expire_type` - 
    * 0: No caching (the default method)
    * 1: time-based expiration ("Expire after *x* minutes")
    * 2: event-based expiration ("Expire upon creation or modification of 
      object")
* `expire_interval` - This key is used only if `expire_type: 1` is used. 
  Specify a time to expire in minutes.
* `expire_event` - This key is used only if `expire_type: 2` is used. Specify
  a valid object to cause expiration. Valid objects are as follows:
    * asset
    * author
    * category
    * comment
    * entry
    * folder
    * page
    * tbping

Another import aspect to caching is using "includes." The key 
`include_with_ssi` allows the specified module or widget to be included as an 
external file, saving server resources and making it easy to keep content 
updated site-wide. Possible values are `1` and `0` (the default). Within the 
UI, this option corresponds to the "Process as [SSI method] include." Server 
Side Includes must be enabled at the blog level (check this in Preferences > 
Publishing).

An advanced feature that Theme Manager supports installing localized templates. 
Localized templates (that is, templates translated to another language) need to 
be defined within your plugin. You'll need to specify an `l10n_class` and the 
accompanying translations in your plugin.

    name: Awesomeness
    version: 1.0
    l10n_class: 'Awesomeness::L10N'
    template_sets:
        my_awesome_theme:
            base_path: 'templates'
            label: 'My Awesome Theme'
            languages:
                - en-us
                - fr
                - es
            templates:
                index:
                    main_index:
                        main_index:
                            label: 'Main Index'
                            outfile: index.html
                            rebuild_me: 1
                            build_type: 1
                archive:
                    category_archive:
                        label: 'Category Archive'
                        mappings:
                            category:
                                archive_type: Category
                                file_template: %c/%f
                                preferred: 1
                                build_type: 4
                module:
                    recent_entries:
                        label: 'Recent Entries'
                        cache:
                            expire_type: 2
                            expire_event: entry
                widget:
                    awesomeness_factor:
                        label: 'My Awesomeness Factor'
                        cache:
                            expire_type: 1
                            expire_interval: 30
                            include_with_ssi: 1

# Acknowledgements

This plugin was commissioned by Endevver to Dan Wolfgang of uiNNOVATIONS. Endevver is proud to be partners with uiNNOVATIONS.
http://uinnovations.com/

# License

This plugin is licensed under the same terms as Perl itself.

#Copyright

Copyright 2010, Endevver LLC. All rights reserved.
