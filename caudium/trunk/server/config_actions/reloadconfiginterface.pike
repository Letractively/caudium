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

inherit "roxenlib";
constant name= "Development//Reload the configuration interface from disk";
constant doc = ("Force a reload of the configuration interface.");
constant more=1;

constant programs = ({
  "mainconfig",
  "builders",
  "wizard",
  "savers",
  "draw_things",
  "describers",
});

mixed handle(object id, object mc)
{
  if (roxen->unload_configuration_interface) {
    /* Fool the type-checker of in old Roxen's */
    mixed foo = roxen->unload_configuration_interface;
    foo();
  } else {
    /* Some backward compatibility */
    roxen->configuration_interface_obj=0;
    roxen->loading_config_interface=0;
    roxen->enabling_configurations=0;
    roxen->build_root=0;
    catch{roxen->root->dest();};
    roxen->root=0;
  }

  report_notice("Reloading the configuration interface from disk...\n");

  foreach(indices(master()->programs), string s)
    foreach(programs, string s2)
      if(search(s,s2)!=-1) {
	werror("Unloading "+s+"\n");
	m_delete(master()->programs, s);
      }

  report_notice("Configuration interface reloaded from disk.\n");
  
  return http_redirect(roxen->config_url()+"Actions/?"+time(1));
}
