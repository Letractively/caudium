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

/*
 * $Id$
 */

inherit "wizard";
constant name= "Cache//Cache status";

constant doc = ("Show hitrate of the caching system.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

mixed page_0(object id, object mc)
{
  string ret;

  ret = "<font size=\"+1\">Memory</font>";
  ret += html_border(cache->status());
  if( caudium->query("cache") )
  {
    ret += "<p><font size=\"+1\">Disk</font>";
    ret += html_border( caudium->get_garb_info(), 0, 5 );
  }
  return ret;
}

int verify_0()
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }
