/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
  string name = "client";

  array(string)|string get(string entity, object id) {
    mixed tmp;
    mixed ret = -1;
    switch(entity) {
     case "authenticated":
      //! entity: authenticated
      //!  Returns the authenticated user. If a user was sent but the
      //!  authentication was incorrect, this will be empty.
      NOCACHE();
      ret = (id->auth && id->auth[0] && id->auth[1]);
      break;
     case "fullname":
      //! entity: fullname
      //!  Returns the full user agent string, i.e. the name of the browser
      //!  and additional info like operating system and more.
      //!  E.g. "<tt>Mozilla/4.73 [en] (X11; U; Linux 2.2.16-9mdk i686)</tt>"
      NOCACHE();
      ret = id->useragent;
      break;
     case "host":
      //! entity: host
      //!  The hostname of the client, or the ip-address if it's not (yet)
      //!  resolved. 
      NOCACHE();
      ret = caudium->quick_ip_to_host(id->remoteaddr);
      break;
     case "ip":
      //! entity: ip
      //!  The ip-address of the client computer.
      NOCACHE();
      ret = id->remoteaddr;
      break;
     case "name":
      //! entity: name
      //!  The name of the client, i.e. "Mozilla/4.73". 
      NOCACHE();
      if(id->useragent) ret = (id->useragent / " " - ({""}))[0];
      break;
     case "password":
      //! entity: password
      //!  The authentication password sent to this request. Please note
      //!  that this password isn't necessarily correct.
      NOCACHE();
      ret = id->realauth && (sizeof(tmp = id->realauth/":") > 1) && tmp[1];
      break;
     case "referrer":
      //! entity: referrer
      //!  The URL of the page on which the user followed a link that
      //!  brought her to this page. The information comes from the Referrer
      //!  header sent by the browser and can't always be trusted.
      NOCACHE();
      ret = id->referrer;
      break;
     case "user":
      //! entity: user
      //!  The user sent in the authentication header to this request.
      //!  It will be available even if Caudium failed to authenticate
      //!  the user. If you want to see whether authentication succeeded,
      //!  use &amp;client.authenticated;.
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

//! entity_scope: page
//!  This scope contains information related to the current page.

class PageScope {
  inherit "scope";  
  string name = "page";

  array(string)|string get(string entity, object id) {
    mixed tmp;
    mixed ret = -4711;
    switch(entity) {
     case "filesize":
      //! entity: filesize
      //!  Returns the size in bytes of this file or -4 if the size is unknown.
      ret = id->misc->defines[" _stat"] ? id->misc->defines[" _stat"][1] : -4;
      break;
     case "true":
     case "last-true":
      //! entity: true
      //!  Returns 1 if the last statement with a conditional result (&lt;if>,
      //!  &lt;true> and &lt;false> for example) was true or 0 if it was false.
      //! entity: last-true
      //!  Roxen 2.x compatibility. Identical to &amp;page.true;.
      ret = id->misc->defines[" _ok"];
      break;
     case "path":
      //! entity: path
      //!  Return the absolute path of this file in the virtual filesystem.
      ret = id->not_query;
      break;
     case "pathinfo":
      //! entity: pathinfo
      //!  Return the "path info" part of the URL, if any. This is set by the
      //!  "Path info support" module.
      ret = id->misc->path_info||"";
      break;
     case "query":
      //! entity: query
      //!  Returns the query part for the current page.
      ret = id->query||"";
      break;
     case "realfile":
      //! entity: realfile
      //!  Returns the path to this file in the real filesysten, if available.
      ret = id->realfile||"";
      break;
     case "basename":
     case "self":
      //! entity: basename
      //!  Returns the basename, ie the file name without the path, of this
      //!  file.
      //! entity: self
      //!  Roxen 2.x compat. Identical to &amp;page.basename;
      ret = basename((id->realfile||id->not_query));
      break;
     case "dirname":
      //! entity: dirname
      //!  Returns the directory part of the current path in the virtual
      //!  filesystem.
      ret = dirname(id->not_query);
      break;
     case "realdirname":
      //! entity: realdirname
      //!  Returns the directory part of the current path in the real
      //!  filesystem, if available.
      ret = id->realfile ? dirname(id->realfile) : "";
      break;
     case "ssl-strength":
      //! entity: ssl-strength
      //!  Return the strength in bits of the current SSL connection or zero
      //!  if SSL is not used for this request.
      NOCACHE();
      if (!id->my_fd || !id->my_fd->session)
	ret = 0;
      else
	ret = id->my_fd->session->cipher_spec->key_bits;
      break;

     case "raw-url":
     case "url":
      //! entity: raw-url
      //!  The raw url of the current resource as sent to the server by
      //!  the browser. This URL is unparsed and include Caudium specific
      //!  parts like the prestate.
      //! entity: url
      //!  Roxen 2.x compatibility. Identical to &amp;page.raw-url;
      ret = id->raw_url;
      break;      
    }
    if(stringp(ret)) return ret;
    if(ret == -4711)
      return ({ "<b>Invalid entity &amp;"+name+"."+entity+";.</b>" });
    else if(intp(ret) || floatp(ret))
      return ({ (string)ret });
    return 0;
  }
}

//! entity_scope: roxen
//!  This scope is here for Roxen 2.x compatibility reasons and is identical
//!  to the &amp;caudium; scope.
//! entity_scope: caudium
//!  This scope contains information related to the current virtual
//!  server. Some entities, like &amp;caudium.uptime; relates to the server
//!  as whole, but others like &amp;caudium.requests; are specific to the
//!  current virtual server.
class CaudiumScope {
  inherit "scope";  
  
  string name;
  int ssl_strength=0;

  string create(string|void _name) {
    name = _name || "caudium"; // Allow for &roxen; compat.
    ssl_strength=40;
#if constant(SSL.constants.CIPHER_des)
    if(SSL.constants.CIPHER_algorithms[SSL.constants.CIPHER_des])
      ssl_strength=128;
    if(SSL.constants.CIPHER_algorithms[SSL.constants.CIPHER_3des])
      ssl_strength=168;
#endif /* !constant(SSL.constants.CIPHER_des) */
  }
  array(string)|string get(string entity, object id) {
    mixed tmp;
    mixed ret = -1;
    switch(entity) {
     case "uptime":
      //! entity: uptime
      //!  The uptime of the server, in seconds.
      CACHE(1);
      ret = (time(1)-caudium.start_time);
      break;
     case "uptime-days":
      //! entity: uptime-days
      //!  The uptime of the server in days.
      CACHE(3600*2);
      ret = (time(1)-caudium.start_time)/3600/24;
      break;
     case "uptime-hours":
      //! entity: uptime-hours
      //!  The uptime of the server in hours.
      CACHE(1800);
      ret = (time(1)-caudium.start_time)/3600;
      break;
     case "uptime-minutes":
      //! entity: uptime-minutes
      //!  The uptime of the server in minutes.
      CACHE(60);
      ret = (time(1)-caudium.start_time)/60;
      break;
     case "requests-per-minute":
     case "hits-per-minute":
      //! entity: hits-per-minute
      //!  Same as &amp;caudium.requests-per-minute;. Roxen 2.x compatibility.
      //! entity: requests-per-minute
      //!  The average number of requests the server has received per minute since
      //!  the last restart.
      CACHE(2);
      ret = id->conf->requests / ((time(1)-caudium.start_time)/60 + 1);
      break;
     case "hits":
     case "requests":
      //! entity: hits-per-minute
      //!  Same as &amp;caudium.requests;. Roxen 2.x compatibility.
      //! entity: requests
      //!  The number of requests the server has received since boot.
      NOCACHE();
      ret = id->conf->requests;
      break;
     case "sent-mb":
      //! entity: sent-mb
      //!  The total amount of data that has been sent, in Mebibytes.
      CACHE(10);
      ret = sprintf("%1.2f",id->conf->sent->mb());
      break;
#if constant(Gmp.mpz);
     case "sent":
      //! entity: sent-mb
      //!  The total amount of data that has been sent, in bytes.
      //!  note: Only available if Pike is compiled with the Gmp module.      
      NOCACHE();
      ret =  (int)id->conf->sent;
      break;
     case "sent-per-minute":
      //! entity: sent-per-minute
      //!  The average  amount of data that has been sent per minute, in bytes.
      //!  note: Only available if Pike is compiled with the Gmp module.      
      CACHE(2);
      ret = (int)id->conf->sent / ((time(1)-caudium.start_time)/60 || 1);
      break;
     case "sent-kbit-per-second":
      //! entity: sent-kbit-per-minute
      //!  The average  amount of data that has been sent per minute, in
      //!  kibibits,
      //!  note: Only available if Pike is compiled with the Gmp module.      
      CACHE(2);
      ret =  sprintf("%1.2f",(((int)(id->conf->sent)*8)/1024.0/
			      (time(1)-caudium.start_time || 1)));
      break;
#else
     case "sent":
     case "sent-per-minute":
     case "sent-kbit-per-second":
      ret = "Sorry, you need a Pike with Gmp-support to get this.";
      break;
#endif      
     case "ssl-strength":
      //! entity: ssl-strength
      //!  Number of bits encryption strength the SSL is capable of.
      ret = ssl_strength;
      break;
     case "pike-version":
      //! entity: pike-version
      //!  The version of Pike the webserver is running with.
      ret = fish_version;
      break;
     case "version":
      //! entity: version
      //!  The version of the Caudium webserver.
      ret = caudium.real_version;
      break;
     case "base-version":
      //! entity: base-version
      //!  The base version of the Caudium webserver excluding the build.
      ret = __caudium_version__;
      break;
     case "build":
      //! entity: build
      //!  The build version of the Caudium webserver.
      ret = __caudium_build__;
      break;
     case "time":
      //! entity: time
      //!  The current time  since the Epoch (00:00:00 UTC, January 1, 1970),
      //!  measured in seconds.
      CACHE(1);
      ret = time(1);
      break;
     case "server":
      //! entity: server
      //!  The user-configured URL for the current server.
      ret = id->conf->query("MyWorldLocation");
      break;
     case "domain":
      //! entity: domain
      //!  The hostname of the current server (i.e. the URL without http:// etc).
      tmp = id->conf->query("MyWorldLocation");
      sscanf(tmp, "%*s//%s", tmp);
      sscanf(tmp, "%s:", tmp);
      sscanf(tmp, "%s/", tmp);
      ret = tmp;
      break;
    }
    
    if(stringp(ret)) return ({ ret });
    if(ret == -1) 
      return ({ "<b>Invalid entity &amp;"+name+"."+entity+";.</b>" });
    else if(intp(ret) || floatp(ret))
      return ({ (string)ret });
  }
}

//! entity_scope: random
//!  Returns a random number from 0 to the "variable" - 1. I.e.
//!  &amp;random.100; returns a number from 0 to 99.
//! bugs:
//!  Does this break the XML-specification?

class RandomScope {
  inherit "scope";
  string name = "random";

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
  string name = "cookie";

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
  string name = "form";
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
//!  variables. In addition to allowing normal variables, i.e. &amp;var.name;, 
//!  it can store second level variables, like &amp;var.prices.banana;. This is
//!  useful if you want to group variables together. It has no predefined
//!  entities and is always empty at the beginning of a request.

class VarScope {
  inherit "scope";
  string name = "var";
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
      } else if(sub_vars[ split[0] ]) {
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
    CaudiumScope(),
    CaudiumScope("roxen"),
    PageScope()
  });
}
  
