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

constant doc = "If channel is 'image', rotates both channels in the layer by 'degree' degrees. Otherwise rotate the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  float degrees = (float)args->degrees;
  if(channel == "mask")
  {
    if(this->mask)
      this->mask = this->mask->rotate(degrees, 0,0,0);
    return;
  }

  if(!this->image)
    return;

  if(!this->mask)
    this->mask = Image.image( this->image->xsize(), 
			      this->image->ysize(),
			      255,255,255 );
  this->image = this->image->rotate_expand(degrees);
  this->mask  = this->mask->rotate( degrees, 0,0,0 );
}
