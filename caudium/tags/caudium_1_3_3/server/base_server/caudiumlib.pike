/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 *
 * $Id$
 */

//! Caudiumlib is a collection of utility functions used by modules and
//! the Caudium core. 

inherit "http";

// static string _cvs_version = "$Id$";
// This code has to work both in the roxen object, and in modules
#if !constant(caudium)
#define caudium caudiump()
#endif

#include <stat.h>

#define ipaddr(x,y) (((x)/" ")[y])

//!  Get the size in pixels of the file pointed to by the
//!  object gif.
//! @param gif
//!  The opened Stdio.File object with the GIF image.
//! @returns
//!  The size of the image as a string in a format suitable for use
//!  in a HTML &lt;img&gt; tag (width=&quot;XXX&quot; height=&quot;YYY&quot;).
string gif_size(object gif)
{
  int x,y;
  string d;
  gif->seek(6);
  d = gif->read(4);
  x = (d[1]<<8) + d[0]; y = (d[3]<<8) + d[2];
  return "width=\""+x+"\" height=\""+y+"\"";
}

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
static mapping build_env_vars(string f, object id, string path_info)
{
  string addr=id->remoteaddr || "Internal";
  mixed tmp;
  object tmpid;
  mapping new = ([]);
  
  
  if(id->query && strlen(id->query))
    new->INDEX=id->query;
    
  if(path_info && strlen(path_info))
  {
    string t, t2;
    if(path_info[0] != '/')
      path_info = "/" + path_info;
    
    t = t2 = "";
    
    // Kludge
    if (id->misc->path_info == path_info) {
      // Already extracted
      new["SCRIPT_NAME"]=id->not_query;
    } else {
      new["SCRIPT_NAME"]=
	id->not_query[0..strlen(id->not_query)-strlen(path_info)-1];
    }
    new["PATH_INFO"]=path_info;


    while(1)
    {
      // Fix PATH_TRANSLATED correctly.
      t2 = caudium->real_file(path_info, id);
      if(t2)
      {
	new["PATH_TRANSLATED"] = t2 + t;
	break;
      }
      tmp = path_info/"/" - ({""});
      if(!sizeof(tmp))
	break;
      path_info = "/" + (tmp[0..sizeof(tmp)-2]) * "/";
      t = tmp[-1] +"/" + t;
    }
  } else
    new["SCRIPT_NAME"]=id->not_query;

  tmpid = id;
  while(tmpid->misc->orig)
    // internal get
    tmpid = tmpid->misc->orig;
  
  // Begin "SSI" vars.
  if(sizeof(tmp = tmpid->not_query/"/" - ({""})))
    new["DOCUMENT_NAME"]=tmp[-1];
  
  new["DOCUMENT_URI"]= tmpid->not_query;
  
  if(((tmp = (tmpid->misc && tmpid->misc->stat)) ||
      (tmp = (tmpid->defined && tmpid->defines[" _stat"])) ||
      (tmpid->conf &&
       (tmp = tmpid->conf->stat_file(tmpid->not_query||"", tmpid)))))
    new["LAST_MODIFIED"]=http_date(tmp[3]);

  // End SSI vars.
    
  if(tmp = caudium->real_file(new["SCRIPT_NAME"], id))
    new["SCRIPT_FILENAME"] = tmp;
    
  if(tmp = caudium->real_file("/", id))
    new["DOCUMENT_ROOT"] = tmp;

  if(!new["PATH_TRANSLATED"])
    m_delete(new, "PATH_TRANSLATED");
  else if(new["PATH_INFO"][-1] != '/' && new["PATH_TRANSLATED"][-1] == '/')
    new["PATH_TRANSLATED"] = 
      new["PATH_TRANSLATED"][0..strlen(new["PATH_TRANSLATED"])-2];

  // HTTP_ style variables:

  mapping hdrs;

  if ((hdrs = id->request_headers)) {
    foreach(indices(hdrs) - ({ "authorization", "proxy-authorization",
			       "security-scheme", }), string h) {
      string hh = "HTTP_" + upper_case(VARQUOTE(h));      
      new[hh] = replace(hdrs[h], ({ "\0" }), ({ "" }));
    }
    if (!new["HTTP_HOST"]) {
      if(objectp(id->my_fd) && id->my_fd->query_address(1))
	new["HTTP_HOST"] = replace(id->my_fd->query_address(1)," ",":");
    }
  } else {
    if(id->misc->host)
      new["HTTP_HOST"]=id->misc->host;
    else if(objectp(id->my_fd) && id->my_fd->query_address(1))
      new["HTTP_HOST"]=replace(id->my_fd->query_address(1)," ",":");
    if(id->misc["proxy-connection"])
      new["HTTP_PROXY_CONNECTION"]=id->misc["proxy-connection"];
    if(id->misc->accept) {
      if (arrayp(id->misc->accept)) {
	new["HTTP_ACCEPT"]=id->misc->accept*", ";
      } else {
	new["HTTP_ACCEPT"]=(string)id->misc->accept;
      }
    }

    if(id->misc->cookies)
      new["HTTP_COOKIE"] = id->misc->cookies;
  
    if(sizeof(id->pragma))
      new["HTTP_PRAGMA"]=indices(id->pragma)*", ";

    if(stringp(id->misc->connection))
      new["HTTP_CONNECTION"]=id->misc->connection;
    
    new["HTTP_USER_AGENT"] = id->useragent; 
    
    if(id->referrer)
      new["HTTP_REFERER"] = id->referrer;
  }

  new["REMOTE_ADDR"]=addr;
    
  if(caudium->quick_ip_to_host(addr) != addr)
    new["REMOTE_HOST"]=caudium->quick_ip_to_host(addr);

  catch {
    if(id->my_fd) {
      new["REMOTE_PORT"] = ipaddr(id->my_fd->query_address(), 1);
    }
  };
    
  if(id->misc->_temporary_query_string)
    new["QUERY_STRING"] = id->misc->_temporary_query_string;
  else
    new["QUERY_STRING"] = id->query || "";
   
  if(!strlen(new["QUERY_STRING"]))
    m_delete(new, "QUERY_STRING");
    
  if(id->realauth) 
    new["REMOTE_USER"] = (id->realauth / ":")[0];
  if(id->auth && id->auth[0])
    new["ROXEN_AUTHENTICATED"] = "1"; // User is valid with the Roxen userdb.
  
  if(id->data && strlen(id->data))
  {
    if(id->misc["content-type"])
      new["CONTENT_TYPE"]=id->misc["content-type"];
    else
      new["CONTENT_TYPE"]="application/x-www-form-urlencoded";
    new["CONTENT_LENGTH"]=(string)strlen(id->data);
  }
    
  if(id->query && strlen(id->query))
    new["INDEX"]=id->query;
    
  new["REQUEST_METHOD"]=id->method||"GET";
  new["SERVER_PORT"] = id->my_fd?
    ((id->my_fd->query_address(1)||"foo unknown")/" ")[1]: "Internal";
    
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

  if(id->cookies->CaudiumUserID)
    new["CAUDIUM_USER_ID"]=id->cookies->CaudiumUserID;

  new["COOKIES"] = "";
  foreach(indices(id->cookies), tmp)
  {
    tmp = VARQUOTE(tmp);
    new["COOKIE_"+tmp] = id->cookies[tmp];
    new["COOKIES"]+= tmp+" ";
  }
	
  foreach(indices(id->config), tmp)
  {
    tmp = VARQUOTE(tmp);
    new["WANTS_"+tmp]="true";
    if(new["CONFIGS"])
      new["CONFIGS"] += " " + tmp;
    else
      new["CONFIGS"] = tmp;
  }

  foreach(indices(id->variables), tmp)
  {
    string name = VARQUOTE(tmp);
    if (id->variables[tmp] && (sizeof(id->variables[tmp]) < 8192)) {
      /* Some shells/OS's don't like LARGE environment variables */
      new["QUERY_"+name] = replace(id->variables[tmp],"\000"," ");
      new["VAR_"+name] = replace(id->variables[tmp],"\000","#");
    }
    if(new["VARIABLES"])
      new["VARIABLES"]+= " " + name;
    else
      new["VARIABLES"]= name;
  }
      
  foreach(indices(id->prestate), tmp)
  {
    tmp = VARQUOTE(tmp);
    new["PRESTATE_"+tmp]="true";
    if(new["PRESTATES"])
      new["PRESTATES"] += " " + tmp;
    else
      new["PRESTATES"] = tmp;
  }
	
  foreach(indices(id->supports), tmp)
  {
    tmp = VARQUOTE(tmp);
    new["SUPPORTS_"+tmp]="true";
    if (new["SUPPORTS"])
      new["SUPPORTS"] += " " + tmp;
    else
      new["SUPPORTS"] = tmp;
  }
  return new;
}

