/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
 */
/*
 * $Id$
 */

//! Used to build some Environments variables for SSI / CGI

constant cvs_version = "$Id$";

#define VARQUOTE(X) replace(X,({" ","$","-","\0","="}),({"_","_", "_","","_" }))

//!  Build a mapping with standard CGI environment variables for use with
//!  CGI execution or Apache-style SSI.
//! @param f
//!  The patch of the accessed file.
//! @param id
//!  The request id object.
//! @param path_info
//!  The path info string - ie the path prepended to the actual file name.
//!  This is part of the CGI specification. In Caudium it's extracted by the
//!  PATH INFO module.
//! @note
//!  Normally this function won't be called by the user. It's not really
//!  useful outside the CGI / SSI concept since all the information is easily
//!  accessible from the request id object.
//! @returns
//!  The environment variable mapping.
//! @fixme
//!  RIS Code.
mapping build_vars(string f, object id, string path_info) {
  string addr=id->remoteaddr || "Internal";
  mixed tmp;
  object tmpid;
  mapping new = ([]);
  
  if(id->query && strlen(id->query))
    new->INDEX=id->query;
    
  if (path_info && strlen(path_info)) {
    string t, t2;
    if (path_info[0] != '/')
      path_info = "/" + path_info;
    
    t = t2 = "";
    
    // Kludge
    if (id->misc->path_info == path_info) {
      // Already extracted
      new["SCRIPT_NAME"]=id->not_query;
    } else {
      new["SCRIPT_NAME"]=id->not_query[0..strlen(id->not_query)-strlen(path_info)-1];
    }
    new["PATH_INFO"]=path_info;

    while (1) {
      // Fix PATH_TRANSLATED correctly.
      t2 = caudiump()->real_file(path_info, id);
      if (t2) {
        new["PATH_TRANSLATED"] = t2 + t;
        break;
      }
      
      tmp = path_info/"/" - ({""});
      if (tmp && !sizeof(tmp))
        break;
      path_info = "/" + (tmp[0..sizeof(tmp)-2]) * "/";
      t = tmp[-1] +"/" + t;
    }
  } else
    new["SCRIPT_NAME"]=id->not_query;

  tmpid = id;
  while (tmpid->misc->orig)
    // internal get
    tmpid = tmpid->misc->orig;
  
  // Begin "SSI" vars.
  if (sizeof(tmp = tmpid->not_query/"/" - ({""})))
    new["DOCUMENT_NAME"]=tmp[-1];
  
  new["DOCUMENT_URI"]= tmpid->not_query;
  
  if (((tmp = (tmpid->misc && tmpid->misc->stat)) ||
       (tmp = (tmpid->defined && tmpid->defines[" _stat"])) ||
       (tmpid->conf &&
       (tmp = tmpid->conf->stat_file(tmpid->not_query||"", tmpid)))))
    new["LAST_MODIFIED"]=Caudium.HTTP.date(tmp[3]);

  // End SSI vars.
    
  if (tmp = caudiump()->real_file(new["SCRIPT_NAME"], id))
    new["SCRIPT_FILENAME"] = tmp;
    
  if (tmp = caudiump()->real_file("/", id))
    new["DOCUMENT_ROOT"] = tmp;

  if (!new["PATH_TRANSLATED"])
    m_delete(new, "PATH_TRANSLATED");
  else if (new["PATH_INFO"][-1] != '/' && new["PATH_TRANSLATED"][-1] == '/')
    new["PATH_TRANSLATED"] = 
      new["PATH_TRANSLATED"][0..strlen(new["PATH_TRANSLATED"])-2];

  // HTTP_ style variables:

  mapping hdrs;

  if ((hdrs = id->request_headers)) {
    foreach (indices(hdrs) - ({ "authorization", "proxy-authorization",
                                "security-scheme", }), string h) {
      string hh = "HTTP_" + upper_case(VARQUOTE(h));      
      new[hh] = replace(hdrs[h], ({ "\0" }), ({ "" }));
    }
    
    if (!new["HTTP_HOST"]) {
      if (objectp(id->my_fd) && id->my_fd->query_address(1))
        new["HTTP_HOST"] = replace(id->my_fd->query_address(1)," ",":");
    }
  } else {
    if (id->misc->host)
      new["HTTP_HOST"]=id->misc->host;
    else if (objectp(id->my_fd) && id->my_fd->query_address(1))
      new["HTTP_HOST"]=replace(id->my_fd->query_address(1)," ",":");
    if (id->misc["proxy-connection"])
      new["HTTP_PROXY_CONNECTION"]=id->misc["proxy-connection"];
    if (id->misc->accept) {
      if (arrayp(id->misc->accept)) {
        new["HTTP_ACCEPT"]=id->misc->accept*", ";
      } else {
        new["HTTP_ACCEPT"]=(string)id->misc->accept;
      }
    }

    if (id->misc->cookies)
      new["HTTP_COOKIE"] = id->misc->cookies;
  
    if (sizeof(id->pragma))
      new["HTTP_PRAGMA"]=indices(id->pragma)*", ";

    if (stringp(id->misc->connection))
      new["HTTP_CONNECTION"]=id->misc->connection;
    
    new["HTTP_USER_AGENT"] = id->useragent; 
    
    if (id->referrer)
      new["HTTP_REFERER"] = id->referrer;
  }

  new["REMOTE_ADDR"]=addr;
    
  if (caudiump()->quick_ip_to_host(addr) != addr)
    new["REMOTE_HOST"]=caudium->quick_ip_to_host(addr);

  catch {
    if(id->my_fd) {
      new["REMOTE_PORT"] = Caudium.get_port(id->my_fd->query_address());
    }
  };
    
  if (id->misc->_temporary_query_string)
    new["QUERY_STRING"] = id->misc->_temporary_query_string;
  else
    new["QUERY_STRING"] = id->query || "";
   
  if (!strlen(new["QUERY_STRING"]))
    m_delete(new, "QUERY_STRING");
    
  if (id->realauth) 
    new["REMOTE_USER"] = (id->realauth / ":")[0];
  if (id->auth && id->auth[0])
    new["ROXEN_AUTHENTICATED"] = "1"; // User is valid with the Roxen userdb.
  
  if (id->data && strlen(id->data)) {
    if(id->misc["content-type"])
      new["CONTENT_TYPE"]=id->misc["content-type"];
    else
      new["CONTENT_TYPE"]="application/x-www-form-urlencoded";
    new["CONTENT_LENGTH"]=(string)strlen(id->data);
  }
    
  if (id->query && strlen(id->query))
    new["INDEX"]=id->query;
    
  new["REQUEST_METHOD"]=id->method||"GET";
  new["SERVER_PORT"] = id->my_fd?
    ((id->my_fd->query_address(1)||"foo unknown")/" ")[1]: "Internal";

  if(id->ssl_accept_callback)
    new["HTTPS"]="on";
    
  return new;
}

