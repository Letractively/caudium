/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

//! This module will handle all HTTP related things.

//!  Return the specified date (as returned by time()) formated in the 
//!  commong log file format, which is "DD/MM/YYYY:HH:MM:SS [+/-]TZTZ".
//! @param t
//!  The time in seconds since 00:00:00 UTC, January 1, 1970. If this
//!  argument is void, then the function will return the current date
//!  in common log format.
//! @returns
//!  The date in the common log file format
//! @example
//!  Pike v7.4 release 10 running Hilfe v3.5 (Incremental Pike Frontend)
//!  > Caudium.HTTP.cern_date();
//!  (1) Result: "16/Feb/2003:23:38:48 +0100"
//! @note
//!  Non RIS code, handled by _Caudium C module.
//! @seealso
//!   @[Caudium.cern_http_date]
string cern_date(int|void t) {
   return Caudium.cern_http_date(t);
}

//!  Return the specified date (as returned by time()) formated in the
//!  HTTP-protocol standart date format, which is "Day, DD MMM YYYY HH:MM:SS GMT"
//!  Used in, for example, the "Last-Modified" header.
//! @param t
//!  The time in seconds since the 00:00:00 UTC, January 1, 1970. If this
//!  argument is void, then the function will return the current date in
//!  HTTP-protocol date format.
//! @returns
//!  The date in the common log file format
//! @example
//!  Pike v7.4 release 10 running Hilfe v3.5 (Incremental Pike Frontend)
//!  > Caudium.HTTP.date();
//!  (1) Result: "Sun, 16 Feb 2003 22:41:25 GMT"
//! @note
//!  Non RIS code, handled by _Caudium C module
//! @seealso
//!  @[Caudium.http_date]
string date(void|int t) {
  return Caudium.http_date(t);
}

//! Encodes a query to a string. This protects odd characters
//! like '&' and '#' and control characters, and pack the result
//! together in a HTTP query string.
//!
//! Example:
//! @pre{
//! > Caudium.HTTP.encode_query( (["user":"foo","passwd":"encrypted"]) );
//! (1) Result: "user=foo&passwd=encrypted"
//! > Caudium.HTTP.encode_query( (["foo":"&&amp;","'=\"":"\0\0\0"]) );
//! (2) Result: "foo=%26%26amp%3B&%27%3D%22=%00%00%00"
//! @}
//!
//! @param variables
//!   mapping of string variables to encode to
//!
//! @returns
//!   query string encoded according to RFC 2396
//!  
string encode_query(mapping(string:int|string) variables)
{
  return Array.map((array)variables,
           lambda(array(string|int|array(string)) v)
           {
             if (intp(v[1]))
               return Caudium.http_encode(v[0]);
             if (arrayp(v[1]))
               return map(v[1], lambda (string val) {
                          return 
                            Caudium.http_encode(v[0])+"="+
                            Caudium.http_encode(val);
                        })*"&";
             return Caudium.http_encode(v[0])+"="+Caudium.http_encode(v[1]);
           })*"&"; 
}
