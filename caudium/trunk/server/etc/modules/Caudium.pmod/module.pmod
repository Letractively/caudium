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

//! This is Caudium main library. Some of theses call are handled by 
//! our C pike glue _Caudium.

inherit _Caudium;


// Some documentation for some call handled by _Caudium module.

//! @decl string cern_http_date(int|void t)
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
//!  > Caudium.cern_http_date();
//!  (1) Result: "16/Feb/2003:23:38:48 +0100"
//! @note
//!  Non RIS code, handled by _Caudium C module.

//! @decl string http_date(int|void t)
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
//!  > Caudium.http_date();
//!  (1) Result: "Sun, 16 Feb 2003 22:41:25 GMT"
//! @note
//!  Non RIS code, handled by _Caudium C module
