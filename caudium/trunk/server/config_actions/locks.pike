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
#include <config.h>

#ifndef THREADS
constant action_disabled = 1;
#else /* THREADS */
inherit "wizard";
constant name= "Status//Module lock status";
constant doc = ("Shows various information about the module thread locks in Caudium.");
constant more=1;

string describe_module(object q)
{
  foreach(caudium->configurations, object c)
  {
    foreach(indices(c->modules), string m)
    {
	int w;
	mapping mod = c->modules[m];
	if(mod->enabled == q)
	  return c->name+"/"+m+"</td><td>"+caudium->filename(q);
	else if(mod->copies && !zero_type(search(mod->copies,q)))
	  return (c->name+"/"+m+"#"+search(mod->copies,q)+
		  "</td><td>"+caudium->filename(q));
    }
  }
  return "Unknown module</td><td>"+caudium->filename(q)+"";
}


constant ok_label = " Refresh ";
constant cancel_label = " Done ";

int verify_0()
{
  return 1;
}

mixed page_0(object id, object mc)
{
  mapping l = ([]), locks=([]), L=([]);
  foreach(caudium->configurations, object c) {
    if (c->locked) {
      l += c->locked;
    }
    if (c->thread_safe) {
      L += c->thread_safe;
    }
  }
  mapping res=([]);
  string data=("<font size=+2>Module lock status</font><p>Accesses to all modules, "
	       "Locked means that the access was done using a serializing lock since "
	       "the module was not thread-safe, unlocked means that there was no need "
	       "for a lock.<p>Locked accesses to a single module can be a "
	       "quite severe performance degradation of the whole server, since the "
	       "module will act as a bottleneck, blocking access for all other "
	       "threads that want to access that module.<p>This is only a problem if "
	       "a significant percentage of the accesses are passed throgh that the "
	       "non-threadsafe module<p>");
  array mods = (indices(L)+indices(l));
  mods &= mods;
  foreach(mods, object q)
  {
    res[describe_module(q)]+=l[q];
    locks[describe_module(q)]+=L[q];
  }
  array rows = ({});
  foreach(sort(indices(res)), string q)
    rows += ({ ({q,(string)res[q],(string)locks[q] }) });
  return data+html_table( ({ "Config", "File", "Locked", "Unlocked" }), rows );
}

mixed handle(object id) { return wizard_for(id,0); }
#endif /* THREADS */
