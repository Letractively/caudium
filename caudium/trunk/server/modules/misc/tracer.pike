/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
 *
 * Ported from own Roxen module 
 * Daniel Podlejski <underley@underley.eu.org>
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

//
//! module: Session tracer
//!  This module can be used to trace pages vieved by user with 
//!  set session cookie. Module return 1x1 gif, and log date,
//!  Referer header, query string and session cookie value.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOCATION
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_LOCATION;
constant module_unique = 0;
constant module_name = "Session tracer";
constant module_doc  = "This module can be used to trace pages viewed by user with " +
			"set session cookie. Module return 1x1 gif, and log date, " +
			"Referer header, query string and session cookie value.\n";

int inited = 0;
int logok  = 0;

object logfile;
string pixel;

void start()
{
  object img;

  if (!logfile) logfile = Stdio.File();

  if (logfile->_fd) logfile->close();

  if (logfile->open(query("logfile"), "wac"))
     logok = 1;

  if (inited) return;

  inited = 1; 

  img = Image.Image(1, 1);
  pixel = Image.GIF.encode(img);
}

void create()
{
  string default_log = GLOBVAR(logdirprefix) + "Trace";

  defvar("location", "/tracer", "Mount point", TYPE_LOCATION,
	 "This is where the module will be inserted in the "
	 "name space of your server.");

  defvar("logfile", default_log, "Logfile", TYPE_STRING, 
	 "File to log users, that has set session cookie.");

  defvar("cookie", "SessionID", "Cookie name", TYPE_STRING, 
	 "Session cookie name.");
}

string status()
{
  if (logok) return "Module enabled.";
  return "Logfile open failed.";
}

string query_name()
{
  return sprintf("Tracer module mounted on <i>%s</i>", query("location"));
}

string query_location()
{
  return query("location");
}

void log_referer(string cookie, void|string query, void|string referer)
{
  if (logok) logfile->write(sprintf("%s | %s | %s | %s\n",
		Caudium.http_date(), cookie, query || "-", referer || "-"));
}

mixed find_file(string f, object id)
{
  if (id->cookies[query("cookie")])
     log_referer(id->cookies[query("cookie")],
		 id->query,
                 id->request_headers->referer);

  id->misc->moreheads = ([ "Expires": Caudium.http_date(),
                           "Pragma": "no-cache",
                           "Last-Modified": Caudium.http_date(),
                           "Cache-Control": "no-cache, must-revalidate" ]);

  return ([ "data" : pixel,
            "type" : "image/gif" ]);
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: location
//! This is where the module will be inserted in the name space of your server.
//!  type: TYPE_LOCATION
//!  name: Mount point
//
//! defvar: logfile
//! File to log users, that has set session cookie.
//!  type: TYPE_STRING
//!  name: Logfile
//
//! defvar: cookie
//! Session cookie name.
//!  type: TYPE_STRING
//!  name: Cookie name
//
