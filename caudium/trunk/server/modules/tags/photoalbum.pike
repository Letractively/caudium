/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

//
//! module: Photo Album
//!  This is a new photo album module for Caudium.
//!  It automagically generates photo albums based on a directory of
//!  image files.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//

/*
 * This is the _NEW_ photo album module for pike.
 * I didn't like the way that the original one worked so I thought I would
 * re-write it.
 *
 * Original author : James Tyson) <james@samizdat.co.nz>
 * Modified by Tomasz Proc <tp@d-net.pl> (damn <br> tags)
 */

/* Standard includes */

#include <config.h>
#include <module.h>

inherit "module";

#ifdef CAUDIUM
inherit "caudiumlib";
#else
inherit "roxenlib";
#endif

/* Custom includes */

constant cvs_version = "$Id$";
constant thread_safe=1;

mapping albums = ([ ]);

array register_module() {
    return
	({ MODULE_PARSER,
	"Photo Album",
	"This is a new photo album module for Caudium.<br>\n" +
	"It automagically generates photo albums based on a directory of\n" +
	"image files.<br>\n" +
        "The syntax is easy to use, and can be embedded in any HTML page.<blockquote>\n" +
	html_encode_string( "<album name=\"My Photo Album\" dir=\"myphotos/\">\n" ) +
	"</blockquote>\n" +
	"The <i>name</i> argument sets the photo album name to be displayed,\n" +
	"if not specified it uses the default value set in the config interface.<br>\n" +
	"The <i>dir</i> argument points to a directory within the virtual filesystem\n" +
	"where a bunch of images are stored. Note that this directory is relative not\n" +
	"to your virtual filesystem root, but to the directory where the HTML file\n" +
	"with the &lt;album&gt; tag is.<br />\n" + 
	"Another important thing is that the directory must be browsable. This can be\n" +
	"Done either in the config interface by setting the <em>Enable directory listings per default</em>\n" +
	"option to <strong>yes</strong> in the appropriate file system, or by creating a file\n" +
	"named <tt>.www_browsable</tt> in your album directory. If none of those options is set\n" +
	"the module will report that the directory is empty, even though there are images in it<br />\n" +
	"For every image (say <i>myphoto.jpg</i>) there optionally can be a\n" +
	"file called <i>myphoto.jpg.desc</i> that contains text to be used\n" +
        "as the description for that photo.<br>\n",
	0, 1 });
}