//!  Build a mapping of the Caudium extended environment variables. These
//!  include COOKIE_[cookiename], VAR_[variablename], SUPPORTS and PRESTATES.
//!  When programming CGI, using these variables can be rather handy. 
//! @param id
//!  The request id object.
//! @returns
//!  The environment variable mapping.
//! @note
//!  Normally this function won't be called by the user. It's not really
//!  useful outside the CGI / SSI concept since all the information is easily
//!  accessible from the request id object.
//! @fixme
//!  RIS code.
static mapping build_caudium_vars(object id) {
  mapping new = ([]);
  mixed tmp;

  if (id->cookies->CaudiumUserID)
    new["CAUDIUM_USER_ID"]=id->cookies->CaudiumUserID;

  new["COOKIES"] = "";
  foreach (indices(id->cookies), tmp) {
    tmp = VARQUOTE(tmp);
    new["COOKIE_"+tmp] = id->cookies[tmp];
    new["COOKIES"]+= tmp+" ";
  }
  
  foreach (indices(id->config), tmp) {
    tmp = VARQUOTE(tmp);
    new["WANTS_"+tmp]="true";
    if (new["CONFIGS"])
      new["CONFIGS"] += " " + tmp;
    else
      new["CONFIGS"] = tmp;
  }

  foreach (indices(id->variables), tmp) {
    string name = VARQUOTE(tmp);
    if (id->variables[tmp] && (sizeof(id->variables[tmp]) < 8192)) {
      /* Some shells/OS's don't like LARGE environment variables */
      new["QUERY_"+name] = replace(id->variables[tmp],"\000"," ");
      new["VAR_"+name] = replace(id->variables[tmp],"\000","#");
    }
    
    if (new["VARIABLES"])
      new["VARIABLES"]+= " " + name;
    else
      new["VARIABLES"]= name;
  }
      
  foreach (indices(id->prestate), tmp) {
    tmp = VARQUOTE(tmp);
    new["PRESTATE_"+tmp]="true";
    if (new["PRESTATES"])
      new["PRESTATES"] += " " + tmp;
    else
      new["PRESTATES"] = tmp;
  }
  
  foreach (indices(id->supports), tmp) {
    tmp = VARQUOTE(tmp);
    new["SUPPORTS_"+tmp]="true";
    if (new["SUPPORTS"])
      new["SUPPORTS"] += " " + tmp;
    else
      new["SUPPORTS"] = tmp;
  }
  return new;
}

