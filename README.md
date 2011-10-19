# About the Theme Manager plugin for Movable Type and Melody

Theme Manager is a plugin for Movable Type and Melody created for designers
and users with an express goal of making it much easier to both build and use
themes on the Movable Type and Melody platforms.

## What Theme Manager Does for End Users

Theme Manager provides a much more intuitive administrative interface for end
users allowing them to more easily apply and customize a theme. Furthermore,
it virtually eliminates the need for end users to edit or worry about
templates.

An "upgrade" function allows a user to easily upgrade a blog to use the latest
features and capabilities in the newest release of a theme.

Need to refer to an old template for some reason? Template backups are
organized by date, making it easier to locate what you are looking for, as
well as letting you see how your templates have changed.

Using Theme Manager as an end user is known as "Production Mode."

## What Theme Manager Does for Designers

Designers can speed theme creation with the "Designer Mode." Designer Mode
makes template editing easier and allows for quick iteration by automatically
installing templates and custom fields as they are defined in the theme's
`config.yaml`.

When a theme is applied to a blog the user is presented with the ability to 
apply the theme in Production or Designer Mode.

### Eliminate Burdensome "Template Refreshing" and Use Your Preferred Text Editor

Designers who have built sites on Movable Type are all too familiar with the
workflow to see a simple change actually appear on a web site. It goes
something like this:

1. Edit template on file system.
2. Go into MT, refresh template to pull in changes.
3. Save and publish newly updated template.
4. Go to browser, refresh and see change.
5. Repeat.

Theme Manager streamlines this process by eliminating the need to refresh
templates, and by providing simple mechanisms inside of Melody and Movable
Type to quickly and efficiently republish templates, entries and pages. With
Theme Manager installed, when you edit a theme on the filesystem, the theme is
immediately updated in Movable Type. Then republishing that file is as simple
as clicking a rebuild icon next to the template or content you would like
refreshed.

### Quickly Iterate Through Bigger Theme Updates

In addition to speeding the theme development process with with linked
templates and your favorite text editor, Theme Manager's Designer Mode relies
upon your `config.yaml` to add new templates and create and update Custom
Fields and Field Day fields automatically. That's right, defining a template
in `config.yaml`, for example, is all that is required to deploy a new
template! No need to upgrade or re-apply a theme.

### Create Better Products

When a designer creates a theme with the intent to distribute it, it is
essential that the product they produce is not only easy to use, but also easy
to support. Themes should never have to include complex instructions in order
to allow end users to apply, setup, configure and tweak them. These actions
should be easy and obvious. Theme Manager makes that happen. Here's how:

* Theme Manager allows you provide thumbnails for your theme so that users
  can preview the theme more easily from directly within Movable Type.

* Theme Manager allows end users to donate money to you via PayPal. Just
  provide your PayPal email address and a donate appears automatically.

* Theme Manager greatly expands upon the options made available to them in 
  a theme's config file (e.g. `config.yaml`). Designers can specify caching
  options, default content to be created (folders, categories, entries, 
  pages), and much more.

* Theme Manager integrates seamlessly with Config Assistant to provide a 
  simple way for users to access a theme's options. These options allow a
  designer to constrain the ways in which a theme can be customized and 
  virtually eliminates the need for users to edit templates. 

## Don't Let Theme Upgrades Break Your Web Site

Upgrading a theme should be something every user should not only be able to
do, but something they feel comfortable and safe in doing. Adding new features
to a blog through templates, for example, requires iterative testing that can
result in a broken site. Themes and Theme Manager provide varied functionality
to make testing, deploying, and upgrades an easier process.

When creating a new theme or testing proposed changes you can work with a
theme in Developer Mode (such as on a non-public development server or in a
separate test blog within your Melody or Movable Type installation). In
developer mode, a theme in the CMS is linked directly to the theme's template
source files on the file system. When the theme changes on the file system, it
changes in the CMS. This helps make iterating through changes to your web site
much faster and more enjoyable. Adding new templates in Designer mode is
also easier: just define the template in `config.yaml` -- the template will be
automatically added with the template definition you create. Similarly, Custom
Fields and Field Day fields are automatically added (and updated) based on the
contents of your `config.yaml` file.

When a theme is in Production Mode it is stable. Templates are not linked to
their filesystem counterparts and are not automatically updated. Custom Fields
and Field Day fields are similarly not automatically updated. When a new
version of a theme is available, it's new features can be deployed by using
Theme Manager's theme upgrade capability, helping you to understand exactly
what will be affected by the upgrade and what to expect. Just look for the
Upgrade button on the Theme Dashboard. The result: a smooth upgrade to a
theme's new capabilities without unexpected downtime.


