/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2003 The Caudium Group
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

//! Compatibility Library for Roxen and Caudium
//! $Id$
//! @note
//!   All theses calls are here to allow transparent migration
//!   between Roxen 1.3 and Caudium. This allows also some modules
//!   designed for Caudium to run without modifications. This Library
//!   contains also some compat call for Pike as well.

constant cvs_version = "$Id$";

// Private functions
// Used for backtrace work
static private string dbt(array t) {
  if(!arrayp(t) || (sizeof(t)<2)) return "";
  return (((t[0]||"Unknown program")-(getcwd()+"/"))-"base_server/")+":"+t[1];
}        

#define WCOMPAT(Y,X) report_error("Compat "+X+"() used in %s, please consider using "+Y+"."+X+"() instead\n",dbt(backtrace()[-2]));

#define WCOMPAT2(Y,X) report_error("Compat "+X+"() used in %s, please consider using "+Y+"() instead\n",dbt(backtrace()[-2]));

//! Compat call of Stdio.mkdirhier
//! @deprecated
int mkdirhier(string pathname, void|int mode) {
   WCOMPAT("Stdio","mkdirhier");
   return Stdio.mkdirhier(pathname, mode);
}

//! Compat call of _Roxen.http_decode_string
//! @deprecated
string http_decode_string(string m) {
   WCOMPAT("_Roxen","http_decode_string");
   return _Roxen.http_decode_string(m);
}

//! Compat call of _Roxen.html_encode_string
//! @deprecated
string html_encode_string(string m) {
   WCOMPAT("_Roxen","html_encode_string");
   return _Roxen.html_encode_string(m);
}

//! Compat call of Protocols.HTTP.unentity
//! @deprecated
string html_decode_string(string m) {
   WCOMPAT2("Protocols.HTTP.unentity","html_decode_string");
   return Protocols.HTTP.unentity(m);
}

//! Compat call of Caudium.http_encode_string
//! @deprecated
string http_encode_string(string m) {
   WCOMPAT("Caudium","http_encode_string");
   return Caudium.http_encode_string(m);
}

//! Compat call of Caudium.http_encode_cookie
//! @deprecated
string http_encode_cookie(string m) {
   WCOMPAT("Caudium","http_encode_cookie");
   return Caudium.http_encode_cookie(m);
}

//! Compat call of Caudium.http_encode_url
//! @deprecated
string http_encode_url(string m) {
   WCOMPAT("Caudium","http_encode_url");
   return Caudium.http_encode_url(m);
}

//! Compat call of Caudium.cern_http_date
//! @deprecated
string cern_http_date(int t) {
   WCOMPAT("Caudium","cern_http_date");
   return Caudium.cern_http_date(t);
}

//! Compat call of Caudium.http_date
//! @deprecated
string http_date(int t) {
   WCOMPAT("Caudium","http_date");
   return Caudium.http_date(t);
}

// Some spider calls are not under spider module so here is some compat
// things

//! Compat call of spider.parse_html
//! @deprecated
string parse_html(mixed ... args) {
   WCOMPAT("spider","parse_html");
   return spider.parse_html(@args);
}

//! Compat call of spider.parse_html_lines
//! @deprecated
string parse_html_lines(mixed ... args) {
   WCOMPAT("spider","parse_html_lines");
   return spider.parse_html_lines(@args);
}

//! Compat call of spider.parse_accessed_database
//! @deprecated
mixed parse_accessed_database(mixed ... args) {
   WCOMPAT("spider","parse_accessed_database");
   return spider.parse_accessed_database(@args);
}

// some API calls thats are not used in current caudium.

//!  Get the size in pixels of the file pointed to by the
//!  object gif.
//! @param gif
//!  The opened Stdio.File object with the GIF image.
//! @returns
//!  The size of the image as a string in a format suitable for use
//!  in a HTML &lt;img&gt; tag (width=&quot;XXX&quot; height=&quot;YYY&quot;).
string gif_size(object gif)
{
  report_error("Compat gif_size() used in %s, please consider using Image.Dims functions instead\n",dbt(backtrace()[-2]));

  array size;
  mixed err;
  
  err = catch{
  size = Image.Dims.get(gif);
  };
  if(err) return "";
  else {
    if(arrayp(size))
      return "width=\""+size[0]+"\" height=\""+size[1]+"\"";
    else
      return "";
  }
  return "";
}

