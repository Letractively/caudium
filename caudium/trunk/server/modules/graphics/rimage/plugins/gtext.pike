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

inherit "caudiumlib";

constant doc = "This plugin uses the gtext module. You must have it enabled on the server. Arguments are identical to 'gtext', with one exception: 'text' is the text that should be rendered. 'xpos' and 'ypos' are the image coordinates to use.";

void render( mapping args, mapping this, string channel, object id, object m)
{
  string txt = args->text;
  int xp = (int)args->xpos;
  int yp = (int)args->xpos;
  
  m_delete(args, "xpos");
  m_delete(args, "ypos");
  string prefix = parse_rxml( make_tag("gtext-id", args), id );
  
  mapping a = ([ "file":prefix+"$"+txt, 
		 "xpos":xp,
		 "ypos":yp, ]);
  werror("file: "+prefix+"$"+txt+"\n");
  return m->plugin_for( "load" )( a, this, channel, id, m );
}
