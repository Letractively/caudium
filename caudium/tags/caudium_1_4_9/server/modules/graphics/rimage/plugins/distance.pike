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

constant doc = "Makes an grey-scale image, for mask-channel use. The given 'color' are used for coordinates in the color cube. Each resulting pixel is the distance from this point to the source pixel color, in the RGB color cube, squared, rightshifted 8 steps";

void render( mapping args, mapping this, string channel, object id, object m )
{
  if(!this[channel]) return;
  this[channel]=
    this[channel]->distanceq(@Colors.Colors.parse_color(args->color||"black"));
}
