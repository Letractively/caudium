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

// Some 25% of the original RIS code remains in this file. The code lives
// in the following functions:
//
//  build_env_vars
//  decode_mode
//  is_modified (GROSS!!)
//  parse_rxml
//  msectos
//  get_size
//  do_output_tag (GROSS!!)
//  get_module
//  get_modname
//  roxen_encode

//! Caudiumlib is a collection of utility functions used by modules and
//! the Caudium core. 

// constant _cvs_version = "$Id$";
// This code has to work both in the roxen object, and in modules

#if !constant(caudium)
#define caudium caudiump()
#endif

#include <config.h>
#include <stat.h>
#include <variables.h>

#define ipaddr(x,y) (((x)/" ")[y])

#define VARQUOTE(X) replace(X,({" ","$","-","\0","="}),({"_","_", "_","","_" }))
//!   Return a response mapping which defines a redirect to the
//!   specified URL. If the URL begins with / and the ID object is present,
//!   a host name (and the prestates) will be prefixed to the URL. If the
//!   url doesn't begin with /, it won't be modified. This means that you
//!   either need a complete URL (ie http://www.somewhere.com/a/path) or an
//!   absolute url /a/path. Relative URLs won't work (ie path/index2.html).
//! @param url
//!   The URL to redirect to.
//! @param id
//!   The request id object.
//! @returns
//!   The HTTP response mapping for the redirect
mapping http_redirect( string url, object|void id )
{
  if(url[0] == '/')
  {
    if(id)
    {
      url = Caudium.add_pre_state(url, id->prestate);
      if(id->request_headers->host) {
	string p = ":80", prot = "http://";
	array h;
	if(id->ssl_accept_callback) {
	  // This is an SSL port. Not a great check, but what is one to do?
	  p = ":443";
	  prot = "https://";
	}
	h = id->request_headers->host / p  - ({""});
	if(sizeof(h) == 1)
	  // Remove redundant port number.
	  url=prot+h[0]+url;
	else
	  url=prot+id->request_headers->host+url;
      } else
	url = id->conf->query("MyWorldLocation") + url[1..];
    }
  }
#ifdef HTTP_DEBUG
  report_debug("HTTP: Redirect -> %s\n",Caudium.http_encode_string(url));
#endif  
  return Caudium.HTTP.low_answer( 302, "") 
    + ([ "extra_heads":([ "Location":Caudium.http_encode_string( url ) ]) ]);
}

//!   Returns a response mapping that tells Caudium that this request
//!   is to be streamed as-is from the specified fd-object (until there is
//!   nothing more to read). This differs from @[Caudium.HTTP.pipe_in_progress] in that
//!   this function makes Roxen read the data from the specified object and will
//!   close the connection when it's done. With @[Caudium.HTTP.pipe_in_progress] you are
//!   responsible for writing the content to the client and closing the
//!   connection. Please note that a http_stream reply also inhibits the
//!   sending of normal HTTP headers.
//! @param from
//!   The object Roxen should read data from. This can be any object that
//!   implements the correct functions - read() is _probably_ enough.
//! @returns
//!   The HTTP response mapping.
mapping http_stream(object from)
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}

//!   Returns a http authentication response mapping which will make the
//!   browser request the user for authentication information. The optional
//!   message will be used as the body of the page. 
//! @param realm
//!   The realm of this authentication. This is show in various methods by the
//!   authenticating browser.
//! @param message
//!   An option message which defaults to a simple "Authentication failed.".
//! @param dohtml
//!   An option to make it HTML formated.
//! @returns
//!   The HTTP response mapping.
mapping http_auth_required(string realm, string|void message, void|int dohtml)
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";

  if (dohtml)
      message = Caudium.HTTP.make_htmldoc_string(message, "Caudium: Authentication failed");
  
#ifdef HTTP_DEBUG
  report_debug("HTTP: Auth required (%s)\n",realm);
#endif  
  return Caudium.HTTP.low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