void create () {
    string css_classes =
	"/* These are the default CSS classes, you can delete them\n" +
	" * and your page will be rendered with your default document\n" +
	" * properties.\n" +
	" * You can also check out the template option for more advanced\n" +
	" * Layout control.\n" +
	" */\n" +
	"div.albumname {\n" +
	"\tfont-weight: bold;\n" +
	"\tfont-family: Arial, Helvetica, sans-serif;\n" +
	"\tfont-size: 12pt;\n" +
	"\talign: center;\n" +
	"}\n" +
	"div.numofphotos {\n" +
	"\tfont-family: Arial, Helvetica, sans-serif;\n" +
	"\tfont-size: 10pt;\n" +
	"\talign: center;\n" +
	"}\n" +
	"font.thumbnaildesc {\n" +
	"\tfont-family: Arial, Helvetica, sans-serif;\n" +
	"\tfont-size: 10pt;\n" +
	"}\n" +
	"div.photo {\n" +
	"\talign: center;\n" +
	"}\n" +
	"div.thumbnail {\n" +
	"}\n" +
	"div.photodesc {\n" +
	"\tfont-family: Arial, Helvetica, sans-serif;\n" +
	"\tfont-size: 10pt;\n" +
	"\talign: center;\n" +
	"}\n" +
	"div.nav {\n" +
	"\tfont-family: Arial, Helvetica, sans-serif;\n" +
	"\tfont-size: 10pt;\n" +
	"\talign: center;\n" +
	"}\n";
    string css_help =
	"CSS stands for Cascading Style Sheets.<br>\n" +
	"The CSS properties you add here will be applied to the text and images as they are displayed in the page.<br>\n" +
	"For more information about CSS see the CSS section on <a href=\"http://www.jalfrezi.com/\">The Sizzling HTML Jalfrezi</a> or <a href=\"http://www.webmonkey.com/\">Web Monkey</a><br>\n";
    defvar( "width", 120, "Default tumbnail width", TYPE_INT, "This the default width (in pixels) of the thumbnailed image" );
    defvar( "thumbnail_border", 1, "Default border width for thumbnail", TYPE_INT|VAR_MORE, "This is the default border size around each thumbnail" );
    defvar( "photo_border", 1, "Default border width for phot", TYPE_INT|VAR_MORE, "This is the default border size around the photo" );
    defvar( "show_numofphotos", 1, "Show the number of photos in the Album in the index display?", TYPE_FLAG, "" );
    defvar( "css_classes", css_classes, "CSS Classes", TYPE_TEXT|VAR_MORE, css_help );
    defvar( "use_css", 1, "Use the defined CSS Classes", TYPE_FLAG, "You can turn off the usage of Photo Album's default CSS Classes" );
    defvar( "nav_next", "Next", "The text for the &quot;next&quot; nav link", TYPE_STRING|VAR_MORE, "This could also be an &lt;IMG&gt; tag or whatever" );
    defvar( "nav_prev", "Previous", "The text for the &quot;previous&quot; nav link", TYPE_STRING|VAR_MORE, "This could also be an &lt;IMB&gt; tag or whatever" );
    defvar( "nav_index", "Index", "The text for the &quot;index&quot; nav link", TYPE_STRING|VAR_MORE, "This could also be an &lt;IMG&gt; tag, or whatever" );
    defvar( "void_album_name", "Untitled Photo Album", "The text shown for the photo album name where none is defined", TYPE_STRING|VAR_MORE, "" );
    defvar( "void_description", "No description given", "The text shown in place of a description if none is provided", TYPE_STRING|VAR_MORE, "" );
    defvar( "void_cols", 4, "Default number of col's", TYPE_INT, "Default number of columns." );
}

void start (int cnt, object conf) {
    // Depends of sqltag
    module_dependencies(conf, ({ "cimg" }));
}

