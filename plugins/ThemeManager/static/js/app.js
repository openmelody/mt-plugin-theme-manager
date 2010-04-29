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
});
