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
        link.css('background','url('+StaticURI+'images/ani-rebuild.gif) no-repeat center -1px');
        var url = ScriptURI + '?__mode=tm.rebuild_tmpl&amp;blog_id='+BlogID+'&amp;id=' + id; 
        $.ajax({
            url: url,
            dataType: 'json',
            error: function (xhr, status, error) {
                link.css('background','url('+PluginStaticURI+'images/icon-error.gif) no-repeat center -1px');
            },
            success: function (data, status, xhr) {
                if (data.success) {
                    link.css('background','url('+StaticURI+'images/nav-icon-rebuild.gif) no-repeat center 0px');
                    link.qtip('destroy');
                } else {
                    link.css('background','url('+PluginStaticURI+'images/icon-error.gif) no-repeat center -1px');
                    link.qtip({
                        content: data.errstr,
                        position: {
                            corner: {
                                tooltip: 'topRight',
                                target: 'bottomLeft'
                            }
                        },
                        show: {
                            solo: true
                        },
                        style: {
                            border: {
                                width: 3,
                                radius: 5
                            },
                            padding: 6, 
                            tip: true, // Give it a speech bubble tip with automatic corner detection
                            name: 'cream' // Style it according to the preset 'cream' style
                        }
                    });
                }
            }
        });
    });
    if ( $('#content-nav ul li a').length > 0) {
        var myFile = document.location.toString();
        if (myFile.match('#')) { // the URL contains an anchor
            // click the navigation item corresponding to the anchor
            var myAnchor = myFile.split('#')[1];
            var sel = "#content-nav ul li."+myAnchor+" a";
            $(sel).click();
        }
    };
});