string status() {
    string ret =
	"<table border=1>\n" +
	"<tr><td colspan=2>\n" +
	"<strong>Photo Album Status</strong>" +
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

mixed build_album( object id, mapping args ) {
    object newalbum = album( query );
    string name = args->name?args->name:QUERY(void_album_name);
    string dir = args->dir?args->dir:"";
    int cols = (int)args["cols"] || QUERY(void_cols);
    if ( dir == "" ) {
	return "<b>ERROR:</b> No photo directory given!\n";
    }
    newalbum->set_name( name );
    newalbum->set_cols( cols );
    array tmp = id->conf->find_dir( fix_relative( dir, id ), id );
    array dirlist = sort( tmp ? tmp : ({}) );
    if ( sizeof( dirlist ) == 0 ) {
	return "<b>ERROR:</b> Photo directory is empty!\n";
    }
    string filename;
    foreach( dirlist, filename ) {
	array f = filename / ".";
	string ext = lower_case( f[ sizeof( f ) - 1 ] );
	if ( ! (( ext == "jpg" )
	     || ( ext == "gif" )
	     || ( ext == "png" )) ) continue;
	string fullpath = fix_relative( replace( dir + "/" + filename, "//", "/" ), id );
	newalbum->set_photo(
                            fullpath,
			    ( id->conf->try_get_file( fullpath + ".desc", id )?id->conf->try_get_file( fullpath + ".desc", id ):QUERY(void_description))
			   );
    }
    newalbum->set_template( args->template?args->template:0 );
    return newalbum;
}

string t_album ( string tag, mapping args, object id ) {
    if ( ( ! albums[ id->not_query ] ) || ( id->pragma[ "no-cache" ] ) ) {
	mixed x = build_album( id, args );
        if ( stringp( x ) ) return sprintf( "%s", x );
        object o = x;
	albums += ([ id->not_query : o ]);
    }
    return albums[ id->not_query ]->render_page( id );
}

class album {
    mapping data = ([ ]);
    function query;

    void create( function q ) {
	query = q;
    }

    private string prestate( array pstates, string url ) {
	array urlparts = url / "/";
	urlparts = urlparts - ({ "" });
	urlparts = urlparts[ 0 ][ 0 ] == "("?urlparts - ({ urlparts[ 0 ] }):urlparts;
	string prestate = "(" + ( pstates * "," ) + ")";
	urlparts = ({ prestate }) + urlparts;
	string ret = urlparts * "/";
        return "/" + ret;
    }

    // t0mpr dodal
    void set_cols( int cols ) {
        data += ([ "num_cols" : cols ]);
    }
   
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
	return data[ "photos" ]?sizeof( data[ "photos" ] ):0;
    }

    string get_name() {
	return data[ "album_name" ]?data[ "album_name" ]:"No Album Name Specified";
    }

    void set_template( object id, void|string filename ) {
	if ( filename ) {
	    string tmpl = id->conf->try_get_file( fix_relative( filename, id ), id );
	    if ( tmpl == "" ) return;
	    data += ([ "template" : tmpl ]);
	}
    }

    string render_othumb(object id, int i) {
      return "<a href=\"" + prestate( ({ "page_" + sprintf( "%d", i + 1 ) }), id->not_query ) +"\">\n" +
	"<cimg alt=\"" + id->conf->html_encode_string( get_photo( i )[ 1 ] ) + "\" " +
	"src=\"" + get_photo( i )[ 0 ] + "\" " +
	/*	"border=\"" + sprintf( "%d", QUERY(thumbnail_border) ) + "\" " +*/
	"maxwidth=\"" + QUERY(width) + "\" "+
	"maxheight=\"" + QUERY(width) + "\" "+ 
	"format=\"jpeg\">" +

	"</a><br>\n" +
	"<font class=\"thumbnaildesc\">" +
	get_photo( i )[ 1 ] +
        "</font>\n";
    }


    string render_index_page( object id ) {
	string ret = "";
	if ( QUERY(use_css) ) {
	    ret += "<style type=\"text/css\">\n<!--\n" + QUERY(css_classes) + "\n-->\n</style>\n";
	} else {
	    ret += "";
	}
	if ( data[ "template" ] ) {
            return "not implemented yet";
	} else {
	    ret +=
		"<div class=\"albumname\">" + get_name() + "</div><br>\n" +
		((QUERY(show_numofphotos))?("<div class=\"numofphotos\">Total Photos: " + sprintf( "%d", get_num_photos() ) + "</div><br>\n"):"") +
                "<div class=\"thumbnail\">\n";

	    int i=0,j,k;
            ret += "<table cellspacing=15>";
	    for ( j=0; j <= (get_num_photos()/data["num_cols"]); j++ ) {
	        ret += "<tr align=center valign=top>";
	        for (k=0; k<data["num_cols"]; k++) {
		    if (get_num_photos()==i) break; 
		    ret += "<td>"+render_othumb(id,i)+"</td>";
		    i++;
    		}
		ret += "</tr>";
	    }
	    ret += "</table>" ;
            return parse_rxml( ret, id );
	}
    }

    private string a_next( string url, int page_num, string contents ) {
	if ( page_num == 0 ) {
	    return "<a href=\"" + prestate( ({ "page_2" }), url ) + "\">" + contents + "</a>";
	} else if ( page_num == ( get_num_photos() - 1 ) ) {
            return contents;
	} else {
	    return "<a href=\"" + prestate( ({ "page_" + sprintf( "%d", page_num + 2 ) }), url ) + "\">" + contents + "</a>";
	}
    }

    private string a_prev( string url, int page_num, string contents ) {
	if ( page_num == 0 ) {
	    return contents;
	} else {
	    return "<a href=\"" + prestate( ({ "page_" + sprintf( "%d", page_num ) }), url ) + "\">" + contents + "</a>";
	}
    }

    string render_photo_page( object id, int page_num ) {
	string ret;
	if ( QUERY(use_css) ) {
	    ret = "<style type\"text/css\">\n<!--\n" + QUERY(css_classes) + "\n-->\n</style>\n";
	} else {
	    ret = "";
	}
	if ( data[ "template" ] ) {
            return "not implemented yet";
	} else {
	    ret +=
		"<div class=\"albumname\">" + get_name() + "</div><br>\n" +
                "<div class=\"photodesc\">" + get_photo( page_num )[ 1 ] + "</div><br>\n" +
		"<div class=\"photo\">" +
		"<img border=\"" + sprintf( "%d", QUERY(photo_border) ) + "\" " +
		"alt=\"" + id->conf->html_encode_string( get_photo( page_num )[ 1 ] ) + "\" " +
		"src=\"" + get_photo( page_num )[ 0 ] + "\">" +
		"</div><br>\n" +
                "<div class=\"nav\">" +
		a_next( id->not_query, page_num, QUERY(nav_next) ) + " " +
		"<a href=\"" + id->not_query + "\">" + QUERY(nav_index) + "</a> " +
		a_prev( id->not_query, page_num, QUERY(nav_prev) ) +
                "</div>";
	}
        return ret;
    }

    string render_page( object id ) {
	int page_num;
	string tmp;
	foreach( indices( id->prestate ), tmp ) {
	    if ( tmp[ 0..4 ] == "page_" ) sscanf( tmp, "page_%d", page_num );
	}
	if ( page_num > 0 ) {
	    return render_photo_page( id, page_num - 1 );
	} else {
	    return render_index_page( id );
	}
    }

}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: width
//! This the default width (in pixels) of the thumbnailed image
//!  type: TYPE_INT
//!  name: Default tumbnail width
//
//! defvar: thumbnail_border
//! This is the default border size around each thumbnail
//!  type: TYPE_INT|VAR_MORE
//!  name: Default border width for thumbnail
//
//! defvar: photo_border
//! This is the default border size around the photo
//!  type: TYPE_INT|VAR_MORE
//!  name: Default border width for phot
//
//! defvar: show_numofphotos
//!  type: TYPE_FLAG
//!  name: Show the number of photos in the Album in the index display?
//
//! defvar: css_classes
//!  type: TYPE_TEXT|VAR_MORE
//!  name: CSS Classes
//
//! defvar: use_css
//! You can turn off the usage of Photo Album's default CSS Classes
//!  type: TYPE_FLAG
//!  name: Use the defined CSS Classes
//
//! defvar: nav_next
//! This could also be an &lt;IMG&gt; tag or whatever
//!  type: TYPE_STRING|VAR_MORE
//!  name: The text for the &quot;next&quot; nav link
//
//! defvar: nav_prev
//! This could also be an &lt;IMB&gt; tag or whatever
//!  type: TYPE_STRING|VAR_MORE
//!  name: The text for the &quot;previous&quot; nav link
//
//! defvar: nav_index
//! This could also be an &lt;IMG&gt; tag, or whatever
//!  type: TYPE_STRING|VAR_MORE
//!  name: The text for the &quot;index&quot; nav link
//
//! defvar: void_album_name
//!  type: TYPE_STRING|VAR_MORE
//!  name: The text shown for the photo album name where none is defined
//
//! defvar: void_description
//!  type: TYPE_STRING|VAR_MORE
//!  name: The text shown in place of a description if none is provided
//
//! defvar: void_cols
//! Default number of columns.
//!  type: TYPE_INT
//!  name: Default number of col's
//
