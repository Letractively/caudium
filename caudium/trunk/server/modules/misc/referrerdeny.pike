/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © ???? David Hedbor <david@hedbor.org>
 * Copyright © 1999 Xavier Beaudouin <kiwi@oav.net>
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
// Based on David's refererdeny with some few new features =)

#define REFERERDEBUG

#ifdef REFERERDEBUG
#define LOG(X) if(QUERY(debug)) werror("RefererDeny :" +X+"\n");
#else
#define LOG(X) /* */
#endif

#include <module.h>
inherit "module";
inherit "caudiumlib";

//! module: Referrer Deny
//!  A module which allow you to deny accesses to files matching a certain
//!  regexp bases on their referrer. Usefull to stop people from leeching
//!  images or files from your server without your permission.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PRECACHE | MODULE_FIRST
//! cvs_version: $Id$
//! todo: Agent type deny e.g. can deny somewhat GetRight/*, Wget/* apents
//!  to stop leaching some files.
//! todo: Add some regexp to deny some kind of referer regexp... =)

constant module_type   = MODULE_PRECACHE | MODULE_FIRST;
constant module_name   = "Referrer Deny";
constant module_doc    = "A module which allow you to deny accesses to files "
                         "matching a certain regexp based on their referrer. "
		         "Usefull to stop people from leeching image or files "
		         "from your server without your permission.";
constant module_unique = 0;
constant cvs_version   = "$Id$";
constant thread_safe   = 1;

void create()
{
  defvar("switch",0,"Activate Referrer Deny MKII", TYPE_FLAG,
         "Should the Referrer Deny MKII module be actived ?" );
  defvar("deny",1,"Configuration: Referrer Deny comportment", TYPE_FLAG,
  	 "If set to <tt>YES</tt> the module will <tt>DENY</tt> the File Regexp entered.<br>"
	 "If set to <tt>NO</tt> the module will <tt>ACCEPT</tt> all the File Regexp and deny another unkown files.<br>");
  defvar("exts", "(\\.gif$|\\.jpg$|\\.png$|\\.pjpg$|\\.jpeg$|\\.zip$|\\.mp3$|\\.mpg$|\\.mpeg$|\\.mov$|\\.avi$|\\.e_xe$|\\.exe$|\\.ace$|\\.C..$|\\.c..$|\\.r..$|\\.R..$)",
	 "Configuration: File Regexp", TYPE_STRING, 
	 "Files matching this regexp will be denied or accept depending of state of <tt>Referrer Deny Comportment</tt>"
	 "switch. <br>"
	 "If <tt>SET</tt>The following files will be denied if their referrer doesn't match the allowed regexp.<br>"
	 "If <tt>NO SET</tt>The following files will be accepted whatever the referer is, but <b>all</b> other files "
	 "will be rejected if their referer doesn't match the allowed regexp.");
  defvar("msg", 
         "<TITLE>Sorry, access to this resource is not authorized \n"
	 "<if referer>from <referer></if></TITLE>\n"
	 "<h2 align=center><configimage src=caudium.gif alt=\"Access Forbidden\">\n"
	 "<hr noshade>\n"
	 "<i>Sorry</i></h2>\n"
	 "<br clear><font size=+2>Access to this resource is not authorized \n"
	 "<if referer>from <a href=\"<referer>\"><referer></a></if><p></font>\n"
	 "Please stop leaching.\n"
	 "<hr noshade>\n"
	 "<version>\n",
	 "Configuration: Deny message", TYPE_TEXT_FIELD, 
	 "Message to send for denied accesses.");
  defvar("match", "(\\.caudium.net|\\.caudium.org)", 
	 "Configuration: Allowed Regexp", TYPE_STRING, 
	 "Referrers matching this regexp will be allowed access to "
	 "files matching the file regexp.");
  defvar("noempty", 1, 
	 "Configuration: Deny empty referrers ", TYPE_FLAG, 
	 "If set, always deny accesses without a referrer.");
  defvar("return_code",403,"Configuration: HTTP return code.", TYPE_MULTIPLE_INT,
         "What HTTP code to return if <tt>Referrer Deny MKII</tt> is enabled, see the "
	 "Roxen's documentation for the values' meanings)<br>"
	 "The most usefull are 200(OK), 30*(moved), 403(Forbidden), "
	 "404(No such resource), 500(Server Error), 502(Service temporarily unavailble).",
	 ({ 200, 201, 202, 203, 204, 300, 301, 302, 304, 400, 401, 402, 403, 404, 405, 408, 409, 410, 500, 501, 502, 503 })
	 );
  defvar("allowroot",1,"Configuration: Don't check virtual paths with less than 2 /", TYPE_FLAG,
  	 "If set, the referrer deny module will never check access to virtual paths "
	 "that have less than 2 / in it.<br> "
	 "For example : <br>"
	 "&nbsp;&nbsp;<tt>/foo</tt> will <b>not</b> checked by this module,but<br>"
	 "&nbsp;&nbsp;<tt>/foo/bar</tt> will <b>be</b> checked by this module.");
#ifdef REFERERDEBUG
  defvar("debug", 1, "Debug",TYPE_FLAG,
         "Debug the referrer deny access into server log...");
#endif
}

