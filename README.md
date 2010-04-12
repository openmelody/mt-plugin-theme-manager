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
New Theme" link to get started. A dialog will popup with a paginated view of 
the installed themes. Here the user can see more detail about the theme 
(click the thumbnail) or select a theme to apply. After selecting a theme the 
user will be required to fill-in any fields marked "required" by the theme 
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

Both the `description` and `about_designer` keys are special, in that you can 
supply text to them in a variety of ways. This gives you the opportunity to 
include simple or complex HTML along with inline CSS. Examples:

* Inline, formatted as HTML:

    `description: "<p>This is my great theme!</p>"
    about_designer: "<p>I am the bestest designer <em>evar</em>!</p>"`

* As a file reference, which contains HTML. The file you specify should be
  placed in your plugin's envelope, or in a folder named `tmpl` within your
  plugin's envelope.

    `description: description.html
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

# Acknowledgements

This plugin was commissioned by Endevver to Dan Wolfgang of uiNNOVATIONS. Endevver is proud to be partners with uiNNOVATIONS.
http://uinnovations.com/

# License

This plugin is licensed under the same terms as Perl itself.

#Copyright

Copyright 2010, Endevver LLC. All rights reserved.
