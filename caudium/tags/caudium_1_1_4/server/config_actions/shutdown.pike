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
/*
 * $Id$
 */

inherit "wizard";
constant name= "Shutdown//Shut down Caudium...";
constant doc = ("Restart or shut down Caudium.");

string page_0(object id)
{
  return ("<font size=+1>How do you want to shut down Caudium?</font><p>"
	  "<var type=radio name=how checked value=reset> Restart Caudium<br>"
	  "<var type=radio name=how value=shutdown> Shut down Caudium "
	  "(no automatic restart)");
}

mapping wizard_done(object id)
{
  if(id->variables->how == "shutdown")
    return http_redirect(caudium->config_url(id)+"(shutdown)/Actions/");
  return http_redirect(caudium->config_url(id)+"(restart)/Actions/");
}

mixed handle(object id) { return wizard_for(id,0); }
