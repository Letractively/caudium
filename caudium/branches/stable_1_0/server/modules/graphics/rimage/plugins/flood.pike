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

constant doc="Makes an grey-scale image, for alpha-channel use. The specified channel is scannedd from the given 'x' and 'y' coordinate, filled with 255 if the color is the same, or 255 minus distance in the colorcube, squared, rightshifted 8 steps (see distance). When the edge distance is reached, the scan is stopped. Default 'edge' value is 30. This value is squared and compared with the square of the distance above.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  this[channel]=this[channel]->select_from((int)args->x,(int)args->y,(int)args->edge||30);
}
