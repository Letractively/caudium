/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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
//! module: Secure file system module (Mk II)
//!  This is a (somewhat) more secure filesystem module. It
//!  allows an per-regexp level security.
//!  Mark 2 allows for authentication via a form.
//! inherits: filesystem
//! type: MODULE_LOCATION
//! cvs_version: $Id$
//

// A somewhat more secure version of the normal filesystem. This
// module user regular expressions to regulate the access of files.

// Mk II changes by Henrik P Johnson <hpj@globecom.net>.

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#include <pcre.h>

inherit "filesystem";

constant module_type = MODULE_LOCATION;
constant module_name = "Secure file system module (Mk II)";
constant module_doc  = "This is a (somewhat) more secure filesystem module. It "
            "allows an per-regexp level security.\n"
	    "Mark 2 allows for authentication via a form.\n";
constant module_unique = 0;

array seclevels = ({ });

#define  regexp(_) (Regexp(_)->match)

#define ALLOW 1
#define DENY 2
#define USER 3

void start()
{
  string sl, sec;
  array new_seclevels = ({});

  foreach(replace(query("sec"),({" ","\t","\\\n"}),({"","",""}))/"\n", sl)
  {
    if(!strlen(sl) || sl[0]=='#')
      continue;
    string pat, type, value;
    if(sscanf(sl, "%s:%s=%s", pat, type, value)==3)
    {
      switch(type)
      {
      case "allowip":
	new_seclevels += ({ ({ regexp(replace(pat, ({ "?", "*", "." }),
					      ({ ".", ".*", "\." }))),
			       ALLOW, 
			       regexp(replace(value, ({ "?", ".", "*" }),
					      ({ ".", "\.", ".*" })))
	}) });
	break;

      case "denyip":
	new_seclevels += ({ ({ regexp(replace(pat, ({ "?", ".", "*" }),
					      ({ ".", "\.", ".*" }))),
			       DENY, 
			       regexp(replace(value, ({ "?", ".", "*" }),
					      ({ ".", "\.", ".*" })))
	}) });
	break;

      case "allowuser":
	new_seclevels += ({ ({ regexp(replace(pat, ({ "?", ".", "*", "," }),
					      ({ ".", "\.", ".*","|" }))),
			       USER,
			       value,
	}) });
	break;
      }
    }
  }
  seclevels = new_seclevels;
  ::start();
}

int dont_use_page()
{
  return(!QUERY(page));
}

void create()
{
  defvar("sec", 
	 "# Only allow from local host, or persons with a valid account\n"
	 "*:  allow ip=127.0.0.1\n"
	 "*:  allow user=any\n",
	 "Security patterns",

	 TYPE_TEXT_FIELD,

	 "This is the 'pattern: security level=value' list.<br>"
	 "Each security level can be any or more from this list:<br>"
	 "<hr noshade='yes' />"
	 "allow ip=pattern<br />"
	 "deny ip=pattern<br />"
	 "allow user=username,...<br />"
	 "<hr noshade='yes' />"
	 "In patterns: * is one or more characters, ? is one character.");
  defvar("page", 0, "Use FORM authentication", TYPE_FLAG,
         "If set instead of returning a HTTP authentication needed header, "
         "produce a page containing a login form.", 0);
  defvar("expire", 60*15, "Time for page authentication to expire.",
         TYPE_INT,
         "New authentication is required if no page is requested within "
	 "the given time.",
         0, dont_use_page);
  defvar("authpage",
	 "<HTML><HEAD><TITLE>Authentication needed</TITLE></HEAD><BODY>\n"
         "<FORM METHOD=post ACTION=$File>\n"
         "<INPUT NAME=httpuser><P>\n"
         "<INPUT NAME=httppass TYPE=password><P>\n"
         "<INPUT TYPE=submit VALUE=Authenticate>\n"
         "</FORM>\n"
         "</BODY></HTML>",
         "Page to use to authenticate.",
         TYPE_TEXT_FIELD,
         "Should contain an input with name httpuser and httppass. "
         "The text $File will be replaced with the page accessed and "
         "$Me with the current server root.",
         0, dont_use_page);

  ::create();
}

