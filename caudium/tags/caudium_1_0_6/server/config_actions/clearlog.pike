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
constant name= "Maintenance//Clear Event Log...";
constant wizard_name= "Clear Event Log";

constant doc = ("Clear all or specified (on type) events from the Event Log.");

mixed page_0(object id)
{
  return ("<font size=+2>Select type(s) of messages to delete:</font><p>"
	  "<table><tr><td>"
	  "<var name=types type=select_multiple default='' choices='"
	  "Informational messages,Warning messages,Error messages'></td><td>"+
	  html_notice("Example Informational Message", id)+
	  html_warning("Example Warning Message", id)+
	  html_error("Example Error Message", id)+
	  "</td></tr></table>");
}

mixed wizard_done(object id)
{
  if(stringp(id->variables->types)) {
    array types=Array.map(id->variables->types/"\0",
			  lambda(string s){
      return (s[0]=='I'?1:s[0]=='W'?2:3);});
    foreach(indices(caudium->error_log), string err)
    {
      int type;
      sscanf(err, "%d,%*s", type);
      if(search(types,type) != -1) m_delete(caudium->error_log, err);
    }
    caudium->last_error = "";
    report_notice("Event log cleared by admin from "+
		  caudium->blocking_ip_to_host(id->remoteaddr)+".\n");
  }
  return http_redirect(caudium->config_url(id)+"Errors/?"+time());
}

string handle(object id)
{
  return wizard_for(id,0);
}

