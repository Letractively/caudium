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
string parser_html_lines(mixed ... args) {
   WCOMPAT("spider","parse_html_lines");
   return spider.parse_html_lines(@args);
}
