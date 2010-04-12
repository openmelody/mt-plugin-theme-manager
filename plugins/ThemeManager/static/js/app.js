$(document).ready( function() {
    var url = document.location.href;
    if ( url.match('offset') ) {
        // The user is turning pages on the theme display. We want to display
        // the Apply a Theme tab by default, so they can pick up where they
        // left off.
        $('#content-nav li.active').removeClass('active');
        $('#content-nav li.apply-theme-tab').addClass('active');
    }

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
        $('h2#page-title span').html( $('#content-nav ul li.'+newactive+' a b').html() );
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
});
