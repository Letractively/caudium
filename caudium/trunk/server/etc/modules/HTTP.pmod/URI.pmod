/* Emacs, this is -*-pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

//! URI class. Handle formating, encoding and decoding for URI. Frontend
//! of some Caudium C functions.

//! Encodes a query to a string. This protects odd characters
//! like '&' and '#' and control characters, and pack the result
//! together in a HTTP query string.
//!
//! Example:
//! @pre{
//! > HTTP.URI.encode_query( (["user":"foo","passwd":"encrypted"]) );
//! (1) Result: "user=foo&passwd=encrypted"
//! > HTTP.URI.encode_query( (["foo":"&&amp;","'=\"":"\0\0\0"]) );
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
