/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/*
 * This is the _NEW_ photo album module for pike.
 * I didn't like the way that the original one worked so I thought I would
 * re-write it.
 *
 * Original author : James Tyson <james@samizdat.co.nz>
 *
 */

/* Standard includes */

#include <module.h>
inherit "module";
inherit "caudiumlib";

/* Custom includes */

constant cvs_version = "$Id$";
constant thread_safe=1;

mapping albums = ([ ]);

array register_module() {
    return
	({ MODULE_PARSER,
	"Caudium Photo Album Module",
	"This is a new photo album module for Caudium.<br>\n" +
	"It automagically generates photo albums based on a directory of\n" +
	"image files.<br>\n" +
        "The syntax is easy to use, and can be embedded in any HTML page.<blockquote>\n" +
	html_encode_string( "<album name=\"My Photo Album\" dir=\"myphotos/\">\n" ) +
	"</blockquote>\n" +
	"The <i>name</i> argument sets the photo album name to be displayed,\n" +
	"if not specified it uses the default value set in the config interface.<br>\n" +
	"The <i>dir</i> argument points to a directory within the virtual filesystem\n" +
	"where a bunch of images are stored.\n" +
	"for every image (say <i>myphoto.jpg</i>) there optionally can be a\n" +
	"file called <i>myphoto.jpg.desc</i> that contains text to be used\n" +
        "as the description for that photo.<br>\n",
	0, 1 });
}

void create () {
    string css_album_name =
	"font-weight: bold;\n" +
	"font-family: Arial, Helvetica, sans-serif;\n" +
	"font-size: 12pt;\n" +
	"align: center;\n";
    string css_numofphotos =
	"font-family: Arial, Helvetica, sans-serif;\n" +
	"font-size: 10pt;\n" +
	"align: center;\n";
    string css_thumbnail_desc =
	"font-family: Arial, Helvetica, sans-serif;\n" +
	"font-size: 10pt;\n";
    string css_photo =
	"align: center;\n";
    string css_thumbnail = "";
    string css_photo_desc =
	"font-family: Arial, Helvetica, sans-serif;\n" +
	"font-size: 10pt;\n" +
	"align: center;\n";
    string css_nav =
	"font-family: Arial, Helvetica, sans-serif;\n" +
	"font-size: 10pt;\n" +
	"align: center;\n";
    string css_help =
	"CSS stands for Cascading Style Sheets.<br>\n" +
	"The CSS properties you add here will be applied to the text and images as they are displayed in the page.<br>\n" +
	"For more information about CSS see the CSS section on <a href=\"http://www.jalfrezi.com/\">The Sizzling HTML Jalfrezi</a> or <a href=\"http://www.webmonkey.com/\">Web Monkey</a><br>\n";
    defvar( "width", 120, "Default tumbnail width", TYPE_INT, "This the default width (in pixels) of the thumbnailed image" );
    defvar( "thumbnail_border", 1, "Default border width for thumbnail", TYPE_INT, "This is the default border size around each thumbnail" );
    defvar( "photo_border", 1, "Default border width for phot", TYPE_INT, "This is the default border size around the photo" );
    defvar( "show_numofphotos", 1, "Show the number of photos in the Album in the index display?", TYPE_FLAG, "" );
    defvar( "css_album_name", css_album_name, "CSS Properties for Photo Album name", TYPE_TEXT, css_help );
    defvar( "css_numofphotos", css_numofphotos, "CSS Properties for &quot;Total photos&quot; on the index display", TYPE_TEXT, "<b>You only need to enter this value if you said yes to the &quot;Total photos&quot; display question</b><br>\n" + css_help );
    defvar( "css_thumbnail", css_thumbnail, "CSS Properties for the thumbnail image", TYPE_TEXT, css_help );
    defvar( "css_thumbnail_desc", css_thumbnail_desc, "CSS Properties for the description next to each photo in the index display", TYPE_TEXT, css_help );
    defvar( "css_photo", css_photo, "CSS Properties for the photo on the photo display", TYPE_TEXT, css_help );
    defvar( "css_photo_desc", css_photo_desc, "CSS Properties for the photo description in the photo display", TYPE_TEXT, css_help );
    defvar( "css_nav", css_nav, "CSS Properties for the navigation links in the photo display", TYPE_TEXT, css_help );
    defvar( "nav_next", "Next ", "The text for the &quot;next&quot; nav link", TYPE_STRING, "This could also be an &lt;IMG&gt; tag or whatever" );
    defvar( "nav_prev", " Previous", "The text for the &quot;previous&quot; nav link", TYPE_STRING, "This could also be an &lt;IMB&gt; tag or whatever" );
    defvar( "nav_index", " Index ", "The text for the &quot;index&quot; nav link", TYPE_STRING, "This could also be an &lt;IMG&gt; tag, or whatever" );
    defvar( "void_album_name", "Untitled Photo Album", "The text shown for the photo album name where none is defined", TYPE_STRING, "" );
    defvar( "void_description", "No description given", "The text shown in place of a description if none is provided", TYPE_STRING, "" );
}

