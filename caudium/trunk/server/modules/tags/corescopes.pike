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

//! entity_scope: client
//!  This scope contains information related to the client on the other end
//!  of the current request. 

class ClientScope {
  inherit "scope";  
  constant name = "client";

  array(string)|string get(string entity, object id) {
    mixed tmp;
    mixed ret = -1;
    switch(entity) {
      //! entity: authenticated
      //!  Returns the authenticated user. If a user was sent but the
      //!  authentication was incorrect, this will be empty.
    case "authenticated":
      NOCACHE();
      ret = (id->auth && id->auth[0] && id->auth[1]);
      break;
      //! entity: fullname
      //!  Returns the full user agent string, i.e. the name of the browser
      //!  and additional info like operating system and more.
      //!  E.g. "<tt>Mozilla/4.73 [en] (X11; U; Linux 2.2.16-9mdk i686)</tt>"
    case "fullname":
      NOCACHE();
      ret = id->useragent;
      break;
      //! entity: host
      //!  The hostname of the client, or the ip-address if it's not (yet)
      //!  resolved. 
    case "host":
      NOCACHE();
      ret = caudium->quick_ip_to_host(id->remoteaddr);
      break;
      //! entity: ip
      //!  The ip-address of the client computer.
    case "ip":
      NOCACHE();
      ret = id->remoteaddr;
      break;
      //! entity: name
      //!  The name of the client, i.e. "Mozilla/4.73". 
    case "name":
      NOCACHE();
      if(id->useragent) ret = (id->useragent / " " - ({""}))[0];
      break;
      //! entity: password
      //!  The authentication password sent to this request. Please note
      //!  that this password isn't necessarily correct.
    case "password":
      NOCACHE();
      ret = id->realauth && (sizeof(tmp = id->realauth/":") > 1) && tmp[1];
      break;
      //! entity: referrer
      //!  The URL of the page on which the user followed a link that
      //!  brought her to this page. The information comes from the Referrer
      //!  header sent by the browser and can't always be trusted.
    case "referrer":
      NOCACHE();
      ret = id->referrer;
      break;
      //! entity: user
      //!  The user sent in the authentication header to this request.
      //!  It will be available even if Caudium failed to authenticate
      //!  the user. If you want to see whether authentication succeeded,
      //!  use &amp;client.authenticated;.
    case "user":
      NOCACHE();
      ret = (id->realauth  && (id->realauth/":")[0]);
      break;
    }
    if(ret == -1)
      return "<b>Invalid entity &amp;client."+entity+";.</b>";
    if(ret) return ({ ret });
    return 0;
  }
}

//! entity_scope: random
//!  Returns a random number from 0 to the "variable" - 1. I.e.
//!  &amp;random.100; returns a number from 0 to 99.
//! bugs:
//!  Does this break the XML-specification?

class RandomScope {
  inherit "scope";
  constant name = "random";

  array(string) get(string entity, object id) {
    NOCACHE();
    return ({ (string)random((int)entity) });
  }
}

//! entity_scope: cookie
//!  This scope provides access to cookies using the entity syntax. There are
//!  no predefined entities for this scope.
//! bugs:
//!  You can't set cookies using the &lt;set variable="cookie.name"> syntax
//!  yet.

class CookieScope {
  inherit "scope";
  constant name = "cookie";

  string get(string entity, object id) {
    NOCACHE();
    return id->cookies[entity];
  }
}


//! entity_scope: form
//!  This class provides access to all form variables sent in the request
//!  in the query string or as POST data. It is also the default scope when
//!  using &lt;set variable> and &lt;insert variable>. Since it's based on the
//!  data sent in the request, it has no predefined entities.

class FormScope {
  inherit "scope";
  constant name = "form";
  int set(string entity, mixed value, object id) {
    if(!value)
      m_delete(id->variables, entity);
    else if(catch(id->variables[entity] = (string)value))
      return 0;
    return 1;
  }
  string get(string entity, object id) {
    NOCACHE();
    return id->variables[entity];
  }
}

//! entity_scope: var
//!  This scope is to be used for storage of request specific user
//!  variables. In addition to allowing normal variables, i.e. &var.name;, 
//!  it can store second level variables, like &var.prices.banana;. This is
//!  useful if you want to group variables together. It has no predefined
//!  entities and is always empty at the beginning of a request.

class VarScope {
  inherit "scope";
  constant name = "var";
  mapping top_vars = ([]);
  mapping sub_vars = ([]);
  int set(string entity, mixed value, object id) {
    array split = entity / ".";
    switch(sizeof(split)) {
    case 1:
      if(value)
	top_vars[split[0]] = value;
      else
	m_delete(top_vars, split[0]);
      break;
    default:
      entity = split[1..] * ".";
      if(value) { 
	if(!sub_vars[ split[0] ])
	  sub_vars[ split[0] ] = ([]);
	sub_vars[ split[0] ] [ entity ] = value;
      } else {
	m_delete(sub_vars[ split[0] ], entity);
      }
      break;
    }
    return 1;
  }
  string get(string entity, object id) {
    NOCACHE();
    string value;
    array split = entity / ".";
    switch(sizeof(split)) {
    case 1:
      value = top_vars[split[0]];
      break;
    default:
      entity = split[1..] * ".";
      if(sub_vars[ split[0] ])
	value = sub_vars[ split[0] ] [ entity ];
      break;
    }
    if(!value) return 0;
    catch {
      return (string)value;
    };
    return 0;
  }

  object clone()
  {
    return object_program(this_object())();
  }    
}

array(object) query_scopes()
{
  return ({
    ClientScope(),
    CookieScope(),
    FormScope(),
    VarScope(),
    RandomScope(),
  });
}
