/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

constant cvs_version = "$Id$";

object agent;
object caudium;

#include <module.h>

void create(object c)
{
  caudium=c;
  report_error("snmp agent starting on port " + GLOBVAR(snmp_port) + "\n");

  mixed err=catch(agent=Protocols.SNMP.agent((int)(GLOBVAR(snmp_port))));

  if(err)
  {
    report_error("Unable to start SNMP agent: " + err[0] + "\n");
    agent=0;
    return;
  }
  agent->set_get_communities(({GLOBVAR(snmp_get_community)}));
  agent->set_managers_only(0);
  agent->set_get_oid_callback("1.3.6.1.4.1.13047.100.1", snmp_get_server_version);
}

array snmp_get_server_version(string oid, mapping rv)
{
  return ({1, "str", caudium->real_version});
}

void destroy()
{
   report_error("Agent shutting down.");
}