// Pike API compat (taken from pike 7.4 sources)

//!   Instantiate a program (Pike 7.2 compatibility).
//!
//!   A new instance of the class @[prog] will be created.
//!   All global variables in the new object be initialized, and
//!   then @[lfun::create()] will be called with @[args] as arguments.
//!
//!   This function was removed in Pike 7.3, use
//!   @code{((program)@[prog])(@@@[args])@}
//!   instead.
//!
//! @deprecated
//!
//! @seealso
//!   @[destruct()], @[compile_string()], @[compile_file()], @[clone()]
//!
object new(string|program prog, mixed ... args)
{
  report_error("Compat new() used in %s, please consider using Pike 7.4 (program) cast instead\n",dbt(backtrace()[-2]));
  if(stringp(prog))
  {
    if(program p=(program)(prog, backtrace()[-2][0]))
      return p(@args);
    else
      error("Failed to find program %s.\n", prog);
  }
  return prog(@args);
}

//! @decl object clone(string|program prog, mixed ... args)
//!
//!   Alternate name for the function @[new()] (Pike 7.2 compatibility).
//!
//!   This function was removed in Pike 7.3, use
//!   @code{((program)@[prog])(@@@[args])@}
//!   instead.
//!
//! @deprecated
//!
//! @seealso
//!   @[destruct()], @[compile_string()], @[compile_file()], @[new()]

object clone(mixed ... args) {
  report_error("Compat clone() used in %s, please consider using Pike 7.4 (program) cast instead\n",dbt(backtrace()[-2]));
  return new(@args);
}

// Roxenlib / Caudiumlib API compat

// This is inside caudiumlib14
static mapping build_caudium_env_vars(object id);
static string  http_caudium_id_cookie();
static string  http_caudium_config_cooke(string from);
static mapping http_low_answer(int errno, string data, void|int dohtml);

//! Backward compatibility with Roxen
//! @deprecated
mixed build_roxen_env_vars(mixed ... args) {
  report_error("Compat build_roxen_env_vars() used in %s, please consider using build_caudium_env_vars() instead\n",dbt(backtrace()[-2]));
  return build_caudium_env_vars(@args);
}

//! Compat call for Caudium.extension
//! @deprecated
string extention(string f) {
  WCOMPAT("Caudium","extension");
  return Caudium.extension(f);
}

//! Compat call for http_caudium_id_cookie
//! @deprecated
string http_roxen_id_cookie() {
  report_error("Compat http_roxen_id_cookie() used in %s, please consider using http_caudium_id_cookie() instead\n",dbt(backtrace()[-2]));
  return http_caudium_id_cookie();
}

//! Compat call for http_caudium_config_cookie
//! @deprecated
string http_roxen_config_cookie(string from) {
  report_error("Compat http_roxen_config_cookie() used in %s, please consider using http_caudium_id_cookie() instead\n",dbt(backtrace()[-2]));
  return http_caudium_id_cookie(string from);
}

//! Compat call from http_auth_required
//! @param realm
//!   The realm of this authentication. This is show in variour methods by
//!   authenticating browser.
//! @param m
//!   Unused.
//! @param d
//!   Unused.
//! @deprecated
mapping http_auth_failed(string realm, string|void m, int|void d) {
  report_error("Compat http_auth_failed() used in %s, please consider using http_auth_required() instead\n",dbt(backtrace()[-2]));
#ifdef HTTP_DEBUG
  report_debug("HTTP: Auth failed (%s)\n",realm);
#endif
  return http_low_answer(401, "<h1>Authentication failed.</h1>") 
         + ([ "extra_heads": ([ "WWW-Authenticate":"basic realm=\""+realm+"\"",
                               ]),
              ]);
}