//!   Returns a http proxy authentication response mapping which will make the
//!   browser request the user for authentication information for use with
//!   a proxy. This is different than the normal auth in that it's meant for
//!   proxies only. The optional message will be used as the body of the page. 
//! @param realm
//!   The realm of this authentication. This is show in various methods by the
//!   authenticating browser.
//! @param message
//!   An option message which defaults to a simple "Authentication failed.".
//! @returns
//!   The HTTP response mapping.
mapping http_proxy_auth_required(string realm, void|string message)
{
#ifdef HTTP_DEBUG
  report_debug("HTTP: Proxy auth required (%s)\n",realm);
#endif  
  if(!message)
    message = "<h1>Proxy authentication failed.\n</h1>";
  return Caudium.HTTP.low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

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
static mapping build_env_vars(string f, object id, string path_info)
{
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
      t2 = caudium->real_file(path_info, id);
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
    
  if (tmp = caudium->real_file(new["SCRIPT_NAME"], id))
    new["SCRIPT_FILENAME"] = tmp;
    
  if (tmp = caudium->real_file("/", id))
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
    
  if (caudium->quick_ip_to_host(addr) != addr)
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
static mapping build_caudium_env_vars(object id)
{
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

//!  Return a textual description of the file mode.
//! @param m
//!  The file mode to decode.
//! @returns
//!  The mode described as a string.
//!  Example result: File, &lt;tt&gt;rwxr-xr--&lt;tt&gt;
static string decode_mode(int m)
{
  string s;
  s="";
  
  if (S_ISLNK(m))
    s += "Symbolic link";
  else if(S_ISREG(m))
    s += "File";
  else if(S_ISDIR(m))
    s += "Dir";
  else if(S_ISSOCK(m))
    s += "Socket";
  else if(S_ISCHR(m))
    s += "Special";
  else if(S_ISBLK(m))
    s += "Device";
  else if(S_ISFIFO(m))
    s += "FIFO";
  else if((m&0xf000)==0xd000)
    s+="Door";
  else
    s+= "Unknown";
  
  s+=", ";
  
  if (S_ISREG(m) || S_ISDIR(m)) {
    s+="<tt>";
    if (m&S_IRUSR)
      s+="r";
    else
      s+="-";
    
    if (m&S_IWUSR)
      s+="w";
    else
      s+="-";
    
    if (m&S_IXUSR)
      s+="x";
    else
      s+="-";
    
    if (m&S_IRGRP)
      s+="r";
    else
      s+="-";
    
    if (m&S_IWGRP)
      s+="w";
    else
      s+="-";
    
    if (m&S_IXGRP)
      s+="x";
    else
      s+="-";
    
    if (m&S_IROTH)
      s+="r";
    else
      s+="-";
    
    if (m&S_IWOTH)
      s+="w";
    else
      s+="-";
    
    if (m&S_IXOTH)
      s+="x";
    else
      s+="-";
    
    s+="</tt>";
  } else {
    s+="--";
  }
  return s;
}

//!  Internal glob matching function.
//! @param w
//!  String to match.
//! @param a
//!  Glob patterns to match against the string.
//! @returns
//!  1 if a match occured, -1 if the string to match is invalid, 0 if
//!  no match occured.
static int _match(string w, array (string) a)
{
  string q;
  if (!stringp(w)) // Internal request..
    return -1;
  foreach (a, q) 
    if (stringp(q) && strlen(q) && glob(q, w)) 
      return 1; 
}

//!  This function performs a check to see if the specified time
//!  is newer or older than the Is-Modified-Since header sent in the request.
//!  It also checks whether the size of the file has changed since the
//!  browser first requested it.
//! @param a
//!  The value of the Is-Modified-Since header .
//! @param t
//!  The modification time of the file.
//! @param len
//!  Optional length of the requested resource.
//! @returns
//!  0 if the file is modified, 1 if it isn't.
//! @note
//!  It's somewhat confusing that it returns 1 for "not modified" and
//!  0 for modified. Should be the other way around.
//! @bugs
//!  There has previously been bugs with this function. Is it fixed?
static int is_modified(string a, int t, void|int len)
{
  mapping t1;
  int day, year, month, hour, minute, second, length;
  string m, extra;
  if (!a)
    return 1;
  t1=gmtime(t);
  // Expects 't' as returned from time(), not UTC.
  sscanf(lower_case(a), "%*s, %s; %s", a, extra);
  if (extra && sscanf(extra, "length=%d", length) && len && length != len)
    return 0;

  if (search(a, "-") != -1) {
    sscanf(a, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second);
    year += 1900;
    month=Caudium.Const.MONTHS[m];
  } else if (search(a, ",") == 3) {
    sscanf(a, "%*s, %d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    if (year < 1900)
      year += 1900;
    month=Caudium.Const.MONTHS[m];
  } else if (!(int)a) {
    sscanf(a, "%*[^ ] %s %d %d:%d:%d %d", m, day, hour, minute, second, year);
    month=Caudium.Const.MONTHS[m];
  } else {
    sscanf(a, "%d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    month=Caudium.Const.MONTHS[m];
    if(year < 1900)
      year += 1900;
  }

  //gross!!!!!
  if (year < (t1["year"]+1900))
    return 0;
  else if (year == (t1["year"]+1900))
    if (month < (t1["mon"]))
      return 0;
    else if (month == (t1["mon"]))
      if (day < (t1["mday"]))
        return 0;
      else if (day == (t1["mday"]))
        if (hour < (t1["hour"]))
          return 0;
        else if(hour == (t1["hour"]))
          if (minute < (t1["min"]))
            return 0;
          else if (minute == (t1["min"]))
            if (second < (t1["sec"]))
              return 0;
  return 1;
}

//!  Returns a "short name" of a virtual server. This is simply
//!  the name in lower case with space replaced with underscore.
//!  used for storing the configration on disk, log directories etc.
//! @param long_name
//!  The name of the virtual server.
string short_name(string long_name)
{
  long_name = replace(long_name, " ", "_");
  return lower_case(long_name);
}

//!  Strips the Caudium config cookie part of a path (not the URL).
//!  The cookie part is everything within &lt; and > right after the first
//!  slash.
//! @param from
//!  The path from which the cookie part will be stripped.
string strip_config(string from)
{
  sscanf(from, "/<%*s>%s", from);
  return from;
}

//!  Strips the Caudium prestate part of a path (not the URL).
//!  The prestate part is everything within ( and ) right after the first
//!  slash.
//! @param from
//!  The path from which the prestate part will be stripped.
string strip_prestate(string from)
{
  sscanf(from, "/(%*s)%s", from);
  return from;
}

#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]

//!  Run the RXML parser on a text string. This function is to be used if you
//!  explicitely want to parse some text. It's commonly used in custom modules
//!  or pike scripts.
//! @param what
//!  The text to parse
//! @param id
//!  The request object.
//! @param file
//!  File object, which is sent as the second custom argument to all callback
//!  functions.
//! @param defines
//!  The mapping with defines, sent as another optional argument to callback
//!  functions. It defaults to id->misc->defines.
//! @returns
//!  The RXML parsed result.
static string parse_rxml(string what, object id,
                         void|object file, void|mapping defines)
{
  if (!id)
    error("No id passed to parse_rxml\n");

  if (!defines) {
    defines = id->misc->defines||([]);
    if (!_error)
      _error=200;
    if (!_extra_heads)
      _extra_heads=([ ]);
  }

  if (!id->conf || !id->conf->parse_module)
    return what;
  
  what = id->conf->parse_module->
    do_parse(what, id, file||this_object(), defines, id->my_fd);

  if (!id->misc->moreheads)
    id->misc->moreheads= ([]);
  id->misc->moreheads |= _extra_heads;
  
  id->misc->defines = defines;

  return what;
}

//!  Converts html entity coded chars to unicode
//! @param str
//!  The string to convert, contains the html entities
//! @returns
//!  a unicode string
string html_to_unicode( string str ) {
  return replace((string) str, Caudium.Const.replace_entities, Caudium.Const.replace_values );
}

//!  Converts unicode string to html entity coded string
//! @param str
//!  The string to convert, contains unicode string
//! @returns
//!  html encoded string
string unicode_to_html( string str ) {
  return replace((string) str, Caudium.Const.replace_values, Caudium.Const.replace_entities );
}

private constant safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"/"";
private constant empty_strings = ({
  "","","","","","","","","","","","","","","","","","","","","","","","","",
  "","","","","","","","","","","","","","","","","","","","","","","","","",
  "","","","","","","","","","","","",
});

//!  Check if a string contains only safe characters, which are defined as
//!  a-z, A-Z and 0-9. Mainly used internally by make_tag_attributes.
//! @param in
//!  The string to check.
//! @returns
//!  1 if the test contains only the safe characters, 0 otherwise.
static int is_safe_string(string in)
{
  return strlen(in) && !strlen(replace(in, safe_characters, empty_strings));
}

//!  Convert a mapping with key-value pairs to tag attribute format.
//! @param in
//!  The mapping with the attributes
//! @returns
//!  The string of attributes.
static string make_tag_attributes(mapping in)
{
  array a=indices(in), b=values(in);

  for (int i=0; i<sizeof(a); i++)
    if (lower_case(b[i]) != a[i])
      if (is_safe_string(b[i]))
        a[i]+="=\"" +b[i] + "\"";
      else
        // Bug inserted again. Grmbl.
        a[i]+="=\""+replace(b[i], ({ "\"", "<", ">" //, "&"
        }) ,
                            ({ "&quot;", "&lt;", "&gt;" //, "&amp;"
                            }))+"\"";
  return a*" ";
}

//!  Build a tag with the specified name and attributes.
//! @param tag
//!  The name of the tag.
//! @param in
//!  The mapping with the attributes
//! @returns
//!  A string containing the tag with attributes.
static string make_tag(string tag,mapping in)
{
  string q = make_tag_attributes(in);
  return "<"+tag+(strlen(q)?" "+q:"")+">";
}

//!  Build a container with the specified name, attributes and content.
//! @param tag
//!  The name of the container.
//! @param in
//!  The mapping with the attributes
//! @param contents
//!  The contents of the container.
//! @returns
//!  A string containing the finished container
static string make_container(string tag,mapping in, string contents)
{
  return make_tag(tag,in)+contents+"</"+tag+">";
}

static string add_config( string url, array config, multiset prestate )
{
  if (!sizeof(config)) 
    return url;
  
  if (strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  
  return "/<" + config * "," + ">" + Caudium.add_pre_state(url, prestate);
}

//! Converts miliseconds to seconds
//!
//! @param t
//!  Number of miliseconds.
//!
//! @returns
//!  A string representation of the passed value converted to seconds.
string msectos(int t)
{
  if(t<1000) { /* One sec. */
    return sprintf("0.%02d sec", t/10);
  } else if(t<6000) {  /* One minute */
    return sprintf("%d.%02d sec", t/1000, (t%1000 + 5) / 10);
  } else if(t<3600000) { /* One hour */
    return sprintf("%d:%02d m:s", t/60000,  (t%60000)/1000);
  }
  
  return sprintf("%d:%02d h:m", t/3600000, (t%3600000)/60000);
}

//! Gets the backup extension
//! 
//! @note
//!   RIS code ?
//!
//! @fixme
//!   Is this usefull ???
static int backup_extension( string f )
{
  if (!strlen(f)) 
    return 1;
  
  return (f[-1] == '#' || f[-1] == '~' 
          || (f[-1] == 'd' && sscanf(f, "%*s.old")) 
          || (f[-1] == 'k' && sscanf(f, "%*s.bak")));
}

//! Calculates the size (memory) usage of some element
//!
//! @param x
//!  Anything you want to measure the memory usage for.
//!
//! @returns
//!  Memory usage of the argument
int get_size(mixed x)
{
  if (mappingp(x))
    return 8 + 8 + get_size(indices(x)) + get_size(values(x));
  else if (stringp(x))
    return strlen(x)+8;
  else if (arrayp(x)) {
    mixed f;
    int i;
    foreach(x, f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if (multisetp(x)) {
    mixed f;
    int i;
    foreach(indices(x), f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if (objectp(x) || functionp(x)) {
    return 8 + 16; // (refcount + pointer) + object struct.
    // Should consider size of global variables / refcount 
  }
  return 20; // Ints and floats are 8 bytes, refcount and float/int.
}

//!
static int ipow(int what, int how)
{
  int r=what;
  if (!how)
    return 1;
  
  while (how-=1)
    r *= what;
  
  return r;
}

//! Simplifies the path by removing any relative elements in the middle of
//! it (like @tt{../.@} etc.
//!
//! @param file
//!  The path to be simplified
//!
//! @returns
//!  The simplified path string.
//!
//! @note
//!   Non-RIS code
static string simplify_path(string file)
{
  string   ret;
  mixed    error = catch {
    ret = Stdio.simplify_path(file);
  };

  if (!error)
    return ret;
  
  return file; // better to return the original than 0
}

//! Returns a short date string from a time @tt{int@}
//!
//! @param timestamp
//!  The UNIX time value to convert.
//!
//! @returns
//!  String representation of the param
//!
//! @note
//!  Non-RIS code
static string short_date(int timestamp)
{
  int      date = time(1);
  string   ctimed = ctime(date)[20..23];
  string   ctimet = ctime(timestamp);
  
  if ( ctimed < ctimet[20..23])
    return ctimet[4..9] +" "+ ctimet[20..23];
  
  return ctimet[4..9] +" "+ ctimet[11..15];
}

//! Converts a string representing a HTTP date into a UNIX time value.
//!
//! @param date
//!  The date string to be converted
//!
//! @returns
//!  The UNIX time value for the date.
//!
//! @note
//!   Non-RIS implementation;
int httpdate_to_time(string date)
{     
  if (intp(date))
    return -1;

  int   ret;
  mixed error = catch {
    ret = Calendar.parse("%e, %a %M %Y %h:%m:%s %z", date)->unix_time();
  };

  if (error) {
    report_error("httpdate_to_time error: %O", error);
    return -1;
  }
  
  return ret;
}

//! Converts an integer into a Roman digit
//!
//! @param m
//!  The integer to be converted
//!
//! @returns
//!  A string representing the Roman equivalent of the passed integer.
//!
//! @note
//!  Non-RIS implementation
static string int2roman(int m)
{
  if (m>10000||m<0)
    return "que";

  mixed   error;
  string  ret;

  error = catch {
    ret = String.int2roman(m);
  };

  if (error)
    return "que";

  return ret;
}

//! Converts an integer number into a string
//!
//! @param num
//!  Integer to be converted
//!
//! @param params
//!  Mapping with parameters. Currently known parameters are:
//!
//!   @mapping
//!     @member string "type"
//!       Type of the returned string. Can be either of:
//!         @dl
//!           @item string
//!             A normal string representation of the integer. See below
//!             for the description of additional options available through
//!             the @tt{names@} parameter.
//!           @item roman
//!             A Roman representaion of the integer.
//!         @enddl
//!
//!     @member mixed "lower"
//!       If present, the resulting string will be all in lower case.
//!
//!     @member mixed "upper"
//!       If present, the resulting string will be all in upper case.
//!
//!     @member mixed "capitalize"
//!       If present, the resulting string will be capitalized.
//!   @endmapping
//!
//! @param names
//!  If the string type was chosen this parameter can be used to convert
//!  digits into their string representation in two ways. If mixed is a
//!  @tt{function@} then it will be called with the integer as a parameter
//!  and it is supposed to return a string representing the integer. If, on
//!  the other hand, this parameter is an array then each array element
//!  represents a name for the digit corresponding to its position in the
//!  array.
//!
//! @returns
//!  String representation of the passed integer.
//!
//! @note
//!  Non-RIS implementation
static string number2string(int num ,mapping params, mixed names)
{
  string ret;
  
  switch (params->type) {
      case "string":
        if (functionp(names)) {
          ret = names(num);
          break;
        }
        
        if (!arrayp(names) || num < 0 || num >= sizeof(names))
          ret = "";
        else
          ret = names[num];
        break;
        
      case "roman":
        ret = int2roman(num);
        break;
        
      default:
        return (string)num;
  }
  
  if (params->lower)
    return lower_case(ret);
  
  if (params->upper)
    return upper_case(ret);
  
  if (params->cap || params->capitalize)
    return String.capitalize(ret);
  
  return ret;
}

static mapping(string:string) ift = ([
  "unknown" : "internal-gopher-unknown",
  "audio" : "internal-gopher-sound",
  "sound" : "internal-gopher-sound",
  "image" : "internal-gopher-image",
  "application" : "internal-gopher-binary",
  "text" : "internal-gopher-text"
]);

//! Gets image from type
//! @note
//!   non-RIS code
//! @fixme
//!   Undocumented.
static string image_from_type(string t)
{
  if (t) {
    sscanf(t, "%s/%*s", t);

    if (ift[t])
      return ift[t];
  }
  
  return ift->unknown;
}

static array(string) size_prefix = ({ "bytes", "kB", "MB", "GB", "TB", "HB" });

static string sizetostring(int size)
{
  float s = (float)size;
  if (size < 0.0)
    return "--------";
  
  size=0;

  while( s > 1024.0 ) {
    s /= 1024.0;
    size++;
  }
  
  return sprintf("%.1f %s", s, size_prefix[size]);
}

//! Used for proxy
//! @fixme
//!  Should be in Caudium.HTTP module
mapping proxy_auth_needed(object id)
{
  mixed res = id->conf->check_security(proxy_auth_needed, id);
  if (res) {
    if (res==1) // Nope...
      return Caudium.HTTP.low_answer(403, "Access to this proxy has been denied.");

    if (!mappingp(res))
      return 0;
    
    res->error = 407;
    
    return res;
  }
  
  return 0;
}

string program_filename()
{
  return caudium->filename(this_object()) ||
    search(master()->programs, object_program(this_object()));
}

string program_directory()
{
  array(string) p = program_filename()/"/";
  return (sizeof(p)>1? p[..sizeof(p)-2]*"/" : getcwd());
}

//! Encodes str for use as a value in an html tag.  
//!
//! @param str
//!   String to encode
string html_encode_tag_value(string str)  
{  
   return "\"" + replace(str, ({"&", "\""}), ({"&amp;", "&quot;"})) + "\"";  
}

//! This function exist to aid in finding a module object identified by the
//! passed module name.
//!
//! @param modname
//!  Name of the requested module.
//!
//! @returns
//!  The corresponding module object (if any)
object get_module (string modname)
{
  string cname, mname;
  int mid = 0;

  if (sscanf (modname, "%s/%s", cname, mname) != 2 ||
      !sizeof (cname) || !sizeof(mname)) return 0;
  sscanf (mname, "%s#%d", mname, mid);

  foreach (caudium->configurations, object conf) {
    mapping moddata;
    if (conf->name == cname && (moddata = conf->modules[mname])) {
      if (mid >= 0) {
        if (moddata->copies)
          return moddata->copies[mid];
      } else if (moddata->enabled)
        return moddata->enabled;
      
      if (moddata->master)
        return moddata->master;
      return 0;
    }
  }

  return 0;
}

//!   Given a copy of a Caudium module object create a uniquely identifying
//!   for that object. Along the lines of localhost/filesystem#copy
//! @param module
//!   An object containing an active caudium module (probably this_object()
//!   from inside a modules namespace).
//! @returns
//!   A unique name string.
string get_modname (object module)
{
  if (!module)
    return 0;

  foreach (caudium->configurations, object conf) {
    string mname = conf->otomod[module];
    if (mname) {
      mapping moddata = conf->modules[mname];
      if (moddata)
        if (moddata->copies)
          foreach (indices (moddata->copies), int i) {
            if (moddata->copies[i] == module)
              return conf->name + "/" + mname + "#" + i;
          } else if (moddata->master == module || moddata->enabled == module)
            return conf->name + "/" + mname + "#0";
    }
  }

  return 0;
}

//! This determines the full module name in approximately the same way
//! as the config UI.
//!
//! @param module
//!  Module object whos name is needed.
//!
//! @returns
//!  The module name
string get_modfullname (object module)
{
  if (module) {
    string name = 0;
    if (module->query_name)
      name = module->query_name();
    
    if (!name || !sizeof (name))
      name = module->register_module()[1];
    return name;
  } else
    return 0;
}

//! Quote content in a multitude of ways. Used primarily by do_output_tag
//!
//! @param val
//!  Value to encode.
//!
//! @param encoding
//!  Desired string encoding on return:
//!
//!  @dl
//!    @item none
//!      Returns the value verbatim
//!    @item http
//!      HTTP encoding.
//!    @item cookie
//!      HTTP cookie encoding
//!    @item url
//!      HTTP encoding, including special characters in URLs
//!    @item html
//!      For generic html text and in tag arguments. Does
//!      not work in RXML tags (use dtag or stag instead)
//!    @item dtag
//!      Quote quotes for a double quoted tag argument. Only
//!      for internal use, i.e. in arguments to other RXML tags
//!    @item stag
//!      Quote quotes for a single quoted tag argument. Only
//!      for internal use, i.e. in arguments to other RXML tags
//!    @item pike
//!      Pike string quoting (e.g. for use in the &lt;pike&gt; tag)
//!    @item js|javascript
//!      Javascript string quoting
//!    @item mysql
//!      MySQL quoting
//!    @item mysql-dtag
//!      MySQL quoting followed by dtag quoting
//!    @item mysql-pike
//!      MySQL quoting followed by Pike string quoting
//!    @item sql|oracle
//!      SQL/Oracle quoting
//!    @item sql-dtag/oracle-dtag
//!      SQL/Oracle quoting followed by dtag quoting
//!  @enddl
//!
//! @returns
//!  The encoded string
string roxen_encode( string val, string encoding )
{
  switch (encoding) {
      case "none":
      case "":
        return val;
   
      case "http":
        // HTTP encoding.
        return Caudium.http_encode_string (val);
     
      case "cookie":
        // HTTP cookie encoding.
        return Caudium.http_encode_cookie (val);
     
      case "url":
        // HTTP encoding, including special characters in URL:s.
        return Caudium.http_encode_url (val);
       
      case "html":
        // For generic html text and in tag arguments. Does
        // not work in RXML tags (use dtag or stag instead).
        return _Roxen.html_encode_string (val);
     
      case "dtag":
        // Quote quotes for a double quoted tag argument. Only
        // for internal use, i.e. in arguments to other RXML tags.
        return replace (val, "\"", "\"'\"'\"");
     
      case "stag":
        // Quote quotes for a single quoted tag argument. Only
        // for internal use, i.e. in arguments to other RXML tags.
        return replace(val, "'", "'\"'\"'");
       
      case "pike":
        // Pike string quoting (e.g. for use in a <pike> tag).
        return replace (val,
                        ({ "\"", "\\", "\n" }),
                        ({ "\\\"", "\\\\", "\\n" }));

      case "js":
      case "javascript":
        // Javascript string quoting.
        return replace (val,
                        ({ "\b", "\014", "\n", "\r", "\t", "\\", "'", "\"" }),
                        ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
                           "\\'", "\\\"" }));
       
      case "mysql":
        // MySQL quoting.
        return replace (val,
                        ({ "\"", "'", "\\" }),
                        ({ "\\\"" , "\\'", "\\\\" }) );
       
      case "sql":
      case "oracle":
        // SQL/Oracle quoting.
        return replace (val, "'", "''");
       
      case "mysql-dtag":
        // MySQL quoting followed by dtag quoting.
        return replace (val,
                        ({ "\"", "'", "\\" }),
                        ({ "\\\"'\"'\"", "\\'", "\\\\" }));
       
      case "mysql-pike":
        // MySQL quoting followed by Pike string quoting.
        return replace (val,
                        ({ "\"", "'", "\\", "\n" }),
                        ({ "\\\\\\\"", "\\\\'",
                           "\\\\\\\\", "\\n" }) );
       
      case "sql-dtag":
      case "oracle-dtag":
        // SQL/Oracle quoting followed by dtag quoting.
        return replace (val,
                        ({ "'", "\"" }),
                        ({ "''", "\"'\"'\"" }) );
       
      default:
        // Unknown encoding. Let the caller decide what to do with it.
        return 0;
  }
}

// This method needs lot of work... but so does the rest of the system too
// RXML needs types
private int compare( string a, string b ) // what a mess!
{
  if (!a)
    if (b)
      return -1;
    else
      return 0;
  else if (!b)
    return 1;
  else if ((string)(int)a == a && (string)(int)b == b)
    if ((int )a > (int )b)
      return 1;
    else if ((int )a < (int )b)
      return -1;
    else
      return 0;
  else
    if (a > b)
      return 1;
    else if (a < b)
      return -1;
    else
      return 0;
}

//! method for use by tags that replace variables in their content, like
//! formoutput, sqloutput and others
//!
//! @param args
//!  Arguments that influence the way the output tag does its job.
//!
//!    @mapping
//!      @member string "quote"
//!       The placeholder value quoting character. Defaults to @tt{#@}
//!      @member mixed "preprocess"
//!       If present, the passed contents string is parsed using
//!       @[parse_rxml()] before replacing the placeholders.
//!      @member string "debug-input"
//!       If present and set to one of the supported values, this attribute
//!       allows the programmer to see some debugging output. Supported
//!       values:
//!
//!         @dl
//!           @item log
//!            Debugging information is sent to the default caudium log.
//!           @item comment
//!            Debugging information is sent to the browser in form of a
//!            HTML comment.
//!           @item any_other_value
//!            The debugging info is presented as a bold, preformated text
//!            between the square brackets.
//!         @enddl
//!
//!      @member string "sort"
//!       The array of variables is sorted relatively to the passed,
//!       comma-separated, list of values.
//!
//!      @member string "range"
//!       Only the variables from the passed array enclosed in the given
//!       range (using the @code{X..Y@} syntax) are used for the
//!       output.
//!
//!      @member string "replace"
//!       If absent, or its value is different than "no", the tag will
//!       perform the actual replacement. Each variable can have a number
//!       of options attached to it. The options are attached by using the
//!       syntax presented below:
//!
//!        @code{
//!          #variable:option=value:option=value#
//!        @}
//!
//!        The @tt{#@} character above is, in reality, the value of
//!        @tt{args->quote@} and is the default quoting
//!        character. Available options are presented below:
//!
//!          @dl
//!           @item empty
//!             The value given to variables that have no value
//!             assigned. See also @[args->empty].
//!           @item zero
//!             The value assigned to the variables that are
//!             uninitialized. See also @[args->zero].
//!           @item multisep|multi_separator
//!             Separator for variables whose content is a list. The
//!             variable value will be divided on this string.
//!           @item quote
//!             The quote character to be used for the given variable
//!             only. See also @[args->quote].
//!           @item encode
//!             The encoding for the given variable only.
//!          @enddl
//!
//!       @member string "zero"
//!         The default value returned for all variables which aren't
//!         initialized.
//!
//!       @member string "empty"
//!         The default value returned for all variables which have no
//!         value assigned.
//!
//!       @member string "delimiter"
//!         A string put after each replaced variable.
//!    @endmapping
//!
//! @param var_arr
//!   An array of mappings describing all the variables that can be
//!   replaced. Each mapping index is the name of a quoted variable in the
//!   passed contents. For example, if the passed mapping contains an index
//!   called 'test' then its corresponding variable in the contents string
//!   (assuming the default @tt{#@} quote character is used) will be
//!   @tt{#test@}.
//!
//! @param contents
//!   The contents of the that called this function container.
//!
//! @param id
//!   The request id.
//!
//! @example
//! //
//! // a simple tag that outputs a list of parts of 'something'
//! // it defines an array of mappings containing two indexes:
//! //  'url' and 'name'. The sample usage of the container is:
//! //
//! // <show_parts><a href='#url#'>#name#</a></show_parts>
//! //
//! array(string) show_parts(string tag, mapping args, string
//!                          contents, object id, mapping defines) {
//!   array(mapping)   rep = ({});
//!   int              i = 0;
//!
//!   foreach(configs, mapping cfg) {
//!       mapping nmap = ([]);
//!
//!       nmap->url = sprintf("%s(showpart)/?name=%d",
//!                         id->conf->query("MyWorldLocation"),
//!                         i);
//!       nmap->name = sprintf("Part %d", i++);
//!       rep += ({nmap});
//!   }
//!
//!   return ({ do_output_tag(args, rep, contents, id) });
//! }
//!
//! @returns
//!  Contents with all the variables found in @[var_arr] replaced with
//!  their values.
string do_output_tag( mapping args, array (mapping) var_arr, string contents,
                      object id )
{
  string quote = args->quote || "#";
  mapping other_vars = id->misc->variables;
  string new_contents = "", unparsed_contents = "";
  int first;

  // multi_separator must default to \000 since one sometimes need to
  // pass multivalues through several output tags, and it's a bit
  // tricky to set it to \000 in a tag..
  string multi_separator = args->multi_separator || args->multisep || "\000";

  if (args->preprocess)
    contents = parse_rxml( contents, id );

  switch (args["debug-input"]) {
      case 0:
        break;
        
      case "log":
        report_debug ("tag input: %s\n", contents);
        break;
        
      case "comment":
        new_contents = "<!--\n" + _Roxen.html_encode_string (contents) + "\n-->";
        break;
        
      default:
        new_contents = "\n<br><b>[</b><pre>" +
          _Roxen.html_encode_string (contents) + "</pre><b>]</b>\n";
  }

  if (args->sort) {
    array order;

    order = args->sort / "," - ({ "" });
    var_arr = Array.sort_array( var_arr,
                                lambda (mapping m1, mapping m2, array order)
                                {
                                  int tmp;

                                  foreach (order, string field)
                                  {
                                    int tmp;
            
                                    if (field[0] == '-')
                                      tmp = compare( m2[field[1..]],
                                                     m1[field[1..]] );
                                    else if (field[0] == '+')
                                      tmp = compare( m1[field[1..]],
                                                     m2[field[1..]] );
                                    else
                                      tmp = compare( m1[field], m2[field] );
                                    if (tmp == 1)
                                      return 1;
                                    else if (tmp == -1)
                                      return 0;
                                  }
                                  return 0;
                                }, order );
  }

  if (args->range) {
    int begin, end;
    string b, e;
    

    sscanf( args->range, "%s..%s", b, e );
    if (!b || b == "")
      begin = 0;
    else
      begin = (int )b;

    if (!e || e == "")
      end = -1;
    else
      end = (int )e;

    if (begin < 0)
      begin += sizeof( var_arr );

    if (end < 0)
      end += sizeof( var_arr );

    if (begin > end)
      return "";

    if (begin < 0)
      if (end < 0)
        return "";
      else
        begin = 0;
    var_arr = var_arr[begin..end];
  }

  first = 1;
  foreach (var_arr, mapping vars) {
    if (args->set)
      foreach (indices (vars), string var) {
        mixed val = vars[var];
        if (!val)
          val = args->zero || "";
        else {
          if (arrayp( val ))
            val = Array.map (val, lambda (mixed v) {return (string) v;}) *
              multi_separator;
          else
            val = replace ((string) val, "\000", multi_separator);
          if (!sizeof (val)) val = args->empty || "";
        }
        
        id->variables[var] = val;
      }

    id->misc->variables = vars;

    if (!args->replace || lower_case( args->replace ) != "no") {
      array exploded = contents / quote;
      if (!(sizeof (exploded) & 1))
        return "<b>Contents ends inside a replace field</b>";

      for (int c=1; c < sizeof( exploded ); c+=2)
        if (exploded[c] == "")
          exploded[c] = quote;
        else {
          array(string) options =  exploded[c] / ":";
          string var = String.trim_all_whites(options[0]);
          mixed val = vars[var];
          array(string) encodings = ({});
          string multisep = multi_separator;
          string zero = args->zero || "";
          string empty = args->empty || "";

          foreach (options[1..], string option) {
            array (string) pair = option / "=";
            string optval = String.trim_all_whites (pair[1..] * "=");

            switch (lower_case (String.trim_all_whites( pair[0] ))) {
                case "empty":
                  empty = optval;
                  break;
                  
                case "zero":
                  zero = optval;
                  break;
                  
                case "multisep":
                case "multi_separator":
                  multisep = optval;
                  break;
                  
                case "quote": // For backward compatibility.
                  optval = lower_case (optval);
                  switch (optval) {
                      case "mysql": case "sql": case "oracle":
                        encodings += ({optval + "-dtag"});
                        break;
                        
                      default:
                        encodings += ({optval});
                  }
                  break;
                  
                case "encode":
                  encodings += Array.map (lower_case (optval) / ",",
                                          String.trim_all_whites);
                  break;
                  
                default:
                  return "<b>Unknown option "
                    + String.trim_all_whites (pair[0])
                    + " in replace field " + ((c >> 1) + 1) + "</b>";
            }
          }

          if (!val)
            if (zero_type (vars[var]) && (args->debug || id->misc->debug))
              val = "<b>No variable " + options[0] + "</b>";
            else
              val = zero;
          else {
            if (arrayp( val ))
              val = Array.map (val, lambda (mixed v) {return (string) v;}) *
                multisep;
            else
              val = replace ((string) val, "\000", multisep);
            if (!sizeof (val))
              val = empty;
          }

          if (!sizeof (encodings))
            encodings = args->encode ?
              Array.map (lower_case (args->encode) / ",",
                         String.trim_all_whites) : ({"html"});

          string tmp_val;
          foreach (encodings, string encoding)
            if (!(val = roxen_encode( val, encoding )))
              return ("<b>Unknown encoding " + encoding
                      + " in replace field " + ((c >> 1) + 1) + "</b>");

          exploded[c] = val;
        }

      if (first)
        first = 0;
      else if (args->delimiter)
        new_contents += args->delimiter;
      new_contents += args->preprocess ? exploded * "" :
        parse_rxml (exploded * "", id);
      if (args["debug-output"])
        unparsed_contents += exploded * "";
    } else {
      new_contents += args->preprocess ? contents : parse_rxml (contents, id);
      if (args["debug-output"])
        unparsed_contents += contents;
    }
  }

  switch (args["debug-output"]) {
      case 0:
        break;
        
      case "log":
        report_debug ("tag output: %s\n", unparsed_contents);
        break;
        
      case "comment":
        new_contents += "<!--\n" + _Roxen.html_encode_string (unparsed_contents) + "\n-->";
        break;
        
      default:
        new_contents = "\n<br><b>[</b><pre>" + _Roxen.html_encode_string (unparsed_contents) +
          "</pre><b>]</b>\n";
  }

  id->misc->variables = other_vars;
  return new_contents;
}

//! method: string fix_relative(string file, object id)
//!  Transforms relative paths to absolute ones in the virtual filesystem
//! arg: string file
//!  The relative path to transform
//! arg: object id
//!  The caudium id object
//! returns:
//!  A string containing the absolute path in he virtual filesystem
string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') 
    ;
  else if(file != "" && file[0] == '#') 
    file = id->not_query + file;
  else
    file = dirname(id->not_query) + "/" +  file;
  
  return simplify_path(file);
}


//!  Return the scope and variable name based on the input data.
//! @param variable
//!  The variable to parse. Should be either "variable" or "scope.variable".
//!  If a specific scope is sent to the function, the variable is uses as-is
//!  for the variable name.
//! @param scope
//!  The optional scope. If present, this overrides any scope specification
//!  in the variable name. If left out, the scope is parsed from the variable
//!  name. 
//! @returns
//!  An array consisting of the scope and the variable.
//!
//! @note
//!  Non-RIS code
array(string) parse_scope_var(string variable, string|void scope)
{
  array scvar = allocate(2);
  if (scope) {
    scvar[0] = scope;
    scvar[1] = variable;
  } else {
    if (sscanf(variable, "%s.%s", scvar[0], scvar[1]) != 2) {
      scvar[0] = "form";
      scvar[1] = variable;
    }
  }
  
  return scvar;
}

//!  Return the value of the specified variable in the specified scope.
//! @param variable
//!  The variable to fetch from the scope.
//! @param scope
//!  The scope of the variable. If zero, the scope will be extracted from
//!  the variable using [parse_scope_var].
//! @param id
//!  The request id object.
//! @returns
//!  The value of the variable or zero if the variable or scope doesn't
//!  exist.
//! @seealso
//!   @[set_scope_var()], @[parse_scope_var()]
//!
//! @note
//!  Non-RIS code
mixed get_scope_var(string variable, void|string scope, object id)
{
  function _get;

  if (!id->misc->_scope_status) {
    if (id->variables && id->variables[variable])
      return id->variables[variable];
    return 0;
  }
  
  if(!scope)
    [scope,variable] = parse_scope_var(variable);
  
  if(!id->misc->scopes[scope])
    return 0;
  
  if(!(_get = id->misc->scopes[scope]->get))
    return 0;
  
  return _get(variable, id);
}

//!  Set the specified variable in the specified scope to the value.
//! @param variable
//!  The variable to fetch from the scope.
//! @param scope
//!  The scope of the variable. If zero, the scope will be extracted from
//!  the variable using [parse_scope_var].
//! @param value
//!  The value to set the variable to.
//! @param id
//!  The request id object.
//! @returns
//!  1 if the variable was set correctly, 0 if it failed.
//! 
//! @seealso
//!  @[get_scope_var()], @[parse_scope_var()]
//!
//! @note
//!  non-RIS code
int set_scope_var(string variable, void|string scope, mixed value, object id)
{
  function _set;

  if (!id->misc->_scope_status) {
    id->variables[variable] = value;
    return 1;
  }
  
  if(!scope)
    [scope,variable] = parse_scope_var(variable);
  
  if(!id->misc->scopes[scope])
    return 0;
  
  if(!(_set = id->misc->scopes[scope]->set))
    return 0;
  
  return _set(variable, value, id);
}

//!  Parse the data for entities.
//! @param data
//!  The text to parse.
//! @param cb
//!  The function called when an entity is encountered. Arguments are:
//!  the parser object, the entity scope, the entity name, the request id
//!  and any extra arguments specified.
//! @param id
//!  The request id object.
//! @param extra
//!  Optional arguments to pass to the callback function.
//! @returns
//!  The parsed result.
//!
//! @note
//!  non-RIS code
static mixed cb_wrapper(object parser, string entity, object id, function cb,
                        mixed ... args) {
  string scope, name, encoding;
  array tmp = (parser->tag_name()) / ":";
  entity = tmp[0];
  encoding = tmp[1..] * ":";

  if (!encoding || !strlen(encoding))
    encoding = (id && id->misc->_default_encoding) || "html";
  if (sscanf(entity, "%s.%s", scope, name) != 2)
    return 0;
  
  mixed ret = cb(parser, scope, name, id, @args);
  
  if(!ret)
    return 0;
  if(stringp(ret))
    return roxen_encode(ret, encoding);
  if(arrayp(ret))
    return Array.map(ret, roxen_encode, encoding);    
}

//! Parse the passed string looking for entities referring to the scopes
//! defined in Caudium.
//!
//! @param data
//!  The string to parse
//!
//! @param cb
//!  The callback for extra data found in the string.
//!
//! @param id
//!  The request ID in which context the function is called.
//!
//! @param extra
//!  Extra parameters sent to the @tt{cb@} callback
//!
//! @returns
//!  The input string with all the defined entities replaced.
//!
//! @note
//!  non-RIS code
string parse_scopes(string data, function cb, object id, mixed ... extra) {
  object mp = Parser.HTML();
  mp->lazy_entity_end(1);
  mp->ignore_tags(1);
  mp->set_extra(id, cb, @extra);

  mp->_set_entity_callback(cb_wrapper);
  return mp->finish(data)->read();
}

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