# Prerequisites

* Movable Type 4.1 or higher 
* Config Assistant 1.8 or higher

Theme Manager is a core component to Melody, as is Config Assistant.


# Installation

As a core component of Melody, Theme Manager is automatically installed in the
`addons` folder when Melody is installed.

Prior to version 0.9.36, Theme Manager was installed in the `plugins` folder
of Movable Type. As of v0.9.36, it should be installed in the `addons` folder
and any copy of Theme Manager in the `plugins` folder should be removed. For
more on the plugin installation process, see the [Easy Plugin Installation
Guide](https://github.com/openmelody/melody/wiki/install-EasyPluginInstallGuide).
Again, the one variation from the Easy Plugin Installation Guide's
instructions is that the Theme Manager plugin should now be installed in the
`addons` folder.


# Reference and Documentation

A user can visit the Design menu and choose Theme Dashboard to interact with
their current theme or apply a new theme. The Theme Dashboard is populated
with information about the current theme and links to work with the theme, all
of which can be specified by the theme designer.

Apply a new theme by visiting the Theme Dashboard and clicking the "Change
Theme" link to get started. A thumbnail view of the installed themes appears.
Here the user can see more detail about the theme (click the thumbnail) and
select a theme to apply. After selecting a theme the user will be required to
fill-in any fields marked "required" by the theme designer to finish the
process.

(Need to apply a theme to many blogs? Visit System Overview > Blogs and use 
the Apply Theme list action.)

Keep reading for details on creating a theme that takes full advantage of all 
that Theme Manager offers!

## Production Mode or Designer Mode?

When applying a new theme to a blog one of the options presented is the choice
of deploying in Production Mode or Designer Mode.

Production Mode is aimed at running a live site. It is most analogous to how
Movable Type runs out-of-the-box.

Designer Mode is aimed at speeding development of a theme. Designer Mode has a
short list of additional capabilities, but their value is high:

* Linking the installed template and the source file, making it easy to use
  your preferred text editor to build a template.

* Automate "theme upgrades" based on the content of `config.yaml`.

Switching from Production Mode to Designer Mode is easy and can be done at any
time: simply go to the Design > Theme Dashboard menu item, then select the
Customization tab. There you can see the current Mode and switch.

## Designers: Specifying Your Theme's Details

First, you'll need to build a theme. A theme is a combination of images,
Javascript, CSS, and templates -- all of which are packaged into a plugin and
organized by a `config.yaml` file. Theme Manager adds several keys to the
`config.yaml` of your theme to help you populate the Theme Dashboard.

Tip: use Config Assistant to add user-fillable fields to your theme, as well
as for the static file copy feature, negating the need to include an
`mt-static` folder with your theme distribution!

Tip: be sure to increment your theme's version number after making changes.
Keeping a "version history" makes it easy to know when a new feature was
added, for example. Incrementing the version number is also how Theme Manager
knows how to provide users with a button to upgrade the theme.

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
* `version` - The version number of your theme. If unspecified, this falls
  back to the plugin's `version` value, if specified.
* `paypal_email` - A valid email address that users can donate through PayPal
  to you. If unspecified, this falls back to the root key `paypal_email`
  value.
* `about_designer` - A description of you! If unspecified, this falls back
  to the plugin's `about_designer` value, if specified.

Notice that each value has a fallback value that is defined by your plugin.
The real benefit of this is that you can have multiple template sets in your
theme. Each template set may have its own `version` and `description`, but may
fall back to the plugin-level `doc_link` for both themes, for example. See
their use in the example below.

The `description`, `documentation` and `about_designer` keys are special, in 
that you can supply text to them in a variety of ways. This gives you the 
opportunity to include simple or complex HTML along with inline CSS. Examples:

* Inline, formatted as HTML:

        description: "<p>This is my great theme!</p>"
        documentation: "<p>How to use this theme.</p>"
        about_designer: "<p>I am the bestest designer <em>evar</em>!</p>"

* As a file reference, which contains HTML. The file you specify should be
  placed in your plugin's envelope, or in a folder named `tmpl` within your
  plugin's envelope.

        description: description.html
        documentation: documentation.html
        about_designer: about.html

Additionally, the Theme Chooser will display images to help the user select a 
theme.

* `thumbnail` - a thumbnail image of your theme, measuring 175 x 140 pixels.
  This image is displayed in the Theme Chooser selection grid. A generic theme
  image will be displayed if none is supplied.
* `preview` - a larger thumbnail image of your theme, measuring 300 x 240
  pixels. This image is displayed in the "details" of the Theme Chooser. A
  generic theme image will be displayed if none is supplied.
* Any option marked with the `required: 1` key:value pair will be displayed
  after the user has selected a theme.

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

## Designers: Specify Your Theme's Templates

The heart of your theme is the templates, of course. Theme Manager will look
for a `templates` key and install any templates specified there in the
familiar YAML syntax. In the following example, an index template and template
module are added to our example theme.

    template_sets:
        my_awesome_theme:
            label: 'My Awesome Theme'
            templates:
                index:
                    main_index:
                        label: 'Main Index'
                        outfile: index.html
                module:
                    entry_summary:
                        label: 'Entry Summary'

In addition to Index Templates and Template Modules, other template types can
be specified here as well, following this same format. Examples:

    template_sets:
        my_awesome_theme:
            label: 'My Awesome Theme'
            templates:
                archive:
                    category_entry_listing:
                        label: 'Category Entry Listing'
                        mappings:
                            category:
                                archive_type: Category
                                preferred: 1
                    monthly_entry_listing:
                        label: 'Monthly Entry Listing'
                        mappings:
                            monthly:
                                archive_type: Monthly
                                file_template: '%y/%m/%i'
                                preferred: 1
                individual:
                    entry:
                        label: 'Entry'
                        mappings:
                            individual:
                                archive_type: Individual
                                file_template: '%-c/%-b/%i'
                                preferred: 1
                page:
                    page:
                        label: 'Page'
                        mappings:
                            page:
                                archive_type: Page
                                preferred: 1
                email:
                    entry-notify:
                        label: 'Entry Notify'
                system:
                    comment_preview:
                        label: 'Comment Preview'

Note that if you are developing your theme in Designer Mode, simply adding the
template definition to `config.yaml` is enough for Theme Manager to install
your template. Just refresh in Melody or Movable Type and you will see your
template listed and ready to use.

### Additional Template Settings

Theme Manager allows you to specify some additional keys for templates: 
providing the ability to specify the publishing type, caching preferences for 
modules, and better handling of custom fields. Refer to the example YAML below 
to use these keys.

#### Efficient Publishing

`build_type` - the build type (or publishing method) can be specified for both
index and archive templates. Specifying the `build_type` of templates is a
great way to control what is republished when; look at the Publishing Profiles
(in Design > Templates) for inspiration about the benefits of specifying this
option for each template. Acceptable values for the `build_type` parameter can
be provided in one of two formats, a numeric representation or a string-based
reputation (beginning in version 0.10.20 of Theme Manager), according to the
table below:

<table>
<tr><th>Numeric</th><th>String</th><th>Description</th></tr>
<tr><td>0</td><td>disabled</td><td>Disabled, do not publish.</td></tr>
<tr><td>1</td><td>static</td><td>Publish statically on demand.</td></tr>
<tr><td>2</td><td>manual</td><td>Publish manually, or only when specifically requested by an administrator.</td></tr>
<tr><td>3</td><td>dynamic</td><td>Publish dynamically in real time. Do not publish to the filesystem.</td></tr>
<tr><td>4</td><td>async</td><td>Publish in the background using the run-periodic-tasks script.</td></tr>
</table>

#### Set Caching and Include Options

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
UI, this option corresponds to the "Process as [SSI method] include" option 
found when editing Template Modules and Widgets.

Server Side Includes must be enabled at the blog level (enable this in 
Preferences > Publishing). A great way to enable this feature automatically
is to use the AutoPrefs plugin.

#### Localized Template Support

An advanced feature that Theme Manager supports is installing localized 
templates. Localized templates (that is, templates translated to another 
language) need to be defined within your plugin. You'll need to specify an 
`l10n_class` and the accompanying translations in your plugin.

Note that Production Mode *must* be used to deploy your theme with 
localization support. Templates are translated when they are installed. 

Note also that Designer Mode loses the ability to link templates if your 
theme is built with localization support. Again, templates are translated 
when they are installed. If a template is linked, when re-synced to the 
source template on the filesystem it will be overwritten with the 
translated template.

#### Example of Additional Template Settings

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


## Designers: Create Custom Fields

Many sites require the use of the Movable Type Commercial Pack's Custom Fields
(part of MT Pro). If fields are specified in your theme's `config.yaml` they
can be automatically created when you deploy your theme. Fields can also be
"refreshed" from the Theme Dashboard's Customization tab. If you are creating
or updating your theme by running in Designer Mode, simply defining the Custom
Field definition is enough for Melody and Movable Type to install it; no need
to "refresh" from the Theme Dashboard's Customization tab!

The following example shows how to add a text custom field for Entries to the
theme we're building.

    template_sets:
        my_awesome_theme:
            label: 'My Awesome Theme'
            fields:
                entry_extra_text_field:
                    label: 'Extra Text Field'
                    description: 'This is a text custom field.'
                    default: 'Replace this default text with any value.'
                    required: 1
                    obj_type: entry
                    type: text
                    tag: EntryExtraTextField

Custom Field definitions appear beneath the key `fields`.

The key `entry_extra_text_field` is the basename of this field.

The `description`, `required` and `default` keys are optional.

The key `obj_type` is the type of object this field targets; `entry`, `page`,
`category`, `folder`, and `author` are valid. These correlate to the System
Object field in the GUI, of course.

The key `type` is the type of field to be created. Note that this is the key
name of the field, not the public-facing name you see in the GUI. The
Commercial Pack defines the following types of fields with these keys:

* Text: `text`
* Multi-Line Text: `textarea`
* Checkbox: `checkbox`
* URL: `url`
* Date and Time: `datetime`
* Drop Down Menu: `select`
* Radio Buttons: `radio`
* Embed Object: `embed`
* Post Type: `post_type`
* Asset: `asset`
* Audio: `asset.audio`
* Image: `asset.image`
* Video: `asset.video`

If you have other custom fields available they may also be specified in your
theme's `config.yaml`; you just need to specify the key correctly.

To create a system-level custom field (necessary is you use the `author`
object type), include the `scope` key:

    template_sets:
        my_awesome_theme:
            label: 'My Awesome Theme'
            fields:
                author_bio:
                    label: 'Author Bio'
                    obj_type: author
                    type: textarea
                    tag: AuthorBio
                    scope: system

## Designers: Create Field Day Fields

Another tool for creating additional fields is [Field
Day](https://github.com/movabletype/mt-plugin-field-day). As with the
Commercial Pack's Custom Fields, Field Day fields can be specified in your
theme's `config.yaml` and will be automatically created when you deploy your
theme. Fields can also be "refreshed" from the Theme Dashboard's Customization
tab. If you are creating or updating your theme by running in Designer Mode,
simply defining the Field Day field definition is enough for Melody and
Movable Type to install it; no need to "refresh" from the Theme Dashboard's
Customization tab!

Field Day field definitions are sufficiently complex and varied that writing 
YAML from scratch for them is likely to be a very frustrating exercise. A much 
easier approach is to create the fields within the Field Day interface, then 
use the [Theme Exporter](https://github.com/openmelody/mt-plugin-theme-export) 
plugin to generate the YAML for you, which can then be copy-pasted into your 
theme.

Field Day fields are defined differently from Custom Fields, and the YAML 
mirrors that difference. The following example shows how to add a textarea 
Field Day field for Entries to the theme we're building.

    template_sets:
        my_awesome_theme:
            label: 'My Awesome Theme'
            fd_fields:
                entry_extra_text_field:
                    obj_type: entry
                    type: field
                    order: 1
                    data:
                        label: 'Extra Text Field'
                        type: TextArea
                        group: 0
                        options:
                            width: 400
                            label_display: left

Field Day field definitions appear beneath the `fd_fields` key.

The key `entry_extra_text_field` is the basename of this field. Within the
Field Day interface, this field is referred to as the "Field."

The key `obj_type` is the type of object this field targets Valid object
types:

* `asset`
* `blog`
* `category`
* `comment`
* `entry`
* `folder`
* `page`
* `system`
* `template`
* `user`

The key `type` refers to whether you're creating a `field` or a `group`. The
key `order` determines the order that fields are displayed in on the editing
screen.

Beneath the `data` key you'll find four keys. The `label` key is the
user-facing name for this field.

Use the `type` field to define the type of field to be created. Valid field
types are:

* `Checkbox`
* `ChoiceList`
* `Date`
* `File`
* `LinkedAsset`
* `LinkedBlog`
* `LinkedCategory`
* `LinkedEntry`
* `LinkedFolder`
* `LinkedPage`
* `LinkedTemplate`
* `LinkedUser`
* `RadioButtons`
* `SelectMenu`
* `StarRating`
* `Text`
* `TextArea`

The `group` key refers to a Group ID to determine what Group a field belongs
to. `0` means the field does not belong to a Group. Theme Manager currently
does not support setting the Group through `config.yaml`.

A lot of metadata is defined beneath the `options` key. The contents of this
key vary *significantly* for each field type. For each field type you're
using, the easiest approach is to create the field in the Field Day interface
then use Theme Exporter to generate the YAML for you. Fields are also
recreated below in Field Day Field Examples as reference.

### Field Day Field Examples

Each Field Day `type` is shown below for reference. Because of the variety and
complexity in defining a Field Day field, the recommended approach is to
create the field in the Field Day interface then use Theme EXporter to
generate the YAML for you.

In the examples shown here, note that any key with the value `~` is undefined.
That is, in YAML you may specify an undefined value with `~`.

#### Checkbox

    checkbox:
      data:
        group: 0
        label: Checkbox
        options:
          label_display: left
          read_only: ~
        type: Checkbox
      obj_type: entry
      order: 1
      type: field

#### Date

    date:
      data:
        group: 0
        label: Date
        options:
          ampm: on
          ampm_default: pm
          date_order: mdy
          default_year: on
          label_display: left
          minutes: 5
          read_only: ~
          show_hms: ~
          text_entry: on
          time: hhmm
          y_end: 2010
          y_start: 2008
        type: Date
      obj_type: entry
      order: 2
      type: field

#### File

    file:
      data:
        group: 0
        label: File
        options:
          filenames: dirify
          label_display: left
          overwrite: ~
          read_only: ~
          upload_path: ''
          url_path: ''
        type: File
      obj_type: entry
      order: 3
      type: field

#### Linked Asset

    linked_asset:
      data:
        group: 0
        label: 'Linked Asset'
        options:
          allow_create: on
          asset_type: ''
          autocomplete: on
          autocomplete_fields: ~
          create_fields: ''
          label_display: left
          linked_blog_id: ''
          overwrite: ~
          read_only: ~
          required_fields: ~
          show_autocomplete_values: ~
          unique_fields: ~
          upload_path: ''
          upload_path_relative: on
          url_path: ''
          url_path_relative: on
        type: LinkedAsset
      obj_type: entry
      order: 4
      type: field

#### Linked Blog

    linked_blog:
      data:
        group: 0
        label: 'Linked Blog'
        options:
          allow_create: ~
          autocomplete: on
          autocomplete_fields: ''
          create_fields: ~
          label_display: left
          limit_fields: ''
          read_only: ~
          required_fields: ~
          show_autocomplete_values: ~
          unique_fields: ~
        type: LinkedBlog
      obj_type: entry
      order: 5
      type: field

#### Linked Category

    linked_category:
      data:
        group: 0
        label: 'Linked Category'
        options:
          category_ids: ''
          label_display: left
          linked_blog_id: ''
          read_only: ~
          subcats: ~
        type: LinkedCategory
      obj_type: entry
      order: 6
      type: field

#### Linked Entry

    linked_entry:
      data:
        group: 0
        label: 'Linked Entry'
        options:
          allow_create: on
          autocomplete: on
          autocomplete_fields: ''
          category_ids: ''
          create_fields: ''
          label_display: left
          lastn: ''
          linked_blog_id: ''
          published: on
          read_only: ~
          required_fields: ''
          search: ~
          show_autocomplete_values: ~
          subcats: ~
          unique_fields: ''
        type: LinkedEntry
      obj_type: entry
      order: 7
      type: field

#### Linked Folder

    linked_folder:
      data:
        group: 0
        label: 'Linked Folder'
        options:
          category_ids: ''
          label_display: left
          linked_blog_id: ''
          read_only: ~
          subcats: ~
        type: LinkedFolder
      obj_type: entry
      order: 8
      type: field

#### Linked Page

    linked_page:
      data:
        group: 0
        label: 'Linked Page'
        options:
          allow_create: on
          autocomplete: on
          autocomplete_fields: ''
          category_ids: ''
          create_fields: ''
          label_display: left
          lastn: ''
          linked_blog_id: ''
          published: on
          read_only: ~
          required_fields: ''
          search: ~
          show_autocomplete_values: ~
          subcats: ~
          unique_fields: ''
        type: LinkedPage
      obj_type: entry
      order: 9
      type: field

#### Linked Template

    linked_template:
      data:
        group: 0
        label: 'Linked Template'
        options:
          label_display: left
          linked_blog_id: ''
          read_only: ~
        type: LinkedTemplate
      obj_type: entry
      order: 10
      type: field

#### Linked User

    linked_user:
      data:
        group: 0
        label: 'Linked User'
        options:
          active: on
          allow_create: ~
          autocomplete: on
          autocomplete_fields: ''
          create_fields: ~
          label_display: left
          read_only: ~
          required_fields: ~
          show_autocomplete_values: ~
          unique_fields: ~
        type: LinkedUser
      obj_type: entry
      order: 11
      type: field

#### Radio Buttons

    radio_buttons:
      data:
        group: 0
        label: 'Radio Buttons'
        options:
          choices: ''
          label_display: left
          read_only: ~
        type: RadioButtons
      obj_type: entry
      order: 12
      type: field

#### Select Menu

    select_menu:
      data:
        group: 0
        label: 'Select Menu'
        options:
          choices: ''
          label_display: left
          read_only: ~
        type: SelectMenu
      obj_type: entry
      order: 13
      type: field

#### Star Rating

    star_rating:
      data:
        group: 0
        label: 'Star Rating'
        options:
          average_field: ''
          average_object_type: ''
          half_url: ''
          is_average: ~
          label_display: left
          off_url: ''
          on_url: ''
          read_only: ~
          stars: 5
        type: StarRating
      obj_type: entry
      order: 14
      type: field

#### Text (single-line)

    text:
      data:
        group: 0
        label: Text
        options:
          label_display: left
          length: ''
          read_only: ~
          width: 400
        type: Text
      obj_type: entry
      order: 15
      type: field

#### Text Area

    text_area:
      data:
        group: 0
        label: 'Text Area'
        options:
          height: 200
          label_display: left
          read_only: ~
          width: ''
        type: TextArea
      obj_type: entry
      order: 16
      type: field


## Designers: Specifying Default Content

Theme Manager allows you to preload a new web site using a theme with default
content. This is very useful when a theme requires a certain set of folders,
categories, pages and/or entries to be in place to function properly. It is
also extremely helpful in providing a better "out-of-the-box" end user
experience. That way when a user installs and applies a theme, and then views
their web site for the first time there will be content there, as opposed to a
big empty screen.

To specify default content, utilize the `content` property in your theme's
config.yaml structure. Here is an example config.yaml file that specifies
three default categories, a default folder, a default entry, and an about
page. Also notice that a folder is being associated with the page.

    template_sets:
        my_awesome_theme:
            base_path: templates/blog
            label: 'My Awesome Theme'
            thumbnail: thumb.png
            preview: preview.png
            description: 'This theme is awesome.'
            content:
                categories:
                    announcements:
                        label: 'Announcements'
                    events:
                        label: 'Events'
                    news:
                        label: 'News'
                folders:
                    our_company:
                        label: 'Our Company'
                entries:
                    welcome:
                        label: 'Welcome to my awesome theme'
                        body: 'You just installed a great theme. Congrats!'
                pages:
                    about:
                        label: 'About'
                        folder: our_company

Note that Default Content is installed only when the theme is applied to a
blog. Default Content is not re-installed when a theme upgrade is performed.

### Nested Categories and Folders

You can easily build category and folder hierarchies with multiple
levels like so:

    content:
        folders:
            about:
                label: 'About'
                folders:
                    jobs:
                        label: "We're Hiring"
                    execs:
                        label: "Executive Team"
                        folders:
                            ceo:
                                label: "About our CEO"
                            advisors:
                                label: "Our Advisors"

*Categories are done in an identical fashion except instead of using the
key "folders" you would use "categories".*

### Entries, Pages, and Tags

You can specify default pages and entries, along with their vital meta data
via Theme Manager as well. For example, the following will define an entry
called "Press Kits" which will have two tags: `@nav` and `press`:

    content:
      entries:
        press_kits:
          label: 'Press Kits'
          tags: 
            - '@nav'
            - 'press'

# Acknowledgements

This plugin was commissioned by Endevver from Dan Wolfgang of
[uiNNOVATIONS](http://uinnovations.com/). Endevver is proud to be partners
with uiNNOVATIONS.

# License

This plugin is licensed under the same terms as Perl itself.

# Copyright

Copyright 2010, Endevver LLC. All rights reserved.