mixed not_allowed(string f, object id)
{
  array level;
  int need_auth;
  
  if(id->remoteaddr == "internal") return 0;

  foreach(seclevels, level)
  {
    if(level[0](f)) // The pattern match for this filename...
      switch(level[1])
      {
       case ALLOW: // allow ip=...
	 if(level[2](id->remoteaddr))
	   return 0; // Match. It's ok.
	 break;
	
       case DENY:  // deny ip=...
	// If match, this IP-number will never be permitted access. No need to
	// check any more. User and allow patterns are always checked first.
	 if(level[2](id->remoteaddr))
	   return Caudium.HTTP.low_answer(403, "<h2>Access forbidden</h2>"); 
	 break;
	
	
       case USER:  // allow user=...
	 string uname;
	 need_auth = 1;
	 if (query("page") && id->cookies["httpauth"]) {
	   string user,pass,last;
	   array(string) y=({ "","" });
	   sscanf(id->cookies["httpauth"],"%s:%s:%s", user, pass, last);
	   id->auth=id->conf->auth_module->authenticate(user, pass);
	 }

	 if(!(id->get_user())) {
	   if(query("page")) {
	     return Caudium.HTTP.low_answer(200,
				    replace(parse_rxml(query("authpage"), id),
					    ({"$File", "$Me"}), 
					    ({id->not_query,
					      id->get_canonical_url()})));

	   } else {
	     return http_auth_failed("user");
	   }
	 }
	 foreach(level[2]/",", uname) {
	   if((id->get_user() && id->get_user()->username==uname) || (uname=="any") || (uname=="*")) {
	     return 0;
	   }
	 }
	 break;
      }
  }
  if(need_auth) {
    if(query("page")) {
      return Caudium.HTTP.low_answer(200,
			     replace(parse_rxml(query("authpage"), id),
				     ({"$File", "$Me"}), 
				     ({id->not_query,
				       id->get_canonical_url()})));
    } else {
      return http_auth_failed("user");
    }
  }
  return  1;
}


// Overlay the normal find_file function, that's all this module has to do.
mixed find_file(string f, object id)
{
  mixed tmp, tmp2;
  string user,pass;

  if (query("page")) {
    int last;
    if (stringp(id->cookies["httpauth"])) {
      sscanf(id->cookies["httpauth"],"%s:%s:%d", user, pass, last);
    } else if (id->cookies["httpauth"]) {
      report_warning(sprintf("secure_fs: find_file():\n"
			     "Unexpected value for cookie \"httpauth\":\n"
			     "%O\n",
			     id->cookies["httpauth"]));
    }
    if(!last || (last+query("expire") < time(1)))
      m_delete(id->cookies,"httpauth");
    if(id->variables["httpuser"]&&id->variables["httppass"])
      id->cookies["httpauth"]=sprintf("%s:%s:%d", id->variables["httpuser"],
				      id->variables["httppass"], time(1));
  }

  if(tmp2=::find_file(f, id))
    if(tmp=not_allowed(f, id))
      return intp(tmp)?0:tmp;

  if (intp(tmp2) || !query("page") || !id->cookies["httpauth"])
    return tmp2;

  if (objectp(tmp2)) {
    return ([ "file":tmp2,
	      "extra_heads": ([
		"Set-Cookie": "httpauth="+
		Caudium.http_encode_string(sprintf("%s:%s:%d",
					   user||"", pass||"", time(1)))+
		"; path=/"
	      ]) ]);
  } else {
    return tmp2 +
      ([ "extra_heads": ([
	"Set-Cookie": "httpauth="+
	Caudium.http_encode_string(sprintf("%s:%s:%d",
				   user||"", pass||"", time(1)))+
	"; path=/"
      ]) ]);
  }
}




/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: sec
//! This is the 'pattern: security level=value' list.<br />Each security level can be any or more from this list:<br /><hr noshade='yes' />allow ip=pattern<br />deny ip=pattern<br />allow user=username,...<br /><hr noshade='yes' />In patterns: * is one or more characters, ? is one character.
//!  type: TYPE_TEXT_FIELD
//!  name: Security patterns
//
//! defvar: page
//! If set instead of returning a HTTP authentication needed header, produce a page containing a login form.
//!  type: TYPE_FLAG
//!  name: Use FORM authentication
//
//! defvar: expire
//! New authentication is required if no page is requested within the given time.
//!  type: TYPE_INT
//!  name: Time for page authentication to expire.
//
//! defvar: authpage
//! Should contain an input with name httpuser and httppass. The text $File will be replaced with the page accessed and $Me with the current server root.
//!  type: TYPE_TEXT_FIELD
//!  name: Page to use to authenticate.
//
