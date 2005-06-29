/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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
 * $Id$
 */

//! Caudium CIF module for drawing button, icons etc...
//! $Id$

#include <module.h>

constant cvs_version = "$Id$";

//!
Image.image load_image(string f)
{
  object file = Stdio.File();
  string data;
  object img = Image.image();

//  report_debug("Loading "+f+"\n");

  if(!file->open("caudium-images/modules/"+f,"r"))
  {
    perror("Image things: Failed to open file ("+f+").\n");
    return 0;
  }

  if(!(data=file->read(0x7fffffff)))
    return 0;

  if(img=Image.PNM.decode(data))
    return img;
//  report_debug("Failed to parse image file.\n");
  return 0;
}

#define PASTE(X,Y) do{\
  /*if(!first_icon){knappar->paste(pad,cxp,0);cxp+=pad->xsize();}*/\
  if(X){knappar->paste(X,cxp,0);cxp+=X->xsize();first_icon=0;}\
  if(strlen(Y)) {\
    object f = font->write(Y)->scale(0.45);\
    knappar->paste_mask(Image.image(f->xsize(),f->ysize()),f,cxp-f->xsize()-4,-1);\
   }\
 }while(0)

#define first_filter  load_image("1stfilt.ppm")->scale(0,48)
#define last_filter   load_image("lastfilt.ppm")->scale(0,48)
#define experimental  load_image("experimental.ppm")->scale(0,48)
#define last          load_image("last.ppm")->scale(0,48)
#define first         load_image("first.ppm")->scale(0,48)
#define dir           load_image("dir.ppm")->scale(0,48)
#define location      load_image("find.ppm")->scale(0,48)
#define extension     load_image("extension.ppm")->scale(0,48)
#define logger        load_image("log.ppm")->scale(0,48)
#define proxy         load_image("proxy.ppm")->scale(0,48)
#define security      load_image("security.ppm")->scale(0,48)
#define tag           load_image("tag.ppm")->scale(0,48)
#define fade          load_image("fade.ppm")->scale(0,48)
#define pad           load_image("padding.ppm")->scale(0,48)

//!
Image.image draw_module_header(string name, int type, object font)
{
  object result = Image.image(1000,48);
  object knappar = Image.image(1000,48);
  object text;
  int cxp = 0, first_icon;
  text = font->write(name);
  first_icon=1;PASTE(fade,"");first_icon=1;
  if(type&MODULE_EXPERIMENTAL) PASTE(experimental,"Experimental");
  if((type&MODULE_AUTH)||(type&MODULE_SECURITY)) PASTE(security,"");
  if(type&MODULE_FIRST) PASTE(first,"First");
  if(type&MODULE_URL) PASTE(first_filter,"Filter");
  if(type&MODULE_PROXY) PASTE(proxy,"Proxy");
  if(type&MODULE_LOCATION) PASTE(location,"Location");
  if(type&MODULE_DIRECTORIES) PASTE(dir,"Dir");
  if((type&MODULE_EXTENSION)||(type&MODULE_FILE_EXTENSION))
    PASTE(extension,"Ext.");
  if(type&MODULE_PARSER) PASTE(tag,"");
  if(type&MODULE_FILTER) PASTE(last_filter,"Filter");
  if(type&MODULE_LAST) PASTE(last,"Last");
  if(type&MODULE_LOGGER) PASTE(logger,"Logger");

  knappar = knappar->autocrop();

  result->paste(knappar,result->xsize()-knappar->xsize(),0);
//result->line(0,0,1000,0,255,255,0);
  result->paste_alpha_color(text, 255,255,0, 6,3);
  knappar = 0;
  text=0;

//  result = result->autocrop(10,0,0,1,1);
//  result = bevel(result, 4);
  result = result->scale(0.5);
  return result;
}

#define TABSIZE 15

#define R 11
#define G 33
#define B 77

// Page color
#define dR 0xff
#define dG 0xff
#define dB 0xff


// 0x88, 0xcc, 0xaa
// 11, 33, 77
// Button background
#define bR 11
#define bG 33
#define bB 77

// Button selected
#define bsR 0x88
#define bsG 0xcc
#define bsB 0xaa

// Button text
#define btR 0xff
#define btG 0xff
#define btB 0xff

// Background hightlight
#define bhR 0x00
#define bhG 0x60
#define bhB 0xff

// Text (Obsolete)
#define tR 0xff
#define tG 0xff
#define tB 0x88

