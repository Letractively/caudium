/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2001 The Caudium Group
 * Copyright � 1997 Francesco Chemolli <kinkie@comedia.it>
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

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version  = "$Id$";
constant thread_safe  = 1;
constant module_type  = MODULE_FIRST;
constant module_name  = "Switch";
constant module_doc   = "This module can act as an ON/OFF switch for a virtual "
                        "server, and thus the name.<br /> It can return an "
			"user-defined answer for every query the server "
			"receives, except queries from user-defined hosts "
			"or for user-definied docs.";
constant module_unique= 1;

//! module: Switch
//!  This module can act as an ON/OFF switch for a virtual
//!  server, and thus the name.<br /> It can return an 
//!  user-defined answer for every query the server 
//!  receives, except queries from user-defined hosts 
//!  or for user-definied docs.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FIRST
//! cvs_version: $Id$


//#define SWITCH_DEBUG
#ifdef SWITCH_DEBUG
#define LOG(X) perror("Switchmodule: "+X+"\n");
#else
#define LOG(X) /**/
#endif

mapping first_try (object id)
{
  if (!QUERY(switch))	//okay, we gotta check.
  { 
    LOG("switch is off");
    return 0;
  }
  mixed tmp;
  foreach(QUERY(hosts_to_pass),tmp)
   if (glob(tmp,id->remoteaddr))
   {
     LOG (sprintf ("Allowing: host %s matches glob %s",id->remoteaddr, tmp));
     return 0;
   }
  foreach(QUERY(docs_to_pass),tmp)
   if (glob(tmp,id->not_query))
   {
     LOG (sprintf("Allowing: document %s matches glob %s",id->not_query,tmp));
     return 0;
   }
  LOG("switch triggered");
  return http_low_answer(QUERY(return_code),
                         parse_rxml(QUERY(return_message),id));
}

void create()
{
  defvar ("switch",0,"Activate switch", TYPE_FLAG,
          "Should every server query get the default answer?");

  defvar ("return_code",502,"Configuration: HTTP return code",TYPE_MULTIPLE_INT,
          "What to return if <tt>server's switch</tt> is set (see the HTTP "
          "specification for the values' meanings)<br />"
          "The most useful are 200 (OK), 30X (Moved), 403 (Forbidden), "
          "404 (No such resource), 500 (Server error), 502 "
	  "(Service temporarily unavailable).",
          ({ 200, 202, 300, 301, 302, 400, 401, 403, 404, 410, 500, 502 }) );

  defvar ("return_message",
          "<title>Sorry, service is temporarily unavailible</title>\n"
	  "<body bgcolor=\"white\">\n"
          "\n<h2 align=\"center\"><configimage src=\"cowfish-caudium\" "
          "alt=\"Service unavailable\">\n"
          "<p><hr noshade \>"
          "\n<i>Sorry</i></h2>\n"
          "<br clear />\n<font size="+2">This server is temporarily "
          "disabled for maintenance."
          "Please try again later.\n</font></p>\n"
          "<hr noshade=\"noshade\" />"
          "<version />\n","Configuration: Returned message",
          TYPE_TEXT_FIELD,
          "The explanatory message which should be sent along with the request."
          );
	  
  defvar ("hosts_to_pass",({""}),"Configuration: IP addresses to allow "
          "anyways (globs)",TYPE_STRING_LIST,
          "The hosts which match any glob of these will be allowed access "
	  "even if the switch is turned on." );
	  
  defvar ("docs_to_pass", ({"/_internal*","/internal*"}),
          "Configuration: virtual files to allow anyways (globs)",
          TYPE_STRING_LIST,
          "The (virtual) documents which match any of these will be allowed "
	  "access even if the switch is turned on." );
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: switch
//! Should every server query get the default answer?
//!  type: TYPE_FLAG
//!  name: Activate switch
//
//! defvar: return_code
//! What to return if <tt>server's switch</tt> is set (see the HTTP specification for the values' meanings)<br />The most useful are 200 (OK), 30X (Moved), 403 (Forbidden), 404 (No such resource), 500 (Server error), 502 (Service temporarily unavailable).
//!  type: TYPE_MULTIPLE_INT
//!  name: Configuration: HTTP return code
//
//! defvar: return_message
//! The explanatory message which should be sent along with the request.
//!  type: TYPE_TEXT_FIELD
//!  name: Configuration: Returned message
//
//! defvar: hosts_to_pass
//! The hosts which match any glob of these will be allowed access even if the switch is turned on.
//!  type: TYPE_STRING_LIST
//!  name: Configuration: IP addresses to allow anyways (globs)
//
//! defvar: docs_to_pass
//! The (virtual) documents which match any of these will be allowed access even if the switch is turned on.
//!  type: TYPE_STRING_LIST
//!  name: Configuration: virtual files to allow anyways (globs)
//
