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
 * Logs the User-agent fields in a separate log.
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";


array register_module()
{
  return ({ MODULE_LOGGER, 
	      "Client logger", 
	      "This is a client logger. It simply logs the 'user-agent'"
	      " field in a log somewhere, the format should be compatible "
	      "with other client loggers out there, making it somewhat useful"
	      ". It is also possible to add the clientname to the normal log,"
	      " this saves a file descriptor, but breaks some log analyzers. "
	      
	  });
}

void create()
{
  defvar("logfile", GLOBVAR(logdirprefix)+"/Clients", "Client log file", 
	 TYPE_STRING,
	 "This is the file into which all client names will be put.\n");
}

// This is a pointer to the method 'log' in the file object. For speed.
function logf;

void start()
{
  object c;
  logf=0; // Reset the old value, if any..
  if(!(c=open(query("logfile"), "wca")))
    report_error("Clientlogger: Cannot open logfile.\n");
  else
    logf = c->write;
}

void log(object id, mapping file) 
{
  logf && logf(id->client*" " + "\n");
}
