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
//! module: Tab lists
//!  This module makes graphical tablists.<p>
//!  <strong>NOTE:</strong> This module is not supported and is only here
//!  for compatibility reasons. Please use "<strong>Config tab-list</strong>"
//!  instead.</p>
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER | MODULE_LOCATION
//! cvs_version: $Id$
//

/* The Tab lists tag module. */
string cvs_version = "$Id$";
#include <module.h>

inherit "module";
inherit "caudiumlib";

import Array;

constant module_type = MODULE_PARSER | MODULE_LOCATION;
constant module_name = "Tab lists";
constant module_doc  = "This module makes graphical tablists.<p>"
       "<b>NOTE:</b> This module is not supported and is only here "
       "for compatibility reasons. Please use ``<b>Config tab-list</b>'' "
       "instead.<p>";
constant module_unique = 1;

#define DEFAULT_FONT "32/urw_itc_avant_garde-demi-r"
#define DEFAULT_PATH "fonts/"

// #define DEBUG_TABLIST

array(string) from=map(indices(allocate(256)),lambda(int l) { return sprintf("%c",l); });
array(string) to=map(indices(allocate(256)),
		     lambda(int l) {
		       switch(l)
		       {
		       case 0: return "-";
		       case 'a'..'z':
		       case '.':
		       case ':':
		       case 'A'+16..'Z':
		       case '0'..'9': return sprintf("%c",l);
		       default: return sprintf("%c%c",'A'+(l>>4),'A'+(l&15));
		       }
		     });

string make_filename(mapping arguments)
{
  string s = encode_value(arguments);
  return replace(s,from,to);
}

mapping make_arguments(string filename)
{
  filename=replace(filename,to,from);
  
  return decode_value(filename);
}

array (int) make_color(string s)
{
  int c = (int) ("0x"+(s-" ")[1..]);
  return ({ ((c >> 16) & 0xff),
	    ((c >>  8) & 0xff),
	     (c        & 0xff) });
}

void draw_bg(object img, array (int) bg, array (int) tc)
{
  img->tuned_box(0, 0, img->xsize()-1, 7, ({
		 ({ @bg }),
		 ({ @bg }),
		 ({ @map(tc, `/, 7) }),
		 ({ @map(tc, `/, 7) }) }) );
  img->line(0, 8, img->xsize()-1, 8, 0,0,0);
  img->box(0, 9, img->xsize()-1, img->ysize()-12, @tc);
  img->tuned_box(0, img->ysize()-11, img->xsize()-1, img->ysize()-1, ({
                 ({ @tc }),
		 ({ @tc }),
		 ({ @map(bg, `/, 3) }),
		 ({ @map(bg, `/, 3) }) }) );
  img->line(0, img->ysize()-1, img->xsize()-1, img->ysize()-1, 0,0,0);
}

void right_shadow(object img, array (int) tc)
{
  int i;

  float dr = (6*((float) tc[0])/7)/10;
  float dg = (6*((float) tc[1])/7)/10;
  float db = (6*((float) tc[2])/7)/10;
  float tr = (float) tc[0]/7;
  float tg = (float) tc[1]/7;
  float tb = (float) tc[2]/7;
  for (i = 0; i < 10; i++) {
    tr += dr; tg += dg; tb += db;
    img->line(img->xsize()-15+i, 9, img->xsize()-5-1+i/2, img->ysize()-1-i,
	      (int)tr,(int)tg,(int)tb);
    img->line(img->xsize()-14+i, 9, img->xsize()-5-1+i/2, img->ysize()-1-i,
	      (int)tr,(int)tg,(int)tb);
  }
}

void right_selected(object img, array (int) bg)
{
  int y;
  float x = img->xsize()-1;
  float dx = ((float) 13)/((float) img->ysize());
  for (y = 9; y < img->ysize(); y++) {
    img->line((int) x, y, img->xsize()-1, y, @bg);
    x -= dx;
  }
  img->line(img->xsize()-1, 9, img->xsize()-13, img->ysize()-1, 0,0,0);
  img->line(img->xsize()-2, 9, img->xsize()-13, img->ysize()-1, 0,0,0);
}

void selected(object img, array (int) bg)
{
  int y;
  float x = ((float) img->xsize()) - 14.0;
  float dx = ((float) 10)/((float) img->ysize());
  for (y = 9; y < img->ysize(); y++) {
    img->line(0, y, (int) x, y, @bg);
    x += dx;
  }
}

void left_end(object img, array (int) bg)
{
  int y;
  float x = (float) 15;
  float dx = ((float) x)/((float) img->ysize());
  for (y = 0; y < img->ysize()-1; y++) {
    img->line(0, y, (int) x, y, @bg);
    x -= dx;
  }
  img->line(15, 9, 0, img->ysize()-1, 0,0,0);
  img->line(14, 9, 0, img->ysize()-1, 0,0,0);
}

