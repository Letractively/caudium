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

#include <schemes.h>

class ThemedConfig {

    constant cvs_version = "$Id$";

    object s;
    string datadir, themename;
    void create( void|string schemename, string _datadir ) {
      s = scheme( themename = schemename );
      datadir = _datadir;
    }

    string path() { return datadir || "caudium-images/"; };
    string theme() { return themename; }
    string body () {
	return
	    "<body bgcolor='" + s->html_colour( "bgcolor" ) + "' "
	    "text='" + s->html_colour( "text" ) + "' "
	    "link='" + s->html_colour( "link" ) + "' "
	    "vlink='" + s->html_colour( "vlink" ) + "' "
	    "alink='" + s->html_colour( "alink" ) + "' " +
	    (s->bgimage()?("background='" + s->bgimage() + "' "):"") +
	    " leftmargin='0' marginwidth='0' topmargin='0' marginheight='0'>\n";
    }

    string head(string h, string|void save) {
	return ("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">"
		"<head><title>"+h+"</title>\n<META HTTP-EQUIV=\"Expires\" CONTENT=\"0\">\n</head>\n" );
    }

    string tablist(array(string) nodes, array(string) links, int selected) {

	string tab_0 = "<td rowspan=2><img border=0 alt='' src='/auto/tab0' width=24 height=24></td>";
	string tab_1 = "<td rowspan=2><img border=0 alt='' src='/auto/tab1'></td>";
	string tab_2 = "<td rowspan=2><img border=0 alt='' src='/auto/tab2'></td>";
	string tab_3 = "<td rowspan=2><img border=0 alt='' src='/auto/tab3'></td>";
	string tab_4 = "<td rowspan=2><img border=0 alt='' src='/auto/tab4'></td>";
	string tab_5 = "<td rowspan=2><img border=0 alt='' src='/auto/tab5'></td>";
	string gap = "<td bgcolor='" + s->html_colour( "titlefg" ) + "'><img border=0 alt='' src='/image/unit.gif'></td>";
	array magic = ({ });
	array link = ({ });
	for( int i = 0; i < sizeof( nodes ); i++ ) {
	    if ( i == selected ) {
		// This element is selected!
		link += ({ "<td bgcolor='" + s->html_colour( "titlefg" ) + "'>&nbsp;<a href='" + links[ i ] + "'><b>" + nodes[ i ] + "</b></a>&nbsp;</td>" }) ;
	    } else {
		// This element is not!
		link += ({ "<td bgcolor='" + s->html_colour( "titlebg" ) + "'>&nbsp;<a href='" + links[ i ] + "'><b><font color='" + s->html_colour( "titlefg" ) + "'>" + nodes[ i ] + "</font></b></a>&nbsp;</td>" });
	    }
	    magic += ({ ({ gap }) });
	}
	magic = magic * ({ tab_5 });
	magic = ({ tab_4 }) + magic + ({ tab_2 });
	if ( selected != -1 ) {
	    if ( selected == 0 ) {
		magic[ 0 ] = tab_0;
	    } else {
		magic[ ( selected * 2 ) ] = tab_1;
	    }
	    if ( selected == sizeof( nodes ) - 1 ) {
		magic[ ( selected * 2 ) + 2 ] = tab_3;
	    } else {
		magic[ ( selected * 2 ) + 2 ] = tab_4;
	    }
	}
	return
	    "<table align='right' border=0 cellpadding=0 cellspacing=0>"
	    "<tr>" + ( magic * "" ) + "</tr>"
	    "<tr>" + ( link * "" ) + "</tr>"
	    "</table><br><br>";
    }

    string describe_node_path(object node) {
	string q="/";
	array res = ({ });
	int cnt;
	/* This appears to have always been buggy, it's fixed now */
	array nodes = ( node->path( 1 ) / "/" ) - ({ "" });
	if ( sizeof( nodes ) > 0 ) {
	    foreach( nodes, string p)
	    {
		q+=p+"/";
		res +=
		    ({ "<a href=\""+q+"?"+bar+++"\"><font color='" + s->html_colour( "titlefg" ) + "'>"+
                       dn(find_node(http_decode_string(q[..strlen(q)-2])))+
                       "</font></a>" });
	    }
	    return (res * " -&gt; ");
	}
    }

    string status_row(object node) {
	int open_caudium_link_in_new_window = 1;
	string node_path = describe_node_path( node );
	return ( "<table width='100%' border=0 cellpadding=0 cellspacing=0>"
		 "<tr>"
		 "<td colspan=4 bgcolor='" + s->html_colour( "titlebg" ) + "'><img border=0 alt='' src='/image/unit.gif' width=2 height=6></td>"
		 "</tr>"
		 "<tr>"
		 "<td bgcolor='" + s->html_colour( "titlebg" ) + "'><img border=0 alt='' src='/image/unit.gif' width=3 height=2></td>"
		 "<td align=bottom align=left><a href='http://www.caudium.net/'" + (open_caudium_link_in_new_window?" target='_blank'":"") + "><img border=0 src='/auto/cif_logo' alt='Caudium'></a></td>"
		 "<td width='100%' align=right height=33 valign=bottom bgcolor='" + s->html_colour( "titlebg" ) + "'>"
		 "<font size='-1' color='" + s->html_colour( "titlefg" ) + "'><b>Administration Interface</b>" + (node_path?(": " + node_path):"") + "</font></td>"
		 "<td bgcolor='" + s->html_colour( "titlebg" ) + "'><img border=0 alt='' src='/image/unit.gif' width=3 height=6></td>"
		 "</tr>"
		 "<tr>"
		 "<td colspan=4 bgcolor='" + s->html_colour( "titlebg" ) + "'><img border=0 alt='' src='/image/unit.gif' width=2 height=3></td>"
		 "</tr>"
		 "</table>\n" );
    }