void start (int cnt, object conf) {
    // Depends of sqltag
    module_dependencies(conf, ({ "thumbnail" }));
}

string status() {
    string ret =
	"<table border=1>\n" +
	"<tr><td colspan=2>\n" +
	"<b>Photo Album Status</b>" +
	"</td></tr>\n";
    if ( sizeof( albums ) == 0 ) {
	ret += "<tr><td colspan=2>No photo albums loaded</td></tr>\n";
    } else {
        string path;
	ret += "<tr><td>Path</td><td># of photos</td></tr>\n";
	foreach( indices( albums ), path ) {
            ret += "<tr><td>" + path + "</td><td>" + sprintf( "%d", albums[ path ]->get_num_photos() ) + "</td></tr>\n";
	}
    }
    return ret + "</table>\n";
}

mapping query_tag_callers() {
    return ([ "album" : t_album ]);
}

string t_album ( string tag, mapping args, object id ) {
    if ( ( ! albums[ id->not_query ] ) || ( id->pragma[ "no-cache" ] ) ) {
	object newalbum = album();
	string name = args->name?args->name:query( "void_album_name" );
	string dir = args->dir?args->dir:"";
	if ( dir == "" ) {
	    return "<b>ERROR: No photo directory given</b>";
	}
	newalbum->set_name( name );
	array dirlist = sort( id->conf->find_dir( fix_relative( dir, id ), id ) );
	if ( sizeof( dirlist ) == 0 ) {
	    return "<b>ERROR: Photo directory appears to be empty</b>";
	}
	string filename;
	foreach( dirlist, filename ) {
	    if ( filename[ (sizeof( filename ) - 5)..sizeof( filename ) ] == ".desc" ) {
		continue;
	    }
	    string desc = id->conf->try_get_file( fix_relative( replace( dir + "/" + filename + ".desc", "//", "/" ) , id ), id );
	    if ( desc == 0 ) desc = query( "void_description" );
	    newalbum->set_photo( fix_relative( replace( dir + "/" + filename, "//", "/" ), id ), desc );
	}
	albums += ([ id->not_query : newalbum ]);
    }
    string pstate;
    int found = 0;
    foreach ( indices( id->prestate ), pstate ) {
        if ( pstate[ 0..4 ] == "page_" ) found++;
    }
    if ( found > 0 ) {
        return make_photo_page( id, albums[ id->not_query ] );
    } else {
	return make_index_page( id, albums[ id->not_query ] );
    }
}

string display_css() {
    return
	"<style type=\"text/css\">\n" +
	"<!--\n" +
	"div.albumname{\n" +
	query( "css_album_name" ) +
	"}\n" +
	"div.numofphotos{\n" +
        query( "css_numofphotos" ) +
	"}\n" +
	"div.thumbnaildesc{\n" +
	query( "css_thumbnail_desc" ) +
	"}\n" +
	"div.thumbnail{\n" +
	query( "css_thumbnail" ) +
	"}\n" +
	"div.photo{\n" +
	query( "css_photo" ) +
	"}\n" +
	"div.photodesc{\n" +
	query( "css_photo_desc" ) +
	"}\n" +
	"div.nav{\n" +
	query( "css_nav" ) +
	"}\n" +
	"-->\n" +
        "</style>\n";
}