/* Backwards Roxen compatibility */
static function build_roxen_env_vars = build_caudium_env_vars; 

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
  
  if(S_ISLNK(m))  s += "Symbolic link";
  else if(S_ISREG(m))  s += "File";
  else if(S_ISDIR(m))  s += "Dir";
  else if(S_ISSOCK(m)) s += "Socket";
  else if(S_ISCHR(m))  s += "Special";
  else if(S_ISBLK(m))  s += "Device";
  else if(S_ISFIFO(m)) s += "FIFO";
  else if((m&0xf000)==0xd000) s+="Door";
  else s+= "Unknown";
  
  s+=", ";
  
  if(S_ISREG(m) || S_ISDIR(m))
  {
    s+="<tt>";
    if(m&S_IRUSR) s+="r"; else s+="-";
    if(m&S_IWUSR) s+="w"; else s+="-";
    if(m&S_IXUSR) s+="x"; else s+="-";
    
    if(m&S_IRGRP) s+="r"; else s+="-";
    if(m&S_IWGRP) s+="w"; else s+="-";
    if(m&S_IXGRP) s+="x"; else s+="-";
    
    if(m&S_IROTH) s+="r"; else s+="-";
    if(m&S_IWOTH) s+="w"; else s+="-";
    if(m&S_IXOTH) s+="x"; else s+="-";
    s+="</tt>";
  } else {
    s+="--";
  }
  return s;
}