// Highlight
#define hR 0
#define hG 0xa0
#define hB 0xff

object unselected_tab_image = load_image("../tab_unselected.ppm");
object selected_tab_image = load_image("../tab_selected.ppm");

//!
Image.Image draw_config_button(string name, object font, int lm, int rm,
			       void|array bg, void|array fg, void|array page)
{
  Image.Color.Color bgc, fgc, pagec;
  if(bg) bgc = Image.Color(@bg);
  else bgc = Image.Color(dR, dG, dB);
  if(fg) fgc = Image.Color(@fg);
  else fgc = Image.Color(bR, bG, bB);
  if(page) pagec = Image.Color(@page);
  else pagec = Image.Color(bR, bG, bB);
  
  if(!strlen(name)) return Image.Image(1,15, pagec);
  object txt = font->write(name)->scale(0.48);
  int w = txt->xsize();
  object ruta = Image.Image(w + (rm?40:20), 20, bgc);
  if (lm) {
    // Left-most
    ruta->setcolor(@pagec->rgb())->polygone(({ 0,0, 15,0, 5,20, 0,20 }));
  } else {
    // Add separator.
    ruta->setcolor(@pagec->rgb())->polygone(({ 5,20, 15,0, 16,0, 6,20 }));
  }
  if (rm) {
    // Right-most
    ruta->setcolor(@pagec->rgb())->polygone(({ 36+w,0, 41+w,0, 40+w,20, 26+w,20 }));
  }

  ruta->paste_alpha_color(txt, fgc, 18, 0);

  return ruta->scale(0,15);
}

//!
Image.image draw_tab( object tab, object text, array(int) bgcolor )
{
  text = text->scale( 0, tab->ysize()-2 );
  object i = Image.image( tab->xsize()*2 + text->xsize(), tab->ysize() );
  if(bgcolor)
    tab *= bgcolor;
  i = i->paste( tab );
  i = i->paste( tab->mirrorx(), i->xsize()-tab->xsize(), 0 );
  object linje=tab->copy(tab->xsize()-1, 0, tab->xsize()-1, tab->ysize());
  for(int x = tab->xsize(); x<i->xsize()-tab->xsize(); x++ )
    i->paste( linje, x, 0 );
  if(`+(@tab->getpixel( tab->xsize()-1, tab->ysize()/2 )) < 200)
    i->paste_alpha_color( text, 255,255,255, tab->xsize(), 2 );
  else
    i->paste_alpha_color( text, 0,0,0, tab->xsize(), 2 );
  return i;
}


//!
Image.image draw_unselected_button(string name, object font,
					    void|array(int) pagecol)
{
  object txt = font->write(name);
  return draw_tab( unselected_tab_image, txt, pagecol );
}

//!
Image.image draw_selected_button(string name, object font,
					  void|array(int) pagecol)
{
  object txt = font->write(name);
  return draw_tab( selected_tab_image, txt, pagecol );
}


//!
object pil(int c, object s)
{
  object bgc = s ? s->rgb_colour("bgcolor") :  ({ dR,dG,dB });
  object fgc = s ? s->rgb_colour("titlebg") :  ({ dR,dG,dB });
  object f=Image.image(50,50,@bgc);
  if(c) 
    f->setcolor(200,0,0);
  else
    f->setcolor(@fgc);
  for(int i=1; i<25; i++)
    f->line(25-i,i,25+i,i);
  return f;
}

//!
object draw_unfold(int c, void|object s)
{
  object bgc = s ? s->rgb_colour("bgcolor") :  ({ dR,dG,dB });
  return pil(c, s)->setcolor(@bgc)->rotate(-90)->scale(15,0);
}

//!
object draw_fold(int c, void|object s)
{
  object bgc = s ? s->rgb_colour("bgcolor") :  ({ dR,dG,dB });
  return pil(c, s)->setcolor(@bgc)->rotate(-180)->scale(15,0);
}

//!
object draw_back(int c, void|object s)
{
  object bgc = s ? s->rgb_colour("bgcolor") :  ({ dR,dG,dB });
  object fgc = s ? s->rgb_colour("titlebg") :  ({ dR,dG,dB });
  object f=Image.image(50,50,@bgc);
  f->setcolor(@fgc);
  for(int i=1; i<25; i++)
    f->line(25-i,i,25+i,i);
  return f->setcolor(255,255,255)->rotate(45)->autocrop()->scale(15,0);
}