string make_photo_page( object id, object album ) {
    string pstate, tmp;
    foreach( indices( id->prestate ), tmp ) {
	if ( tmp[ 0..4 ] == "page_" ) pstate = tmp;
    }
    int num;
    sscanf( pstate, "page_%d", num );
    num--;
    string next, previous, index;
    index = "<a href=\"" + id->not_query + "\">" + query( "nav_index" ) + "</a>";
    if ( num == 0 ) {
	next =
	    "<a href=\"/(page_2)" + id->not_query + "\">" +
	    query( "nav_next" ) +
	    "</a>";
	previous = query( "nav_prev" );
    } else if ( num == ( album->get_num_photos() - 1 ) ) {
	next = query( "nav_next" );;
	previous =
	    "<a href=\"/(page_" + sprintf( "%d", num ) + ")" + id->not_query + "\">" +
	    query( "nav_prev" ) +
	    "</a>";
    } else {
	next =
	    "<a href=\"/(page_" + sprintf( "%d", num + 2 ) + ")" + id->not_query + "\">" +
	    query( "nav_next" ) +
	    "</a>";
	previous =
	    "<a href=\"/(page_" + sprintf( "%d", num ) + ")" + id->not_query + "\">" +
	    query( "nav_prev" ) +
	    "</a>";
    }
    array tmp = album->get_photo( num );
    return
	display_css() +
	"<div class=\"photo\">" +
	"<img border=\"" + sprintf( "%d", query( "photo_border" ) ) +
	"\" alt=\"" + html_encode_string( tmp[ 1 ] ) +
	"\" src=\"" + tmp[ 0 ] +
	"\">" +
	"</div>" +
	"<br><div class=\"photodesc\">" + tmp[ 1 ] + "</div>" +
	"<br><div class=\"nav\">" + next + " " + index + " " + previous + "</div>\n";
}

string make_index_page( object id, object album ) {
    string ret =
        display_css() +
	"<div class=\"albumname\">" + album->get_name() + "</div><br>\n";
    if ( query( "show_numofphotos" ) == 1 ) {
        ret +=
	    "<div class=\"numofphotos\">Total photos: " + sprintf( "%d", album->get_num_photos() + 1 ) + "</div><br>\n";
    }
    int num;
    for( num = 0; num < album->get_num_photos(); num++ ) {
	array tmp = album->get_photo( num );
	ret +=
	    "<div class=\"thumbnail\">\n" +
	    "<a href=\"/(page_" + sprintf( "%d", num + 1 ) + ")" + id->not_query + "\">" +
	    "<thumbnail alt=\"" + html_encode_string( tmp[ 1 ] ) + "\" src=\"" + tmp[ 0 ] + "\" border=\"" + sprintf( "%d", query( "thumbnail_border" ) ) + "\" width=\"" + sprintf( "%d", query( "width" ) ) + "\">" +
	    "</a>\n" +
	    "</div>\n" +
	    "<div class=\"thumbnaildesc\">" + tmp[ 1 ] + "</div><br>\n";
    }
    return parse_rxml( ret, id );
}

class album {
    mapping data = ([ ]);

    void set_name( string name ) {
	data += ([ "album_name" : name ]);
    }

    void set_photo( string path, string desc ) {
	if ( ! data[ "photos" ] ) {
	    data += ([ "photos" : ({ }) ]);
	}
	data[ "photos" ] += ({ ([ "path" : path, "desc" : desc ]) });
    }

    mixed get_photo( int photo_num ) {
	if ( data[ "photos" ][ photo_num ] ) {
	    return ({ data[ "photos" ][ photo_num ][ "path" ], data[ "photos" ][ photo_num ][ "desc" ] });
	}
    }

    int get_num_photos() {
        return sizeof( data[ "photos" ] );
    }

    string get_name() {
	return data[ "album_name" ]?data[ "album_name" ]:"No Album Name Specified";
    }

}

