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

constant doc = "Write some 'text' at 'xpos', 'ypos', 'height' pixels high using 'font'. This function is intended for use on the _mask_ channel, not the image channel. The text is always white on black.";

void render( mapping args, mapping this, string channel, object id, object m)
{
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  int height = (int)args->height;
  object font = resolve_font( args->font || "default" );

  object txt = font->write( args->text || "no text" );
  if(height) txt = txt->scale(0,height);

  int xs = txt->xsize(), ys = txt->ysize();
  
  if(args->replace || !this[channel]) 
    this[channel] = Image.image( xs+xp, ys+yp );
  if(this[channel]->xsize() < xs+xp ||
     this[channel]->ysize() < xs+xp)
    this[channel]=this[channel]->copy(0,0,max(xs+xp,this[channel]->xsize()),
				      max(xs+xp,this[channel]->ysize()));

  this[channel]->paste_alpha_color( txt, 255,255,255, xp, yp );
}
