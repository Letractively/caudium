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

constant doc = "If channel is 'image', scale both channels in the layer by 'scale', or to the explicit 'width' and/or 'height'. If the mask is used, scale the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  if(args->width || args->height)
  {
    if(channel == "image")
    {
      if(this->mask) 
	this->mask = this->mask->scale( (int)args->width, (int)args->height );
    }
    this[channel] = this[channel]->scale( (int)args->width, (int)args->height );
    return;
  }
  
  if(args->scale)
  {
    if(channel == "image")
    {
      if(this->mask) 
	this->mask = this->mask->scale( (float)args->scale );
    }
    this[channel] = this[channel]->scale( (float)args->scale );
    return;
  }
}