    object tab_0() {
	array fg_rgb = s->rgb_colour( "titlefg" );
        array bg_rgb = s->rgb_colour( "titlebg" );
	object i = Image.Image( 24, 24, @fg_rgb);
        return i;
    }

    object tab_1() {
	array fg_rgb = s->rgb_colour( "titlefg" );
        array bg_rgb = s->rgb_colour( "titlebg" );
	object i = Image.Image( 24, 24, @fg_rgb);
	i = circlefill( i, 0, 24, 23, @bg_rgb, 255 );
        return i;
    }

    object tab_2() {
	array fg_rgb = s->rgb_colour( "titlefg" );
        array bg_rgb = s->rgb_colour( "titlebg" );
	object i = Image.Image( 24, 24, @bg_rgb );
	i = circlefill( i, 0, 24, 24, @fg_rgb, 255 );
	i = circlefill( i, 0, 24, 23, @bg_rgb, 255 );
        return i;
    }

    object tab_3() {
	array fg_rgb = s->rgb_colour( "titlefg" );
        array bg_rgb = s->rgb_colour( "titlebg" );
	object i = Image.Image( 24, 24, @bg_rgb);
	i = circlefill( i, 0, 24, 24, @fg_rgb, 255 );
        return i;
    }

    object tab_4() {
	array fg_rgb = s->rgb_colour( "titlefg" );
        array bg_rgb = s->rgb_colour( "titlebg" );
	object i = Image.Image( 24, 24, @bg_rgb);
	i = circlefill( i, 0, 24, 24, @fg_rgb, 255 );
        i->line( 0, 0, 24, 0, @fg_rgb );
        return i;
    }

    object tab_5() {
	array fg_rgb = s->rgb_colour( "titlefg" );
        array bg_rgb = s->rgb_colour( "titlebg" );
	object i = Image.Image( 24, 24, @bg_rgb);
	i = circlefill( i, 0, 24, 24, @fg_rgb, 255 );
	i = circlefill( i, 0, 24, 23, @bg_rgb, 255 );
	i->line( 0, 0, 24, 0, @fg_rgb );
        return i;
    }

    object logo() {
	array fg_rgb = s->rgb_colour( "titlefg" );
	array bg_rgb = s->rgb_colour( "titlebg" );
	object text = Image.PNM.decode(Stdio.read_file(datadir+"/cif_logo_txt.pnm"));
	if ( ! text ) {
	    throw( ({ "Failed to load logo image.", backtrace() }) );
	}
	int xsize = text->xsize();
	int ysize = text->ysize();
        int _ysize = ysize + 2;
	object back = Image.Image(
				  ( xsize + (2 * ysize) + 2 ),
				  _ysize,
				  @bg_rgb);
	back = circlefill( back,
			   _ysize,
			   _ysize,
			   _ysize,
			   @fg_rgb,
			   255 );
	back = circlefill( back,
			   ( xsize + ysize ),
			   0,
			   _ysize,
			   @fg_rgb,
			   255 );
	// This is a hack to fix the bug in circlefill();
	back->line( back->xsize() - _ysize,
		    0,
		    back->xsize(),
		    0,
		    @fg_rgb);
	back->box( _ysize,
                   0,
                   back->xsize() - _ysize,
		   _ysize,
		   @fg_rgb );
	object fore = Image.Image( xsize, ysize, @bg_rgb);
	back->paste_mask( fore,
			  text,
			  ( ( back->xsize() - text->xsize() ) / 2 ),
			  ( ( back->ysize() - text->ysize() ) / 2 ) );
	Stdio.write_file("/tmp/image.gif", Image.GIF.encode(back));
        return back;
    }

    object circlefill( object i, int x, int y, int r, int cr, int cg, int cb, int alpha ) {
	/*
	 * object i = the image object
	 * int x = the x coordinate for the center of the circle
	 * int y = the y coordinate for the center of the circle
	 * int r = the radius of the circle
	 * int cr = red value (0 - 255)
	 * int cg = green value (0 - 255)
	 * int cb = blue value (0 - 255)
	 * int alpha = alpha value (0 - 255)
	 */
	array points = ({ });
	// positive y values
	for( int _x = 0 - r; _x != r; _x++ ) {
	    int _y = (int)floor( sqrt( pow( r, 2 ) - pow( _x, 2 ) ) );
	    points += ({ ( _x + x ), ( _y + y ) });
	}
	// negative y values
	for( int _x = r; _x != 0 - r; _x-- ) {
	    int _y = 0 - (int)floor( sqrt( pow( r, 2 ) - pow( _x, 2 ) ) );
	    points += ({ ( _x + x ) , ( _y + y ) });
	}
	i->setcolor( cr, cg, cb, alpha );
	i->polyfill( points );
	return i;
    }

}