object freg, areg;
int deny_counts=0, url_counts=0, root_access=0;

void start()
{
  catch { 
    freg = Regexp(QUERY(exts));
    areg = Regexp(QUERY(match));
  };
}

mapping first_try(object id)
{
  return id->misc->_referrer_denied_request;
}

void precache_rewrite(object id)
{
  if(!QUERY(switch)) 			// Do we active our cool referrer deny ?
  {
    LOG("switched off...");		// No I don't think so ;-(
    return;
  }
  url_counts++;				// Add some statistics
  if(QUERY(allowroot))
  {
    LOG("allow root is on...");
    if (sizeof(id->not_query / "/") <= 2)	// This is a file in the root directory
    {
      LOG(sprintf("%s is in root VFS : allowed...",id->not_query));
      root_access++;		// Add some statistics
      return;
    }
  }
  if (( (freg->match(id->not_query) && QUERY(deny)) ||
	(!freg->match(id->not_query) && !QUERY(deny)) ) &&
      (!areg->match(id->referer * " ") ||
       (!sizeof(id->referer) && QUERY(noempty)))) {
    // Tada. This sucker is asking to be denied. We won't let them down.
    // Cowabunga.
#ifdef REFERERDEBUG
    werror("Denied access to %s\n  with referrer [%s].\n"
	   "  with user agent [%s]\n",
	   id->not_query, id->referer * " ", id->client * " ");
#endif
    //    return http_low_answer(403, QUERY(msg));
    deny_counts++;			// Add some statistics
    
    NOCACHE(); // We don't want to cache negative responses
    id->misc->_referrer_denied_request =
      http_low_answer(QUERY(return_code), parse_rxml(QUERY(msg),id));
  }
}

string status()
{

  string retval;

  retval = "<b>Referer Deny Statistics</b><br>";
  retval+= "<table border=0>";
  retval+= "<tr><td>The module is </td><td>";
  retval+= QUERY(switch) ? "<i>active</i>":"disactivated";
  retval+= "</td></tr>";

  if (QUERY(switch) && url_counts)
  {
    retval += "<tr><td>Module mode is in</td><td><i>";
    retval += QUERY(deny) ? "deny":"accept";
    retval += "</i> mode.</td><tr>";
    if (QUERY(allowroot))
     retval += sprintf("<tr><td>VFS Root accessed files</td><td>%d</td></tr>", root_access);
    retval += sprintf("<tr><td>Url parsed </td><td>%d</td></tr><tr><td>Url denied</td><td>%d</td></tr>",
                      url_counts, deny_counts);    
  }
  retval+= "</table>";
  return retval;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: switch
//! Should the Referrer Deny MKII module be actived ?
//!  type: TYPE_FLAG
//!  name: Activate Referrer Deny MKII
//
//! defvar: deny
//! If set to <tt>YES</tt> the module will <tt>DENY</tt> the File Regexp entered.<br />If set to <tt>NO</tt> the module will <tt>ACCEPT</tt> all the File Regexp and deny another unkown files.<br />
//!  type: TYPE_FLAG
//!  name: Configuration: Referrer Deny comportment
//
//! defvar: exts
//! Files matching this regexp will be denied or accept depending of state of <tt>Referrer Deny Comportment</tt>switch. <br />If <tt>SET</tt>The following files will be denied if their referrer doesn't match the allowed regexp.<br />If <tt>NO SET</tt>The following files will be accepted whatever the referer is, but <b>all</b> other files will be rejected if their referer doesn't match the allowed regexp.
//!  type: TYPE_STRING
//!  name: Configuration: File Regexp
//
//! defvar: msg
//! Message to send for denied accesses.
//!  type: TYPE_TEXT_FIELD
//!  name: Configuration: Deny message
//
//! defvar: match
//! Referrers matching this regexp will not be allowed access to files matching the file regexp.
//!  type: TYPE_STRING
//!  name: Configuration: Allowed Regexp
//
//! defvar: noempty
//! If set, always deny accesses without a referrer.
//!  type: TYPE_FLAG
//!  name: Configuration: Deny empty referrers 
//
//! defvar: return_code
//! What HTTP code to return if <tt>Referrer Deny MKII</tt> is enabled, see the Roxen's documentation for the values' meanings)<br />The most usefull are 200(OK), 30*(moved), 403(Forbidden), 404(No such resource), 500(Server Error), 502(Service temporarily unavailble).
//!  type: TYPE_MULTIPLE_INT
//!  name: Configuration: HTTP return code.
//
//! defvar: allowroot
//! If set, the referrer deny module will never check access to virtual paths that have less than 2 / in it.<br /> For example : <br />&#xa0;&#xa0;<tt>/foo</tt> will <b>not</b> checked by this module,but<br />&#xa0;&#xa0;<tt>/foo/bar</tt> will <b>be</b> checked by this module.
//!  type: TYPE_FLAG
//!  name: Configuration: Don't check virtual paths with less than 2 /
//
//! defvar: debug
//! Debug the referrer deny access into server log...
//!  type: TYPE_FLAG
//!  name: Debug
//
