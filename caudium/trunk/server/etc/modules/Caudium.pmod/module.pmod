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

//! @decl string strftime(string format, int timestamp)
//!   The strftime() function format the information from @[timestamp] 
//!   returned by its output according to the string pointed to by @[format].
//! @param format
//!   The @[format] string consists of zero or more conversions specifications
//!   and ordinary characters. All ordinary characters are copied directly into
//!   the output. A conversion specification consists of a percent sign ''%''
//!   and one more character. The @[format] string must not be empty (""). 
//!   The conversion specification are copied to the output after expansion as
//!   follows :
//!   @dl
//!     @item %A
//!       is replaced by national representation of the full weekday name.
//!     @item %a
//!       is replaced by national representation of the abbreviated weekday
//!       name, where the abbreviation is the first three characters.
//!     @item %B
//!       is replaced by national representation of the full month name.
//!     @item %b
//!       is replaced by national representation of the abbreviated month
//!       name, where the abbreviation is the first three characters.
//!     @item %C
//!       is replaced by (year / 100) as decimal number, single digits are
//!       preceded by a zero.
//!     @item %c
//!       is replaced by national representation of time and date. The format
//!       is similar to that producted by a ctime() and is equivalent to
//!       "%a %Ef %T %y". It also implies "3+1+6+1+8+1+4" format of output.
//!     @item %D
//!       is equivalent to "%m/%d/%y".
//!     @item %d
//!       is replaced by the day of month as a decimal number (01-31).
//!     @item %E*|%O*
//!       POSIX locale extensions. The sequences %Ec %EC %Ex %EX %Ey %EY %Od
//!       %Oe %OH %OI %Om %OM %OS %Ou %OU %OV %Ow %OW %Oy are supposed to
//!       provide alternate representations. Additionly %Ef implemented to 
//!       represent short month name / day order of the date, %EF to 
//!       represent alternative months names (used standalones, without day
//!       mentioned).
//!     @item %e
//!       is replaced by the day of month as a decimal number (1-31); single
//!       digitis are preceded by a blank.
//!     @item %G
//!       is replaced by a year as a decimal number with century. This year
//!       is the one that contains the greater part of the week (Monday as
//!       the first day of the week).
//!     @item %g
//!       is replaced by the same year as in "%G", but as a decimal number
//!       without century (00-99).
//!     @item %H
//!       is replaced by the hour (14-hour clock) as a decimal number (00-23).
//!     @item %h
//!       the same as %b.
//!     @item %I
//!       is replaced by the hour (12-hour clock) as a decimal number (01-12).
//!     @item %j
//!       is replaced by the day of the year as a decimal number (001-366).
//!     @item %k
//!       is replaced by the hour (24-hour clock) as a decimal number (0-23);
//!       single digits are preceded by a blank.
//!     @item %l
//!       is replaced by the hour (12-hour clock) as a decimal number (1-12);
//!       single digits are preceded by a blank.
//!     @item %M
//!       is replaced by the minute as a decimal number (00-59).
//!     @item %m
//!       is replaced by the month as a decimal number (01-12).
//!     @item %n
//!       is replaced by a newline.
//!     @item %p
//!       is replaced by national representation of either "ante meridiem" or
//!       "post meridiem" as appropriate.
//!     @item %R
//!       is equivalent to "%H:%M".
//!     @item %r
//!       is equivalent to "%I:%M:%S %p".
//!     @item %S
//!       is replaced by the second as a decimal number (00-60).
//!     @item %s
//!       is replaced by the number of seconfs since the 01 Janury 1970 UTC.
//!     @item %T
//!       is equivalent to "%H:%M:%S".
//!     @item %t
//!       is replaced by a tab.
//!     @item %U
//!       is replaced by the week number of the year (Sunday as the first day
//!       of the week) as decimal number (00-53).
//!     @item %u
//!       is replaced by the weekday (Monday as the first day of the week) as
//!       decimal number (1-7).
//!     @item %V
//!       is replaced by the week number of the year (Monday as first day of
//!       the week) as a decimal number (01-53). If the week containing
//!       January 1 has four or more days in the new year, then it is week 1;
//!       otherwise it is last week of the previous year, and the next week is
//!       week 1.
//!     @item %v
//!       is equivalent to "%e-%b-%Y".
//!     @item %W
//!       is replaced by the week number of the year (Monday as the first day 
//!       of the week) as a decimal number (00-53).
//!     @item %w
//!       is replaced by the weekday (Sunday as the first day of the week) as
//!       a decimal number (0-6).
//!     @item %X
//!       is replaced by national representation of the time.
//!     @item %x
//!       is replaced by national representation of the date.
//!     @item %Y
//!       is replaced by the year with century as a decimal number.
//!     @item %y
//!       is replaced by the year without century as a decimal number (00-99).
//!     @item %Z
//!       is replaced by the timezone name.
//!     @item %z
//!       is replaced by the timezone offset from UTC; a leading plus sign
//!       stands of east of UTC, a minus sign for west of UTC, hours and 
//!       minutes follow with two digits each and no delimiter between them
//!       (common form for RFC 822 / RFC 2822 date headers).
//!     @item %+
//!       is replaced by national representation of the date and time (the
//!       the format is similar to that produced by unix date(1) tool.
//!     @item %%
//!       is replaced by "%".
//!   @enddl
//! @param timestamp
//!   The timestamp.
//! @note
//!    Non RIS function, handled by _Caudium C module that calls system
//!    strftime(3).

//! @decl string extension(string what)
//!   Get the extension name from a filename string. Handles also
//!   known unix backup extensions as well eg '#' and '~' ending files. 
//! @param what
//!   The filename to get extension.
//! @returns 
//!   The extension string.
//! @note
//!   Non RIS function, handled by _Caudium C module.

//! @decl string get_address(string addr)
//!   Get the IP Address from Pike query_address string.
//! @param addr
//!   The address + port from Pike with the following format :
//!   "aaa.bbb.ccc.ddd portnumber".
//! @returns
//!   The IP Address string.
//! @example
//!   Pike v7.4 release 1 running Hilfe v3.5 (Incremental Pike Frontend)
//!   > Caudium.get_address("127.0.0.1 46021");
//!   (1) Result: "127.0.0.1"
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!   @[get_port]

//! @decl string get_port(string addr)
//!   Get the IPv4 port from Pike query_address string.
//! @param addr
//!   The address + port from Pike with the following format :
//!   "aaa.bbb.ccc.ddd portnumber".
//! @returns
//!   The IP Port string.
//! @example
//!   Pike v7.4 release 1 running Hilfe v3.5 (Incremental Pike Frontend)
//!   > Caudium.get_address("127.0.0.1 46021");
//!   (1) Result: "46021"
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!   @[get_address]
