/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2001 The Caudium Group
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
 * See http://www.daviesinc.com/modules/ for more informations.
 */

#include <module.h>

inherit "module";
inherit "caudiumlib";

// #define PATHINFO_DEBUG

//! module: 404 redirector
//!  Error 404 redirector: simple MODULE_LAST that redirect to some url
//!  when no modules can handle the request.<br />Based on Chris Davies 
//!  <a href="http://www.daviesinc.com/modules/">module.</a>
//! type: MODULE_LAST
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

constant module_type = MODULE_LAST;
constant module_name = "404 redirector";
constant module_doc  = "Error 404 redirector: simple MODULE_LAST that redirect "
                       "to some url when no modules can handle the request. "
                       "<br/>Based on Chris Davies <a href=\"" 
                       "http://www.daviesinc.com/modules/\">module.</a>";
constant module_unique = 1;
constant cvs_version = "$Id$";
constant thread_safe = 1;

void create() {
  defvar ("url", "http://www.yahoo.com", "URL",
          TYPE_STRING,
          "URL to redirect to",
          );
}

mapping|int last_resort(object id)
{ 
  return http_redirect(QUERY(url));
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: url
//! URL to redirect to
//!  type: TYPE_STRING
//!  name: URL
//
