/*
 * Caudium - An extensible World Wide Web server
 * Copyright <A9> 2000 The Caudium Group
 * Copyright <A9> 1994-2000 Roxen Internet Software
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

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";

//! module: Basic Auth SSL Redirector
//! this module will check all connections for basic auth and redirect them if they are not going through ssl
//! type: MODULE_PRECACHE | MODULE_FIRST | MODULE_FILTER | MODULE_PARSER
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

constant thread_safe = 1;
constant module_name = "Basic Auth SSL Redirector";
constant module_doc = "this module will check all connections for basic auth and redirect them if they are not going through ssl";
constant module_unique = 1;
constant module_type = MODULE_PRECACHE | MODULE_FIRST | MODULE_FILTER | MODULE_PARSER;

void precache_rewrite(object id) 
{
  id->misc->redir = http_redirect( sprintf( "https://%s%s",
				      id->request_headers->host,
				      id->raw_url ));
  return;
}

mapping first_try( object id ) 
{
  if(id->realauth && !id->ssl_accept_callback) 
    return id->misc->redir;
  else
    return 0;
}

mapping filter( mapping result, object id, mapping defines)
{
  //werror("result: %O\n", result);
  if(mappingp(result) && result->extra_heads && result->extra_heads["WWW-Authenticate"] && !id->ssl_accept_callback)
    return id->misc->redir;

  id->misc["filter"]=1; 
  //werror("ssl redirect form: %O\n", id->misc);
  if(!id->ssl_accept_callback && id->misc->form)
  {
    //werror("ssl redirect form: %O\n", id->misc->form);
    return id->misc->redir;
  }
  //werror("nothing happens\n");
  return 0;
}

string container_form(string tag_name, 
                     mapping arguments, 
                     string contents, 
                     object id, 
                     mapping defines) 
{
  if(!id->ssl_accept_callback)
  {
    id->misc->defines["_extra_heads"]=id->misc->extra_heads;
    id->misc->defines["_error"]=id->misc->redir->error;
    return(sprintf("<redirect to=\"%s\" />", id->misc->redir->extra_heads->Location));
    return(sprintf("<div align=\"left\"><pre>redirect to \n%O\n failed</pre></div>", id->misc));
  }
  return 0;
}

mapping query_container_callers()
{
  return ([ "form":container_form, ]);
}