constant MONTHS=(["Jan":0, "Feb":1, "Mar":2, "Apr":3, "May":4, "Jun":5,
	         "Jul":6, "Aug":7, "Sep":8, "Oct":9, "Nov":10, "Dec":11,
		 "jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
	         "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

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
  if(!stringp(w)) // Internal request..
    return -1;
  foreach(a, q) 
    if(stringp(q) && strlen(q) && glob(q, w)) 
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
  if(!a)
    return 1;
  t1=gmtime(t);
   // Expects 't' as returned from time(), not UTC.
  sscanf(lower_case(a), "%*s, %s; %s", a, extra);
  if(extra && sscanf(extra, "length=%d", length) && len && length != len)
    return 0;

  if(search(a, "-") != -1)
  {
    sscanf(a, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second);
    year += 1900;
    month=MONTHS[m];
  } else   if(search(a, ",") == 3) {
    sscanf(a, "%*s, %d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    if(year < 1900) year += 1900;
    month=MONTHS[m];
  } else if(!(int)a) {
    sscanf(a, "%*[^ ] %s %d %d:%d:%d %d", m, day, hour, minute, second, year);
    month=MONTHS[m];
  } else {
    sscanf(a, "%d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    month=MONTHS[m];
    if(year < 1900) year += 1900;
  }

  if(year < (t1["year"]+1900))                                
    return 0;
  else if(year == (t1["year"]+1900)) 
    if(month < (t1["mon"]))  
      return 0;
    else if(month == (t1["mon"]))      
      if(day < (t1["mday"]))   
	return 0;
      else if(day == (t1["mday"]))	     
	if(hour < (t1["hour"]))  
	  return 0;
	else if(hour == (t1["hour"]))      
	  if(minute < (t1["min"])) 
	    return 0;
	  else if(minute == (t1["min"]))     
	    if(second < (t1["sec"])) 
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
  if(!id) error("No id passed to parse_rxml\n");

  if(!defines) {
    defines = id->misc->defines||([]);
    if(!_error)
      _error=200;
    if(!_extra_heads)
      _extra_heads=([ ]);
  }

  if(!id->conf || !id->conf->parse_module)
    return what;
  
  what = id->conf->parse_module->
    do_parse(what, id, file||this_object(), defines, id->my_fd);

  if(!id->misc->moreheads)
    id->misc->moreheads= ([]);
  id->misc->moreheads |= _extra_heads;
  
  id->misc->defines = defines;

  return what;
}

constant iso88591
=([ "&nbsp;":   " ",
    "&iexcl;":  "¡",
    "&cent;":   "¢",
    "&pound;":  "£",
    "&curren;": "¤",
    "&yen;":    "¥",
    "&brvbar;": "¦",
    "&sect;":   "§",
    "&uml;":    "¨",
    "&copy;":   "©",
    "&ordf;":   "ª",
    "&laquo;":  "«",
    "&not;":    "¬",
    "&shy;":    "­",
    "&reg;":    "®",
    "&macr;":   "¯",
    "&deg;":    "°",
    "&plusmn;": "±",
    "&sup2;":   "²",
    "&sup3;":   "³",
    "&acute;":  "´",
    "&micro;":  "µ",
    "&para;":   "¶",
    "&middot;": "·",
    "&cedil;":  "¸",
    "&sup1;":   "¹",
    "&ordm;":   "º",
    "&raquo;":  "»",
    "&frac14;": "¼",
    "&frac12;": "½",
    "&frac34;": "¾",
    "&iquest;": "¿",
    "&Agrave;": "À",
    "&Aacute;": "Á",
    "&Acirc;":  "Â",
    "&Atilde;": "Ã",
    "&Auml;":   "Ä",
    "&Aring;":  "Å",
    "&AElig;":  "Æ",
    "&Ccedil;": "Ç",
    "&Egrave;": "È",
    "&Eacute;": "É",
    "&Ecirc;":  "Ê",
    "&Euml;":   "Ë",
    "&Igrave;": "Ì",
    "&Iacute;": "Í",
    "&Icirc;":  "Î",
    "&Iuml;":   "Ï",
    "&ETH;":    "Ð",
    "&Ntilde;": "Ñ",
    "&Ograve;": "Ò",
    "&Oacute;": "Ó",
    "&Ocirc;":  "Ô",
    "&Otilde;": "Õ",
    "&Ouml;":   "Ö",
    "&times;":  "×",
    "&Oslash;": "Ø",
    "&Ugrave;": "Ù",
    "&Uacute;": "Ú",
    "&Ucirc;":  "Û",
    "&Uuml;":   "Ü",
    "&Yacute;": "Ý",
    "&THORN;":  "Þ",
    "&szlig;":  "ß",
    "&agrave;": "à",
    "&aacute;": "á",
    "&acirc;":  "â",
    "&atilde;": "ã",
    "&auml;":   "ä",
    "&aring;":  "å",
    "&aelig;":  "æ",
    "&ccedil;": "ç",
    "&egrave;": "è",
    "&eacute;": "é",
    "&ecirc;":  "ê",
    "&euml;":   "ë",
    "&igrave;": "ì",
    "&iacute;": "í",
    "&icirc;":  "î",
    "&iuml;":   "ï",
    "&eth;":    "ð",
    "&ntilde;": "ñ",
    "&ograve;": "ò",
    "&oacute;": "ó",
    "&ocirc;":  "ô",
    "&otilde;": "õ",
    "&ouml;":   "ö",
    "&divide;": "÷",
    "&oslash;": "ø",
    "&ugrave;": "ù",
    "&uacute;": "ú",
    "&ucirc;":  "û",
    "&uuml;":   "ü",
    "&yacute;": "ý",
    "&thorn;":  "þ",
    "&yuml;":   "ÿ",
]);

constant international
=([ "&OElig;":  "\x0152",
    "&oelig;":  "\x0153",
    "&Scaron;": "\x0160",
    "&scaron;": "\x0161",
    "&Yuml;":   "\x0178",
    "&circ;":   "\x02C6",
    "&tilde;":  "\x02DC",
    "&ensp;":   "\x2002",
    "&emsp;":   "\x2003",
    "&thinsp;": "\x2009",
    "&zwnj;":   "\x200C",
    "&zwj;":    "\x200D",
    "&lrm;":    "\x200E",
    "&rlm;":    "\x200F",
    "&ndash;":  "\x2013",
    "&mdash;":  "\x2014",
    "&lsquo;":  "\x2018",
    "&rsquo;":  "\x2019",
    "&sbquo;":  "\x201A",
    "&ldquo;":  "\x201C",
    "&rdquo;":  "\x201D",
    "&bdquo;":  "\x201E",
    "&dagger;": "\x2020",
    "&Dagger;": "\x2021",
    "&permil;": "\x2030",
    "&lsaquo;": "\x2039",
    "&rsaquo;": "\x203A",
    "&euro;":   "\x20AC",
	"&odbacute;": "\x0151",
	"&Odbacute;": "\x0150",
	"&udbacute;": "\x0171",
	"&Udbacute;": "\x0170",
	"&odblac;": "\x0151",
	"&Odblac;": "\x0150",
	"&udblac;": "\x0171",
	"&Udblac;": "\x0170",

]);

constant symbols
=([ "&fnof;":     "\x0192",
    "&thetasym;": "\x03D1",
    "&upsih;":    "\x03D2",
    "&piv;":      "\x03D6",
    "&bull;":     "\x2022",
    "&hellip;":   "\x2026",
    "&prime;":    "\x2032",
    "&Prime;":    "\x2033",
    "&oline;":    "\x203E",
    "&frasl;":    "\x2044",
    "&weierp;":   "\x2118",
    "&image;":    "\x2111",
    "&real;":     "\x211C",
    "&trade;":    "\x2122",
    "&alefsym;":  "\x2135",
    "&larr;":     "\x2190",
    "&uarr;":     "\x2191",
    "&rarr;":     "\x2192",
    "&darr;":     "\x2193",
    "&harr;":     "\x2194",
    "&crarr;":    "\x21B5",
    "&lArr;":     "\x21D0",
    "&uArr;":     "\x21D1",
    "&rArr;":     "\x21D2",
    "&dArr;":     "\x21D3",
    "&hArr;":     "\x21D4",
    "&forall;":   "\x2200",
    "&part;":     "\x2202",
    "&exist;":    "\x2203",
    "&empty;":    "\x2205",
    "&nabla;":    "\x2207",
    "&isin;":     "\x2208",
    "&notin;":    "\x2209",
    "&ni;":       "\x220B",
    "&prod;":     "\x220F",
    "&sum;":      "\x2211",
    "&minus;":    "\x2212",
    "&lowast;":   "\x2217",
    "&radic;":    "\x221A",
    "&prop;":     "\x221D",
    "&infin;":    "\x221E",
    "&ang;":      "\x2220",
    "&and;":      "\x2227",
    "&or;":       "\x2228",
    "&cap;":      "\x2229",
    "&cup;":      "\x222A",
    "&int;":      "\x222B",
    "&there4;":   "\x2234",
    "&sim;":      "\x223C",
    "&cong;":     "\x2245",
    "&asymp;":    "\x2248",
    "&ne;":       "\x2260",
    "&equiv;":    "\x2261",
    "&le;":       "\x2264",
    "&ge;":       "\x2265",
    "&sub;":      "\x2282",
    "&sup;":      "\x2283",
    "&nsub;":     "\x2284",
    "&sube;":     "\x2286",
    "&supe;":     "\x2287",
    "&oplus;":    "\x2295",
    "&otimes;":   "\x2297",
    "&perp;":     "\x22A5",
    "&sdot;":     "\x22C5",
    "&lceil;":    "\x2308",
    "&rceil;":    "\x2309",
    "&lfloor;":   "\x230A",
    "&rfloor;":   "\x230B",
    "&lang;":     "\x2329",
    "&rang;":     "\x232A",
    "&loz;":      "\x25CA",
    "&spades;":   "\x2660",
    "&clubs;":    "\x2663",
    "&hearts;":   "\x2665",
    "&diams;":    "\x2666",
]);

constant greek
= ([ "&Alpha;":   "\x391",
     "&Beta;":    "\x392",
     "&Gamma;":   "\x393",
     "&Delta;":   "\x394",
     "&Epsilon;": "\x395",
     "&Zeta;":    "\x396",
     "&Eta;":     "\x397",
     "&Theta;":   "\x398",
     "&Iota;":    "\x399",
     "&Kappa;":   "\x39A",
     "&Lambda;":  "\x39B",
     "&Mu;":      "\x39C",
     "&Nu;":      "\x39D",
     "&Xi;":      "\x39E",
     "&Omicron;": "\x39F",
     "&Pi;":      "\x3A0",
     "&Rho;":     "\x3A1",
     "&Sigma;":   "\x3A3",
     "&Tau;":     "\x3A4",
     "&Upsilon;": "\x3A5",
     "&Phi;":     "\x3A6",
     "&Chi;":     "\x3A7",
     "&Psi;":     "\x3A8",
     "&Omega;":   "\x3A9",
     "&alpha;":   "\x3B1",
     "&beta;":    "\x3B2",
     "&gamma;":   "\x3B3",
     "&delta;":   "\x3B4",
     "&epsilon;": "\x3B5",
     "&zeta;":    "\x3B6",
     "&eta;":     "\x3B7",
     "&theta;":   "\x3B8",
     "&iota;":    "\x3B9",
     "&kappa;":   "\x3BA",
     "&lambda;":  "\x3BB",
     "&mu;":      "\x3BC",
     "&nu;":      "\x3BD",
     "&xi;":      "\x3BE",
     "&omicron;": "\x3BF",
     "&pi;":      "\x3C0",
     "&rho;":     "\x3C1",
     "&sigmaf;":  "\x3C2",
     "&sigma;":   "\x3C3",
     "&tau;":     "\x3C4",
     "&upsilon;": "\x3C5",
     "&phi;":     "\x3C6",
     "&chi;":     "\x3C7",
     "&psi;":     "\x3C8",
     "&omega;":   "\x3C9",
]);

constant replace_entities = indices( iso88591 ) +
  indices( international ) +
  indices( symbols ) +
  indices( greek ) +
  ({"&lt;","&gt;","&amp;","&quot;","&apos;","&#x22;","&#34;","&#39;","&#0;"});

constant replace_values = values( iso88591 ) +
  values( international ) +
  values( symbols ) +
  values( greek ) +
  ({"<",">","&","\"","\'","\"","\"","\'","\000"});

//!  Converts html entity coded chars to unicode
//! @param str
//!  The string to convert, contains the html entities
//! @returns
//!  a unicode string
string html_to_unicode( string str ) {
	return replace((string) str, replace_entities, replace_values );
}

//!  Converts unicode string to html entity coded string
//! @param str
//!  The string to convert, contains unicode string
//! @returns
//!  html encoded string
string unicode_to_html( string str ) {
	return replace((string) str, replace_values, replace_entities );
}

constant safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"/"";
constant empty_strings = ({
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
  for(int i=0; i<sizeof(a); i++)
    if(lower_case(b[i]) != a[i])
      if(is_safe_string(b[i]))
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

//
// hmm, isn't that a dupe from Pike?
// /grendel
//
static string dirname( string file )
{
  if(!file) 
    return "/";
  mixed tmp;
  if(file[-1] == '/')
    if(strlen(file) > 1)
      return file[0..strlen(file)-2];
    else
      return file;
  tmp=file/"/";
  if(sizeof(tmp)==2 && tmp[0]=="")
    return "/";
  return tmp[0..sizeof(tmp)-2]*"/";
}

static string conv_hex( int color )
{
  int c;
  string result;

  result = "";
  for (c=0; c < 6; c++, color>>=4)
    switch (color & 15)
    {
     case 0: case 1: case 2: case 3: case 4:
     case 5: case 6: case 7: case 8: case 9:
      result = (color & 15) + result;
      break;
     case 10: 
      result = "A" + result;
      break;
     case 11: 
      result = "B" + result;
      break;
     case 12: 
      result = "C" + result;
      break;
     case 13: 
      result = "D" + result;
      break;
     case 14: 
      result = "E" + result;
      break;
     case 15: 
      result = "F" + result;
      break;
    }
  return "#" + result;
  
}

static string add_config( string url, array config, multiset prestate )
{
  if(!sizeof(config)) 
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/<" + config * "," + ">" + add_pre_state(url, prestate);
}

string msectos(int t)
{
  if(t<1000) /* One sec. */
  {
    return sprintf("0.%02d sec", t/10);
  } else if(t<6000) {  /* One minute */
    return sprintf("%d.%02d sec", t/1000, (t%1000 + 5) / 10);
  } else if(t<3600000) { /* One hour */
    return sprintf("%d:%02d m:s", t/60000,  (t%60000)/1000);
  } 
  return sprintf("%d:%02d h:m", t/3600000, (t%3600000)/60000);
}

#if constant(Caudium.extension)
static function extension = Caudium.extension;
#else
static string extension( string f )
{
  string q;
  sscanf(f, "%s?%*s", f); // Forms.

  f=lower_case( f );
  if(strlen(f)) switch(f[-1])
  {
   case '#': sscanf(f, "%s#", f);    break;
   case '~': sscanf(f, "%s~%*s", f); break;
   case 'd': sscanf(f, "%s.old", f); break;
   case 'k': sscanf(f, "%s.bak", f); break;
  }
  q=f;
  sscanf(reverse(f), "%s.%*s", f);
  f = reverse(f);
  if(q==f) return "";
  return f;
}
#endif

static int backup_extension( string f )
{
  if(!strlen(f)) 
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
  if(mappingp(x))
    return 8 + 8 + get_size(indices(x)) + get_size(values(x));
  else if(stringp(x))
    return strlen(x)+8;
  else if(arrayp(x))
  {
    mixed f;
    int i;
    foreach(x, f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if(multisetp(x)) {
    mixed f;
    int i;
    foreach(indices(x), f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if(objectp(x) || functionp(x)) {
    return 8 + 16; // (refcount + pointer) + object struct.
    // Should consider size of global variables / refcount 
  }
  return 20; // Ints and floats are 8 bytes, refcount and float/int.
}


static int ipow(int what, int how)
{
  int r=what;
  if(!how) return 1;
  while (how-=1) r *= what; 
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
static string simplify_path(string file)
{
  int no_pre_slash, end_slash;
  if(!strlen(file))
    return "";
  
  if(file[0] != '/')  no_pre_slash = 1;

  if(strlen(file) > 1 &&
     (file[-1] == '/' ||
      (file[-1] == '.'  && file[-2] == '/')))
    end_slash = 1;
  file = combine_path("/", file);
  if(end_slash && file[-1] != '/') file += "/";
  if(no_pre_slash) return file[1..];
  return file;
}

//! Returns a short date string from a time @tt{int@}
//!
//! @param timestamp
//!  The UNIX time value to convert.
//!
//! @returns
//!  String representation of the param
static string short_date(int timestamp)
{
  int date = time(1);
  
  if(ctime(date)[20..23] < ctime(timestamp)[20..23])
    return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[20..23];
  
  return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[11..15];
}

//! Converts a string representing a HTTP date into a UNIX time value.
//!
//! @param date
//!  The date string to be converted
//!
//! @returns
//!  The UNIX time value for the date.
int httpdate_to_time(string date)
{     
   if (intp(date)) return -1;
   // Tue, 28 Apr 1998 13:31:29 GMT
   // 0    1  2    3    4  5  6
   int mday,hour,min,sec,year;
   string month;
   if(sscanf(date,"%*s, %d %s %d %d:%d:%d GMT",mday,month,year,hour,min,sec)==6)
     return mktime((["year":year-1900,
		     "mon":MONTHS[lower_case(month)],
		     "mday":mday,
		     "hour":hour,
		     "min":min,
		     "sec":sec,
		     "timezone":0]));
   
   
   return -1; 
}

//! Converts an integer into a Roman digit
//!
//! @param m
//!  The integer to be converted
//!
//! @returns
//!  A string representing the Roman equivalent of the passed integer.
static string int2roman(int m)
{
  string res="";
  if (m>10000000||m<0) return "que";
  while (m>999) { res+="M"; m-=1000; }
  if (m>899) { res+="CM"; m-=900; }
  else if (m>499) { res+="D"; m-=500; }
  else if (m>399) { res+="CD"; m-=400; }
  while (m>99) { res+="C"; m-=100; }
  if (m>89) { res+="XC"; m-=90; }
  else if (m>49) { res+="L"; m-=50; }
  else if (m>39) { res+="XL"; m-=40; }
  while (m>9) { res+="X"; m-=10; }
  if (m>8) return res+"IX";
  else if (m>4) { res+="V"; m-=5; }
  else if (m>3) return res+"IV";
  while (m) { res+="I"; m--; }
  return res;
}

//! Converts an integer number into a string
//!
//! @param n
//!  Integer to be converted
//!
//! @param m
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
static string number2string(int n ,mapping m, mixed names)
{
  string s;
  switch (m->type)
  {
      case "string":
        if (functionp(names)) {
          s=names(n); break;
        }
        if (!arrayp(names) || n<0 || n>=sizeof(names))
          s="";
        else
          s=names[n];
        break;
        
      case "roman":
        s=int2roman(n);
        break;
        
      default:
        return (string)n;
  }
  if (m->lower) s=lower_case(s);
  if (m->upper) s=upper_case(s);
  if (m->cap||m->capitalize) s=String.capitalize(s);
  return s;
}


static string image_from_type( string t )
{
  if(t)
  {
    sscanf(t, "%s/%*s", t);
    switch(t)
    {
     case "audio":
     case "sound":
      return "internal-gopher-sound";
     case "image":
      return "internal-gopher-image";
     case "application":
      return "internal-gopher-binary";
     case "text":
      return "internal-gopher-text";
    }
  }
  return "internal-gopher-unknown";
}

#define  PREFIX ({ "bytes", "kB", "MB", "GB", "TB", "HB" })
static string sizetostring( int size )
{
  float s = (float)size;
  if(size<0) 
    return "--------";
  size=0;

  while( s > 1024.0 )
  {
    s /= 1024.0;
    size ++;
  }
  return sprintf("%.1f %s", s, PREFIX[ size ]);
}

mapping proxy_auth_needed(object id)
{
  mixed res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
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

// *DUPE ALERT*
// They are all dupes from http.pike
//
string html_encode_string(string str)
// Encodes str for use as a literal in html text.
{
  return replace(str, ({"&", "<", ">", "\"", "\'", "\000", ":" }),
	       ({"&amp;", "&lt;", "&gt;", "&#34;", "&#39;", "&#0;", "&#58;"}));
}

string html_decode_string(string str)
// Decodes str, opposite to html_encode_string()
{
  return replace(str,
		 ({"&amp;","&lt;","&gt;","&#34;","&#39;","&#0;","&#58;"}),
		 ({"&", "<", ">", "\"", "\'", "\000", ":" }) );
}

string html_encode_tag_value(string str)
// Encodes str for use as a value in an html tag.
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
	if (moddata->copies) return moddata->copies[mid];
      }
      else if (moddata->enabled) return moddata->enabled;
      if (moddata->master) return moddata->master;
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
  if (!module) return 0;

  foreach (caudium->configurations, object conf) {
    string mname = conf->otomod[module];
    if (mname) {
      mapping moddata = conf->modules[mname];
      if (moddata)
        if (moddata->copies)
          foreach (indices (moddata->copies), int i) {
            if (moddata->copies[i] == module)
              return conf->name + "/" + mname + "#" + i;
          }
        else if (moddata->master == module || moddata->enabled == module)
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
    if (module->query_name) name = module->query_name();
    if (!name || !sizeof (name)) name = module->register_module()[1];
    return name;
  }
  else return 0;
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
     return http_encode_string (val);
     
   case "cookie":
     // HTTP cookie encoding.
     return http_encode_cookie (val);
     
   case "url":
     // HTTP encoding, including special characters in URL:s.
     return http_encode_url (val);
       
   case "html":
     // For generic html text and in tag arguments. Does
     // not work in RXML tags (use dtag or stag instead).
     return html_encode_string (val);
     
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

// internal method for do_output_tag
private string remove_leading_trailing_ws( string str )
{
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str ); 
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str );
  return str;
}

// This method needs lot of work... but so do the rest of the system too
// RXML needs types
private int compare( string a, string b )
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
      case 0: break;
      case "log":
        report_debug ("tag input: " + contents + "\n");
        break;
      case "comment":
        new_contents = "<!--\n" + html_encode_string (contents) + "\n-->";
        break;
      default:
        new_contents = "\n<br><b>[</b><pre>" +
          html_encode_string (contents) + "</pre><b>]</b>\n";
  }

  if (args->sort)
  {
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

  if (args->range)
  {
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
  foreach (var_arr, mapping vars)
  {
    if (args->set)
      foreach (indices (vars), string var) {
        mixed val = vars[var];
        if (!val) val = args->zero || "";
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

    if (!args->replace || lower_case( args->replace ) != "no")
    {
      array exploded = contents / quote;
      if (!(sizeof (exploded) & 1))
        return "<b>Contents ends inside a replace field</b>";

      for (int c=1; c < sizeof( exploded ); c+=2)
        if (exploded[c] == "")
          exploded[c] = quote;
        else
        {
          array(string) options =  exploded[c] / ":";
          string var = remove_leading_trailing_ws (options[0]);
          mixed val = vars[var];
          array(string) encodings = ({});
          string multisep = multi_separator;
          string zero = args->zero || "";
          string empty = args->empty || "";

          foreach(options[1..], string option) {
            array (string) pair = option / "=";
            string optval = remove_leading_trailing_ws (pair[1..] * "=");

            switch (lower_case (remove_leading_trailing_ws( pair[0] ))) {
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
                case "quote":	// For backward compatibility.
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
                                          remove_leading_trailing_ws);
                  break;
                default:
                  return "<b>Unknown option "
                    + remove_leading_trailing_ws (pair[0])
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
            if (!sizeof (val)) val = empty;
          }

          if (!sizeof (encodings))
            encodings = args->encode ?
              Array.map (lower_case (args->encode) / ",",
                         remove_leading_trailing_ws) : ({"html"});

          string tmp_val;
          foreach (encodings, string encoding)
            if( !(val = roxen_encode( val, encoding )) )
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
      if (args["debug-output"]) unparsed_contents += exploded * "";
    }
    else {
      new_contents += args->preprocess ? contents : parse_rxml (contents, id);
      if (args["debug-output"]) unparsed_contents += contents;
    }
  }

  switch (args["debug-output"]) {
      case 0: break;
      case "log":
        report_debug ("tag output: " + unparsed_contents + "\n");
        break;
      case "comment":
        new_contents += "<!--\n" + html_encode_string (unparsed_contents) + "\n-->";
        break;
      default:
        new_contents = "\n<br><b>[</b><pre>" + html_encode_string (unparsed_contents) +
          "</pre><b>]</b>\n";
  }

  id->misc->variables = other_vars;
  return new_contents;
}

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
//! name: parse_scope_var - return the scope and variable name.
array(string) parse_scope_var(string variable, string|void scope)
{
  array scvar = allocate(2);
  if(scope) {
    scvar[0] = scope;
    scvar[1] = variable;
  } else {
    if(sscanf(variable, "%s.%s", scvar[0], scvar[1]) != 2)
    {
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
  if(!id->misc->scopes[scope])  return 0;
  if(!(_get = id->misc->scopes[scope]->get)) return 0;
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
//! name: set_scope_var - set the value of a scope variable
//! @seealso
//!  @[get_scope_var()], @[parse_scope_var()]
int set_scope_var(string variable, void|string scope, mixed value, object id)
{
  function _set;

  if (!id->misc->_scope_status) {
      id->variables[variable] = value;
      return 1;
  }
  
  if(!scope)
    [scope,variable] = parse_scope_var(variable);
  if(!id->misc->scopes[scope])  return 0;
  if(!(_set = id->misc->scopes[scope]->set)) return 0;
  return _set(variable, value, id);
}

#if constant(Parser.HTML)
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
static mixed cb_wrapper(object parser, string entity, object id, function cb,
			mixed ... args) {
  string scope, name, encoding;
  array tmp = (parser->tag_name()) / ":";
  entity = tmp[0];
  encoding = tmp[1..] * ":";
  if(!encoding || !strlen(encoding))
    encoding = (id && id->misc->_default_encoding) || "html";
  if(sscanf(entity, "%s.%s", scope, name) != 2)
    return 0;
  mixed ret = cb(parser, scope, name, id, @args);
  if(!ret) return 0;
  if(stringp(ret)) return roxen_encode(ret, encoding);
  if(arrayp(ret)) return Array.map(ret, roxen_encode, encoding);    
}

string parse_scopes(string data, function cb, object id, mixed ... extra) {
  object mp = Parser.HTML();
  mp->lazy_entity_end(1);
  mp->ignore_tags(1);
  mp->set_extra(id, cb, @extra);

  mp->_set_entity_callback(cb_wrapper);
  return mp->finish(data)->read();
}
#else
string parse_scopes(string data, function cb, object id, mixed ... extra) {
  error("Parser.HTML is required.\n");
}
#endif

// color.pike compatibility functions.
#if !constant(parse_color) && constant(Image.Color)
#define parse_color(X)	Image.Color( X )->rgb()
#endif
#if !constant(color_name) && constant(Image.Color)
#define color_name(X)	Image.Color( @X )->name()
#endif
#if !constant(list_colors) && constant(Image.Color)
#define list_colors()	indices(Image.Color)
#endif

#if !constant(rgb_to_hsv) && constant(Image.Color) && constant(Image.Color.rgb)
array rgb_to_hsv(array|int ri, int|void gi, int|void bi) {
 if( arrayp(ri)  ) return Image.Color.rgb( @ri )->hsv();
 return Image.Color.rgb( ri,gi,bi )->hsv();
} 
#endif

#if !constant(hsv_to_rgb) && constant(Image.Color) && constant(Image.Color.hsv)
array hsv_to_rgb(array|int hv, int|void sv, int|void vv) {
	if( arrayp(hv) ) return Image.Color.hsv(@hv)->rgb();
	return Image.Color.hsv(hv,sv,vv)->rgb();
}
#endif

