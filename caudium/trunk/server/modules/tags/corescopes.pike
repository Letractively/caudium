/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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


//! module: Standard RXML Entities
//!  This module contains all the standard entity scopes in RXML. To utilize
//!  entities, you need the XML Compliant RXML parser. It's easy to insert
//!  the value of an entity - just do &amp;scope.entity; in your RXML page.
//! type: MODULE_PARSER
//! cvs_version: $Id$

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <config.h>
#include <module.h>

inherit "module";
inherit "caudiumlib";


constant module_type = MODULE_PARSER;
constant module_name = "Standard RXML Entities";
constant module_doc  = "\
This module contains all the standard entity scopes in RXML. To utilize \
entities, you need the XML Compliant RXML parser. It's easy to insert \
the value of an entity - just do &amp;scope.entity; in your RXML page.";
constant module_unique = 1;

class ClientScope {
  inherit "scope";
  void create() {
    name = "client";
  }
  array(string)|string get(string entity, object id) {
    mixed tmp;
    switch(entity) {
    case "authenticated":
      NOCACHE();
      return (id->auth && id->auth[0] && id->auth[1]);
    case "fullname":
      NOCACHE();
      return id->useragent;
    case "host":
      NOCACHE();
      return caudium->quick_ip_to_host(id->remoteaddr);
    case "ip":
      NOCACHE();
      return id->remoteaddr;
    case "name":
      NOCACHE();
      if(id->useragent) return (id->useragent / " " - ({""}))[0];
      return 0;
    case "password":
      NOCACHE();
      return id->rawauth && (sizeof(tmp = id->rawauth/":") > 1) && tmp[1];
    case "referrer":
      NOCACHE();
      return id->referrer;
    case "user":
      return (id->rawauth  && (id->rawauth/":")[0]);
    }
    return "<b>Invalid entity &amp;client."+entity+";.</b>";
  }
}


array(object) query_scopes()
{
  return ({ ClientScope() });
}