void right_end(object img, array (int) bg)
{
  int y;
  float x = 0.0;
  float dx = ((float) 13)/((float) img->ysize());
  for (y = 0; y < img->ysize()-1; y++) {
    img->line(img->xsize()-13 + (int) x, y, img->xsize()-1, y, @bg);
    x += dx;
  }
  right_shadow(img, bg);
}

object tab(string name, int select, int n, int last, string font,
	   array (int) bg, array (int) tc, array (int) fc)
{
  int w_spacing = 40+20;
  int h_spacing = 20+5;
  object fnt, txt, img, tmp;
  int width, height;

#ifdef DEBUG_TABLIST
  perror("Creating tab \"" + name + (select==n?"\" (selected)\n":"\"\n"));
#endif

  fnt = Image.Font();
  if (!fnt->load(font)) {
     perror("Could not load font \"" + font + "\"\n");
     fnt->load(DEFAULT_PATH DEFAULT_FONT);
  }
  txt = fnt->write(name);
#ifdef DEBUG_TABLIST
  perror((sprintf("Font image size: %d × %d\n",txt->xsize(),txt->ysize())));
#endif
  width = txt->xsize() + w_spacing;
  height = txt->ysize() + h_spacing;

  img = Image.Image(width,height);
  draw_bg(img, bg, tc);
  if (n == select)
    selected(img, bg);
  if (n+1 == select)
    right_selected(img, bg);
  if (n == last)
    right_end(img, bg);
  else if (n+1 != select)
    right_shadow(img, tc);

  if ((txt->xsize()) && (txt->ysize())) {
    tmp=Image.Image(txt->xsize(), txt->ysize());
    tmp->box(0, 0, tmp->xsize()-1, tmp->ysize()-1, @fc);
    img->paste_mask(tmp, txt, w_spacing/3, h_spacing/2);
  }

  if (!n)
    left_end(img, bg);
  
  return img;
}

void create()
{
  defvar("foo", "/tablists/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The mountpoint in the virtual filesystem.");
  defvar("fontpath", DEFAULT_PATH, "Font path", TYPE_DIR|VAR_MORE,
	 "The path to the font");
  defvar("defaultfont", DEFAULT_FONT, "Default font", TYPE_FILE|VAR_MORE,
	 "The default font to use when making the tablists.");
}

string query_location()
{
  return query("foo");
}

mapping find_file(string filename, object request_id)
{
  string s;
  if(s = cache_lookup("tabs", filename))
    return http_string_answer(s, "image/gif");

  mapping arguments = make_arguments(filename);
  int n = (int) arguments->n;
  int last = (int) arguments->last;
  string name = (string) (arguments->name || "");
  int selected = ((int) arguments->selected) || 1;
  selected--;

  float scale = 0.5;
  if ((float) arguments->scale > 0)
    scale *= (float) arguments->scale;

  string font = (string) (arguments->font || query("defaultfont"));
  if (font[0] != '/') font = query("fontpath") + font;
  array (int) bg = make_color(arguments->bg||"#c0c0c0");  // Background color
  array (int) tc = make_color(arguments->tc||"#d6c69c");  // Tab color
  array (int) fc = make_color(arguments->fc||"#000000");  // Font color

  s = tab(name, selected, n, last, font, bg, tc, fc)->scale(scale)->togif(@bg);
  cache_set("tabs", filename, s);
  return http_string_answer(s, "image/gif");
}

string tag_tablist(string tag_name, mapping arguments, object request_id)
{
  int n = 0;
  string s, name;

  array (string) names = ((string) arguments->names)/";";
  arguments[ "last" ] = sizeof(names)-1;
  s = "<table cellspacing=0 cellpadding=0 border=0><tr>";
  foreach(names, name) {
    arguments[ "name" ] = name;
    arguments[ "n" ] = (string) n++;
    s += "<td>";
    if (arguments[(string) n])
      s += "<a href=\""+(arguments[(string) n]?arguments[(string) n]:"")+"\">"+
	   "<img border=0 "
	   "alt=\""+((n==1||(n==(int)arguments->selected))?"/":"")+name+
 	    ((n+1==(int)arguments->selected)?"":"\\")+"\" "+
	   "src="+query_location()+make_filename(arguments)+"></a>";
    else
      s += "<img border=0 "
	   "alt=\""+((n==1||(n==(int)arguments->selected))?"/":"")+name+
	    ((n+1==(int)arguments->selected)?"":"\\")+"\" "+
	   "src="+query_location()+make_filename(arguments)+">";
    s += "</td>";
  }
  s += "</tr></table>";
  return s+"\n";
}

mapping query_tag_callers()
{
  return ([ "tablist":tag_tablist, ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: foo
//! The mountpoint in the virtual filesystem.
//!  type: TYPE_LOCATION|VAR_MORE
//!  name: Mountpoint
//
//! defvar: fontpath
//! The path to the font
//!  type: TYPE_DIR|VAR_MORE
//!  name: Font path
//
//! defvar: defaultfont
//! The default font to use when making the tablists.
//!  type: TYPE_FILE|VAR_MORE
//!  name: Default font
//
