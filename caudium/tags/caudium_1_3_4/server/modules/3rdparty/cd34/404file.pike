/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2001-2002 The Caudium Group
 * Copyright � 2001 Davies, Inc
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
/*
 * See http://www.daviesinc.com/modules/ for more informations.
 */

#include <module.h>

inherit "module";
inherit "caudiumlib";

//#define DEBUG

#ifdef DEBUG
# define DEBUGLOG(X) werror("REFER: "+X+"\n")
#else
# define DEBUGLOG(X)
#endif

//! module: 404 file
//!  Error 404 file: simple MODULE_LAST that presents and parses a file
//!  when no modules can handle the request.<br />Based on Chris Davies 
//!  <a href="http://www.daviesinc.com/modules/">module.</a>
//! type: MODULE_LAST
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

constant module_type = MODULE_LAST;
constant module_name = "404 file";
constant module_doc  = "Error 404 file: simple MODULE_LAST that presents "
                       "and parses a file when no modules can handle the request. "
                       "<br/>Based on Chris Davies <a href=\"" 
                       "http://www.daviesinc.com/modules/\">module.</a>";
constant module_unique = 1;
constant cvs_version = "$Id$";
constant thread_safe = 1;

void create() {
  defvar ("error404document", "NONE/", "Filename",
          TYPE_STRING,
          "URL to redirect to",
          );
}

mapping|int last_resort(object id)
{ 
  string *dbinfo,html;
  dbinfo = cache_lookup("404Cache",QUERY(error404document));

  if (!(dbinfo)) {
    html = Stdio.read_bytes( QUERY(error404document) );
    DEBUGLOG("not in cache: " + QUERY(error404document));
    dbinfo = ({
      QUERY(error404document),
      html
    });
    cache_set("TemplateCache",QUERY(error404document),dbinfo,30*60);
  } else {
    DEBUGLOG("in cache: "+QUERY(error404document));
    html = dbinfo[1];
  }
  return http_string_answer(parse_rxml(html,id),"text/html");
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: url
//! URL to redirect to
//!  type: TYPE_STRING
//!  name: URL
//
