$(document).ready( function() {
    var active = $('#content-nav ul li.active a').attr('id');
    $('#' + active + '-content').show();

    $('h2#page-title span').html( $('#content-nav ul li.active a b').html() );

    $('#fieldsets input, #fieldsets select, #fieldsets textarea').change( function () {
        var changed = $(this).parent().parent().parent().attr('id');
        $('#content-nav ul li.'+changed).addClass('changed');
    });
    $('#content-nav ul li a').click( function() {
        var newactive = $(this).attr('id');
        $('#content-nav li.active').removeClass('active');
        $('#' + active + '-content').hide();
        $('#content-nav li.' + newactive).addClass('active');
        $('#' + newactive + '-content').show();
        if ( newactive == 'apply-theme-tab' ) {
            // Display only "Apply a new Theme" if the user clicks for the chooser
            $('h2#page-title').html( $('#content-nav ul li.'+newactive+' a b').html() );
        }
        else {
            // Display the theme name and the tab name for any other tab.
            $('h2#page-title').html( $('#theme-label').html() + ': ' + $('#content-nav ul li.'+newactive+' a b').html() );
        }
        active = newactive;
    });

    $('.field-type-radio-image li input:checked').each( function() {
        $(this).parent().addClass('selected');
    });
    $('.field-type-radio-image li').click( function() {
        $(this).parent().find('input:checked').attr('checked',false);
        $(this).find('input').attr('checked',true);
        $(this).parent().find('.selected').removeClass('selected');
        $(this).addClass('selected');
        var changed = $(this).parent().parent().parent().parent().attr('id');
        $('#content-nav ul li.'+changed).addClass('changed');
    });

  $('#templates-tab-content td.status a').click( function() {
    var id = $(this).parents('tr').find('.cb input').val();
    var link = $(this);
    link.css('background','url(<mt:Var name="static_uri">images/ani-rebuild.gif) no-repeat center -1px');
    $.ajax({
      url: '<mt:var name="script_url">?__mode=tm.rebuild_tmpl&amp;blog_id=<mt:var name="blog_id">&amp;id=' + id,
      dataType: 'json',
      error: function (xhr, status, error) {
        link.css('background','url(<mt:PluginStaticWebPath component="ThemeManager">images/icon-error.gif) no-repeat center -1px');
      },
      success: function (data, status, xhr) {
        if (data.success) {
          link.css('background','url(<mt:Var name="static_uri">images/nav-icon-rebuild.gif) no-repeat center 0px');
        } else {
          link.css('background','url(<mt:PluginStaticWebPath component="ThemeManager">images/icon-error.gif) no-repeat center -1px');
        }
      }
    });
  });


});
