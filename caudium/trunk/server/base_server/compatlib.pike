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
//!   designed for Caudium to run without modifications.

constant cvs_version = "$Id$";

#define WCOMPAT(Y,X) \
	string sourcefile; \
        int    sourceline; \
        sscanf(describe_backtrace(backtrace()[1]),"%*s\n%d\n%s\n", \
               sourceline,sourcefile); \
        report_error("Compat "+X+"() used in %s:%d, please consider using " \
                     ""+Y+"."+X+"() instead\n",sourcefile,sourceline);

#define WCOMPAT2(Y,X) \
	string sourcefile; \
        int    sourceline; \
        sscanf(describe_backtrace(backtrace()[1]),"%*s\n%d\n%s\n", \
               sourceline,sourcefile); \
        report_error("Compat "+X+"() used in %s:%d, please consider using " \
                     ""+Y+"() instead\n",sourcefile,sourceline);

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
   return _Roxen.html_decode_string(m);
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
   WCOMPAT("Cadium","http_date");
   return Caudium.http_date(t);
}


