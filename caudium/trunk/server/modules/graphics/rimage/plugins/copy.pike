/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

constant doc="Copy the contents of another channel to this channel. Supported 'source' channels are 'red' 'green' 'value' 'saturation' and 'image'";


void render( mapping args, mapping this, string channel, object id, object m )
{
  object i;
  if(!this["image"]) return;
  switch( args->source )
  {
   case "red": 
     i = this["image"]->color(255,0,0)->grey(255,0,0);
     break;
   case "green": 
     i = this["image"]->color(0,255,0)->grey(0,255,0);
     break;
   case "blue": 
     i = this["image"]->color(0,0,255)->grey(0,0,255);
     break;
   case "value": 
     i = this["image"]->grey();  
     break;
   case "saturation": 
     i = this["image"]->rgb_to_hsv()->color(0,255,0)->grey(0,255,0);
     break;
   case "image":
     i = this["image"];
  }
    this[channel] = i;
}
