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

constant doc = "paste the 'image' slot over the current channel at xpos, ypos, using 'alpha' (defaults to solid) as a transparency mask";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  object i = id->misc[ "__pimage_"+args->image ];
  if(!i) return;
  object a = id->misc[ "__pimage_"+args->alpha ];

  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  
  if(a)
    this[channel] = this[channel]->paste_mask( i, a, xp, yp );
  else
    this[channel] = this[channel]->paste( i, xp, yp );
}
