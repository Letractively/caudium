class scheme {

    constant cvs_version = "$Id$";


    /*
     * A Colour Scheme looks like this:
     *
     * mapping(string:string) scheme =
     *  ([  "bgcolor" : "ffffff",
     *      "text"    : "003366",
     *      "link"    : "003366",
     *      "vlink"   : "000000",
     *      "alink"   : "ff0000",
     *      "bgimage" : "/image/cowfish-bg.gif",
     *      "titlefg" : "ffffff",
     *      "titlebg" : "003366"
     *    ]);
     *
     */

    mapping all_themes =
	([ "default" : ([
			 "bgcolor" : "ffffff",
			 "text"    : "003366",
			 "link"    : "003366",
			 "vlink"   : "000000",
			 "alink"   : "ff0000",
			 "bgimage" : "/image/cowfish-bg.gif",
			 "titlefg" : "ffffff",
			 "titlebg" : "003366",
			 "name"    : "Old Style Caudium Colours"
			]),
	   "caudiumnet" : ([
			    "bgcolor" : "ffffff",
			    "text"    : "000000",
			    "link"    : "00206f",
			    "vlink"   : "001045",
			    "alink"   : "ff0000",
			    "bgimage" : "/image/cowfish-bg.gif",
			    "titlefg" : "ffffff",
			    "titlebg" : "0a6ab2",
			    "name"    : "Supposed to look like caudium.net"
			   ]),
	   "caudiumorg" : ([
			    "bgcolor" : "ffffff",
			    "text"    : "000000",
			    "link"    : "003f10",
			    "vlink"   : "003505",
			    "alink"   : "ff0000",
			    "bgimage" : "/image/cowfish-bg.gif",
			    "titlefg" : "ffffff",
			    "titlebg" : "04740a",
			    "name"    : "Supposed to look like caudium.org"
			   ])
           ]);

    mapping scheme;

    void create( void|string themename ) {
	if ( catch( scheme = all_themes[ themename ] ) ) {
#ifdef DEBUG
	    write( "schemes.h: Scheme '" + themename + "' doesnt exist!\n" );
#endif
	    scheme = all_themes[ "default" ];
	}
        scheme = all_themes[ themename ];
    }

    string colour( string index ) {
        return scheme[ index ];
    }

    string html_colour( string index ) {
	return sprintf( "#%s", scheme[ index ] );
    }

    array rgb_colour( string index ) {
	object c = Image.Color.html( "#" + scheme[ index ] );
        return c->rgb();
    }

    mixed bgimage() {
	return scheme->bgimage?scheme->bgimage:0;
    }

    string theme_list() {
	string retval =
            "You may need to <i>shift-reload</i> if you change this"
	    "You can select out of the following list:<blockquote>\n";
	string theme;
	foreach( indices( all_themes ), theme ) {
            retval +=
		"<b>" + theme + "</b><blockquote>"
		"<i>" + all_themes[ theme ][ "name" ] + "</i></blockquote>\n";
	}
        return retval + "</blockquote>";
    }

    array theme_select() {
	return indices( all_themes );
    }

}