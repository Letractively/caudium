/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2001 The Caudium Group
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


//! module: Roxen Error handler
//!   This module will handle errors (404, 500, etc..) with old messages
//!   from Roxen 1.x days.
//! type: MODULE_ERROR|MODULE_EXPERIMENTAL
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

constant module_type   = MODULE_ERROR|MODULE_EXPERIMENTAL;
constant module_name   = "Roxen Error Handler";
constant module_doc    = "This module will handle errors (404, 500, etc...)"
                         "with old messages from Roxen 1.x days.";
constant module_unique = 1;
constant cvs_version   = "$Id$";
constant thread_safe   = 1;

void create() {
  defvar("404msg", "<title>Sorry. I cannot find this resource</title>\n"
         "<body background='/(internal,image)/cowfish-bg' bgcolor='#ffffff'\n"
         "text='#000000' alink='#ff0000' vlink='#00007f' link='#0000ff'>\n"
         "<h2 align='center'><configimage src='cowfish-caudium' \n"
         "alt=\"File not found\"><p><hr noshade>\n"
         "\n<i>Sorry</i></h2>\n"
         "<br clear>\n<font size=\"+2\">The resource requested "
         "<i>$File</i>\ncannot be found.<p>\n\nIf you feel that this is a "
         "configuration error, please contact "
         "the administrators or the author of the\n"
         "<if referrer>"
         "<a href=\"<referrer>\">referring</a>"
         "</if>\n"
         "<else>referring</else>\n"
         "page."
         "<p>\n</font>\n"
         "<hr noshade>"
         "<version>, at <a href=\"$Me\">$Me</a>.\n"
         "</body>\n", 
         "No such file Message (eg. 404 error)", TYPE_TEXT_FIELD,
         "What to return when there is no resource or file available "
         "at a certain location. $File will be replaced with the name "
         "of the resource requested, and $Me with the URL of this server ");
  defvar("401msg","<hl>Authentication Failed.</h1>\n",
         "Authentication Failed - Error 401 message", TYPE_TEXT_FIELD,
         "What to return when authentication has failed.");
  defvar("debug", 1, "Debug", TYPE_FLAG,
         "Debug the code into Caudium debug log");
}

//!   Auth error code handler.
//!   Return http authentication response mapping which will make the
//!   browser request the user for authentication information. The optional
//!   message will be used as the body of the page.
//! @note
//!   This function is called by http_auth_required() and http_auth_failed()
//!   calls caudiumlib. So DO NOT call such API inside this call or Caudium
//!   gets mad !
//! @param realm
//!   The realm of this authentication. This is show in various methods by the
//!   authenticating browser.
//! @param message
//!   An optional message which defaults to message in the defvar of this 
//!   module.
//! @param dohtml
//!   Optional to make a nice HTML docuemnt.
mapping|int auth_required(string realm, string|void message, void|int dohtml)
{

}

//!   General error code handler.
//!   This used in 404 in general
//! @param id
//!   The Caudium Object ID
//! @param extra_heads
//!   Extra heads to send to browser (optional).
//! @returns
//!   The HTTP response mapping.
mapping|int handle_error(object id, void|mapping extra_heads)
{ 
  int error_code;    // The HTTP Error code
  string error_text; // The message to send.
  mixed err;

  // Checking for error code.

  if(id->misc->error_code)
    error_code = id->misc->error_code;
  else
  {
    if(id->method != "GET" && id->method != "HEAD" && id->method != "POST")
      error_code = 501;
    else 
      error_code = 404;
  }

  // We got it. Getting message to send.
  if(stringp(id->misc->error_name))
    error_text = id->misc->error_name;
  else
  {
    err = catch { error_text = id->errors[error_code]; };
    if (err)  // Error message ????
       error_text = "No Error Message Supplied. Sorry.\n\n";
  }      
   
  // We seems to have error.
  if(id->misc->error_code)
  {
    if(QUERY(debug))
      werror("Error code is : "+error_code);
    if(error_code = 401) 
      error_text=QUERY(401msg); 
    if(mappingp(extra_heads))
      return http_low_answer(error_code, error_text) +
         ([ "extra_heads": extra_heads ]);
    else
      return http_low_answer(error_code, error_text);
  }
  else if (id->method != "GET" && id->method != "HEAD" && id->method != "POST")
    return http_low_answer(501, "Not implemented.");
  else if (err = catch {
    return http_low_answer(404,
                replace(parse_rxml(QUERY(404msg), id),
                        ({"$File", "$Me"}),
                        ({_Roxen.html_encode_string(id->not_query),
                          id->conf->query("MyWorldLocation") }) ));
    }) {
        if(mixed __eRr = catch(id->internal_error(err)))
          report_error("Internal server error: "+describe_backtrace(err)+
                       "internal_error() also failed: "+describe_backtrace(__eRr));
    }

  return 0;
}

