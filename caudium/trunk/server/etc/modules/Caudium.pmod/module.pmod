/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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

//! 
constant cvs_version = "$Id$";

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

//
//! @decl int strptime(string date, string format)
//!  Parse the specified date according to the given format and put the
//!  broken-down time in the mapping passed to the function.
//!
//! @param date
//!  The date string to parse
//!
//! @param format
//!  The format to be used when parsing the date. The format may contain
//!  printf-style formatting codes consisting of a percent character
//!  followed by a single character. The following formatting codes are
//!  recognized:
//!
//!  @dl
//!   @item %%
//!    The % character.
//!   @item %a
//!    The weekday name according to the current locale, in abbreviated
//!    form or the full name.
//!   @item %A
//!    Same as %a
//!   @item %b
//!     The month name according to the current locale, in abbreviated form
//!     or the full name.
//!   @item %B
//!     Same as %b
//!   @item %h
//!     Same as %b
//!   @item %c
//!    The date and time representation for the current locale.
//!   @item %C
//!    The century number (0-99).
//!   @item %d
//!    The day of month (1-31).
//!   @item %e
//!    Same as %e
//!   @item %D
//!    Equivalent  to  %m/%d/%y.  (This  is the American style date, very
//!    confusing to non-Americans, especially since %d/%m/%y is widely used
//!    in Europe.  The ISO 8601 standard format is %Y-%m-%d.)
//!   @item %H
//!    The hour (0-23).
//!   @item %I
//!    The hour on a 12-hour clock (1-12).
//!   @item %j
//!    The day number in the year (1-366).
//!   @item %m
//!    The month number (1-12).
//!   @item %M
//!    The minute (0-59).
//!   @item %n
//!    Arbitrary whitespace.
//!   @item %p
//!    The locale's equivalent of AM or PM. (Note: there may be none.)
//!   @item %r
//!    The 12-hour clock time (using the locale's AM or PM).  In the POSIX
//!    locale equivalent to %I:%M:%S %p.   If  t_fmt_ampm  is  empty  in
//!    the LC_TIME part of the current locale then the behaviour is
//!    undefined.
//!   @item %R
//!    Equivalent to %H:%M.
//!   @item %S
//!    The second (0-60; 60 may occur for leap seconds; earlier also 61 was
//!    allowed).
//!   @item %t
//!    Arbitrary whitespace.
//!   @item %T
//!    Equivalent to %H:%M:%S.
//!   @item %U
//!    The week number with Sunday the first day of the week (0-53).  The
//!    first Sunday of January is the first day of week 1.
//!   @item %w
//!    The weekday number (0-6) with Sunday = 0.
//!   @item %W
//!    The week number with Monday the first day of the week (0-53).  The
//!    first Monday of January is the first day of week 1.
//!   @item %x
//!    The date, using the locale's date format.
//!   @item %X
//!    The time, using the locale's time format.
//!   @item %y
//!    The year within century (0-99).  When a century is not otherwise
//!    specified, values in the range 69-99 refer to years in the twentieth
//!    century (1969-1999); values in the range 00-68 refer to years in the
//!    twenty-first century (2000-2068).
//!   @item %Y
//!    The year, including century (for example, 1991).
//!  @enddl
//!
//! Some field descriptors can be modified by the E or O modifier
//! characters to indicate that an alternative format or specification
//! should be used. If the alternative format or specification does not
//! exist in the current locale, the unmodified field descriptor is used.
//! The E modifier specifies that the input string may contain alternative
//! locale-dependent versions of the date and time representation:
//!
//!  @dl
//!   @item %Ec
//!    The locale's alternative date and time representation.
//!   @item %EC
//!    The name of the base year (period) in the locale's alternative representation.
//!   @item %Ex
//!    The locale's alternative date representation.
//!   @item %EX
//!    The locale's alternative time representation.
//!   @item %Ey
//!    The offset from %EC (year only) in the locale's alternative
//!    representation.
//!   @item %EY
//!    The full alternative year representation.
//!  @enddl
//!
//! The O modifier specifies that the numerical input may be in an
//! alternative locale-dependent format:
//!
//!  @dl
//!   @item %Od
//!    The day of the month using the locale's alternative numeric symbols;
//!    leading zeros are permitted but not required.
//!   @item %Oe
//!    Same as %Od
//!   @item %OH
//!    The hour (24-hour clock) using the locale's alternative numeric
//!    symbols.
//!   @item %OI
//!    The hour (12-hour clock) using the locale's alternative numeric
//!    symbols.
//!   @item %Om
//!    The month using the locale's alternative numeric symbols.
//!   @item %OM
//!    The minutes using the locale's alternative numeric symbols.
//!   @item %OS
//!    The seconds using the locale's alternative numeric symbols.
//!   @item %OU
//!    The week number of the year (Sunday as the first day of the week)
//!    using the locale's alternative numeric symbols.
//!   @item %Ow
//!    The number of the weekday (Sunday=0) using the locale's alternative
//!    numeric symbols.
//!   @item %OW
//!    The week number of the year (Monday as the first day of the week)
//!    using the locale's alternative numeric symbols.
//!   @item %Oy
//!    The year (offset from %C) using the locale's alternative numeric
//!    symbols.
//!  @enddl
//!
//! @returns
//!  The date in the Unix time format.
//

//
//! @decl int is_modified(string header, int tmod, int|void use_weird)
//!
//!  This method is specific to Caudium and is used to test whether the
//!  unix time passed in the tmod parameter is newer than the date passed
//!  in the header argument. This method accepts formats required by
//!  RFC2068 for the If-Modified-Since header and it will NOT parse any
//!  other formats.
//!
//! @param header
//!  The value of the If-Modified-Since header
//!
//! @param tmod
//!  The unix time value to compare the header against
//!
//! @param use_weird
//!  Caudium and Roxen used to accept several weird date formats with this
//!  function. This implementation optionally supports and parses them. Set
//!  this parameter to 1 to enable parsing of the weird formats. By default
//!  the formats are not parsed.
//!
//! @returns
//!  0 if the file was modified, 1 if it wasn't
//!
//! @note
//!   Non RIS function, handled by _Caudium C module.
//

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

//! @decl string http_decode(string what)
//!  Decode the given string from "safe" string according to
//!  RFC 2396 to plain characters. Eg from strings that
//!  are encoded with "%XX".
//! @param what
//!  The string to decode
//! @returns
//!  String decoded.
//! @note
//!  Non RIS function, handled by _Caudium C module.
//! @seealso
//!  @[http_encode] @[http_encode_cookie] @[http_encode_string]
//!  @[http_encode_url] @[http_decode_url]

//! @decl string http_encode(string what)
//!   Encode the given string into "safe" string according to RFC 2396 eg.
//!   all non ascii characters (A-Z,a-Z and 0-9 are not encoded) are encoded
//!   to "%XX" format.
//! @param what
//!   The string to encode
//! @returns
//!   The string encoded.
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!  @[http_decode] @[http_encode_cookie] @[http_encode_string]
//!  @[http_encode_url] @[http_decode_url]

//! @decl string http_encode_cookie(string what)
//!   Encode the specified string in as to the HTTP Cookie standard.
//!   The following caracters will be replaced by "%XX" standard : = , ; % :
//! @param what
//!   The string to encode.
//! @returns
//!   The HTTP cookie encoded string.
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!  @[http_decode] @[http_encode] @[http_encode_string]
//!  @[http_encode_url] @[http_decode_url]

//! @decl string http_encode_string(string what)
//!   HTTP encode the specified string and return it. This means replacing
//!   the following characters to the "%XX" formal : null (char 0), space,
//!   tab, carriage return, newline, percent and signe and double quotes.
//! @param what
//!   The string to encode.
//! @returns
//!   The HTTP encoded string.
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!  @[http_decode] @[http_encode] @[http_encode_cookie]
//!  @[http_encode_url] @[http_decode_url]

//! @decl string http_encode_url(string what)
//!   URL encode the specified string and return it. This means replacing
//!   the following characters to the "%XX" format: null (char 0), space,
//!   tab, carriage return, newline, and % ' ' # & ? = / : +
//! @param what
//!   The string to encode.
//! @returns
//!   The URL encoded string.
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!  @[http_decode] @[http_encode] @[http_encode_cookie]
//!  @[http_encode_string] @[http_decode_url]

//! @decl string http_decode_url(string what)
//!   URL decode the specifed string and return it. This means replacing
//!   all "%XX" string format into their corresponding ASCII code. This 
//!   function is allmost the same as @[http_decode] with the addition to
//!   decoding "+" into space.
//! @param what
//!   The string to decode
//! @returns
//!   The URL decoded string.
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @seealso
//!  @[http_decode] @[http_encode] @[http_encode_cookie]
//!  @[http_encode_string] @[http_encode_url]

//! @decl mapping parse_headers(string headers);
//!   Format all headers into a mapping
//! @param headers
//!   The header string to get parsed.
//! @returns
//!   The headers in a mapping
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @example
//!
//! Pike v7.4 release 1 running Hilfe v3.5 (Incremental Pike Frontend)
//! > Caudium.parse_headers("User-Agent: Mozilla");
//! (1) Result: ([ /* 1 element */
//!               "user-agent":"Mozilla"
//!             ])
//! > Caudium.parse_headers("Host: www.plonk.com:80");
//! (2) Result: ([ /* 1 element */
//!               "host":"www.plonk.com:80"
//!             ])
//! > Caudium.parse_headers("User-Agent: Mozilla\r\nFoo: pof\r\nhost: ponk\r\n\r\n");
//! (3) Result: ([ /* 3 elements */
//!               "foo":"pof",
//!               "host":"ponk",
//!               "user-agent":"Mozilla"
//!             ])

//! @decl string parse_prestates(string url, multiset prestates, multiset internals)
//!  Parse the given url string and fill the passed multiseds with, 
//!  repectively, "normal" and "internal" prestates. Note that the latter
//!  is filled only if the FIRST prestate is "internal" and in such case the
//!  the former has just one member : "internal".
//! @param url
//!  The url string to get prestates from.
//! @param prestates
//!  Multiset where "normal" prestates are filled.
//! @param internals
//!  Multiset where "internal" prestates are filled.
//! @returns
//!  Returns the passed url with the prestate part.
//! @note
//!   Non RIS function, handled by _Caudium C module.
//! @example
//! Pike v7.4 release 1 running Hilfe v3.5 (Incremental Pike Frontend)
//! > multiset prestates = (< >);
//! > multiset internal = (< >);
//! > Caudium.parse_prestates("/(internal,images,test)/index.rxml",prestates,internal);
//! (1) Result: "/index.rxml"
//! > prestates;
//! (2) Result: (< /* 1 element */
//!                 "internal"
//!             >)
//! > internal;
//! (3) Result: (< /* 2 elements */
//!                 "test",
//!                 "images"
//!             >)
//! > prestates = (< >);
//! (4) Result: (< >)
//! > internal = (< >);
//! (5) Result: (< >)
//! > Caudium.parse_prestates("/(test=1)/foo.c",prestates,internal);
//! (6) Result: "/foo.c"
//! > prestates;
//! (7) Result: (< /* 1 element */
//!                 "test=1"
//!             >)
//! > internal;
//! (8) Result: (< >)

//! @decl void parse_query_string(string query, mapping results)
//!  Format and unescape all query string and add the result to the
//!  mapping @[results].
//! @param query
//!  The query string to parse.
//! @param results
//!  The mapping where results will be added.
//! @returns
//!  Void. Or throw when there is an error (usualy when a memory problem
//!  happened).
//! @note
//!  Non RIS code, handled by _Caudium C module.
//! @example
//! Pike v7.4 release 1 running Hilfe v3.5 (Incremental Pike Frontend)
//! > mapping pof = ([ ]);
//! > Caudium.parse_query_string("toto=zzz&plink=pof%20zou", pof);
//! (1) Result: 0
//! > pof;
//! (2) Result: ([ /* 2 elements */
//!               "plink":"pof zou",
//!               "toto":"zzz"
//!             ])

// private form sexpr_eval()
private array permitted = ({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                             "-", "*", "+", "/", "%", "&", "|", "(",")" });

//! Do some expression calculation (eg addition etc).
//! @param what
//!   What to calculate
string sexpr_eval(string what) {
  array  q = what / " ";
  mixed  error;
  string ret;

  if(!what || !sizeof(what))
    return "";

  what = "mixed foo() { return "+(q - (q - permitted))*""+";}";

  error = catch {
    ret = compile_string(what)()->foo();
  };

  if (error) return "";

  return ret;
}

//! parse_html like function.
//! This function will use spider.parse_html() only if OLD_SPIDER define
//! is set.
//! @note
//!   Work in progress
string parse_html(string data, mapping(string:function|string) tags,
                  mapping(string:function|string) containers, mixed ... args) {
#ifndef OLD_SPIDER
#ifdef COMPARE_SPIDER
  string oldp = spider.parse_html(data, tags, containers, @args);
  string newp = Caudium.Parse.parse_html(data, tags, containers, @args);
  if (oldp != newp)
    write("parse_html() : old spider: %O, new one: %O\n", oldp, newp);
  return newp; 
#else /* COMPARE_SPIDER */
  return Caudium.Parse.parse_html(data, tags, containers, @args);
#endif /* COMPARE_SPIDER */
#else  /* OLD_SPIDER */
  return spider.parse_html(data, tags, containers, @args);
#endif /* OLD_SPIDER */
}

//! parse_html_lines function.
//! This function will use spider.parse_html_lines() only if OLD_SPIDER
//! define is set.
//! @note
//!   Work in progress
string parse_html_lines(string data, mapping tags, mapping containers, 
                        mixed ... args) {
#ifndef OLD_SPIDER
#ifdef COMPARE_SPIDER
  string oldp = spider.parse_html_lines(data, tags, containers, @args);
  string newp = Caudium.Parse.parse_html_lines(data, tags, containers, @args);
  if (oldp != newp)
    write("parse_html_lines() : old spider: %O, new one: %O\n", oldp, newp);
  return newp;
#else /* COMPARE_SPIDER */ 
  return Caudium.Parse.parse_html_lines(data, tags, containers, @args);
#endif /* COMPARE_SPIDER */
#else /* OLD_SPIDER */
  return spider.parse_html_lines(data, tags, containers, @args);
#endif /* OLD_SPIDER */
}

//! Unload a programm from Caudium master
//! @param p
//!   The name of program to unload
//! @note
//!   Convenience function to ease reloadling of inherited modules
//!   during development for example. Non-RIS call.
void unload_program(string p) {
  m_delete(master()->programs,search(master()->programs,(program)p));
}

mapping add_http_header(mapping to, string name, string value)
//! Adds a header @[name] with value @[value] to the header style
//! mapping @[to] (which commonly is @tt{id->misc[" _extra_heads"]@})
//! if no header with that value already exist.
{
  if(to[name]) {
    if(arrayp(to[name])) {
      if (search(to[name], value) == -1)
        to[name] += ({ value });
    } else {
      if (to[name] != value)
        to[name] = ({ to[name], value });
    }
  }
  else
    to[name] = value;
  return to;
}

//!   Prepend the URL with the prestate specified. The URL is a path
//!   beginning with /.
//! @param url
//!   The URL.
//! @param state
//!   The multiset with prestates.
//! @returns
//!   The new URL
string add_pre_state( string url, multiset state )
{
  if(!url)
    error("URL needed for add_pre_state()\n");
  if(!state || !sizeof(state))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/(" + sort(indices(state)) * "," + ")" + url ;
}

//!  Internal glob matching function.
//! @param w
//!  String to match.
//! @param a
//!  Glob patterns to match against the string.
//! @returns
//!  1 if a match occured, -1 if the string to match is invalid, 0 if
//!  no match occured.
int _match(string w, array (string) a) {
  string q;
  if (!stringp(w)) // Internal request..
    return -1;
  foreach (a, q) 
    if (stringp(q) && strlen(q) && glob(q, w)) 
      return 1; 
}

//! Return a "short_name" of a virtual server. This is simply
//! the name in lower case with space replaced with underscore,
//! used for storing the configuration on disk, log directories etc...
//! @param name
//!  The name of the virtual server.
string short_name(string name) {
  return lower_case(replace(name, " ", "_"));
}

//! Strips the Caudium config cookie part of a path (not the url).
//! The cookie part is everything withing < and > right after the 
//! first slash.
//! @param from
//!   The path from which the cookie part will be stripped.
//! @fixme
//!   Shouldn't not be better to do that with Regexps ????
string strip_config(string from) {
  sscanf(from, "<%*s>%s", from);
  return from;
}

//! Strips the Caudium prestate part of a path (not the URL).
//! The prestate part is everything within ( and ) right after the first
//! slash.
//! @param from
//!  The path from which the prestate part will be stripped.
//! @fixme
//!  Shouldn't not be better to do that with Regexps ????
string strip_prestate(string from) {
  sscanf(from, "/(%*s)%s", from);
  return from;
}

//! Return a short date string from a time int.
//! @param timestamp
//!   The Unix time value to convert
//! @returns
//!   String representation of the params.
//! @note
//!   Non-RIS code 
//! @example
//! Pike v7.4 release 10 running Hilfe v3.5 (Incremental Pike Frontend)
//! > Caudium.short_date(time());                                      
//! (1) Result: "Mar  1 00:41"     
string short_date(int timestamp) {
#if constant(_Caudium.strftime)
  return _Caudium.strftime("%b %e %H:%M",timestamp);
#else /* constant(_Caudium.strftime) */
  // Fail-back function if strftime() doesn't exist.
  // I really think that we should ask for strftime()

  int      date = time(1);
  string   ctimed = ctime(date)[20..23];
  string   ctimet = ctime(timestamp);

  if ( ctimed < ctimet[20..23])
    return ctimet[4..9] +" "+ ctimet[20..23];

  return ctimet[4..9] +" "+ ctimet[11..15];
#endif /* constant(_Caudium.strftime) */
}

//! Converts html entities coded chars to unicode
//! @param str
//!  The string to convert, contains the html entities
//! @returns
//!  A unicde string
string html_to_unicode(string str) {
  if(!stringp(str))
    return str;
  return replace((string)str, Caudium.Const.replace_entities,
                              Caudium.Const.replace_values);
}

//! Convert unicode string to html entity coded string
//! @param str
//!  The string to convert, contains unicode string
//! @returns
//!  HTML encoded string
string unicode_to_html(string str) {
  if(!stringp(str))
    return str;
  return replace((string)str, Caudium.Const.replace_values,
                              Caudium.Const.replace_entities);
}

// Used for is_safe_string()
private constant safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"/"";
private constant empty_strings = ({
  "","","","","","","","","","","","","","","","","","","","","","","","","",
  "","","","","","","","","","","","","","","","","","","","","","","","","",
  "","","","","","","","","","","","",
});

//!  Check if a string contains only safe characters, which are defined as
//!  a-z, A-Z and 0-9. Mainly used internally by make_tag_attributes.
//! @param in
//!  The string to check.
//! @returns
//!  1 if the test contains only the safe characters, 0 otherwise.
int is_safe_string(string in) {
  return strlen(in) && !strlen(replace(in, safe_characters, empty_strings));
}

//!  Convert a mapping with key-value pairs to tag attribute format.
//! @param in
//!  The mapping with the attributes
//! @returns
//!  The string of attributes.
string make_tag_attributes(mapping in){
  
  // remove "/" that can remain from the parsing of a <tag /> 
  m_delete(in, "/");
  
  array a=indices(in), b=values(in);

  for (int i=0; i<sizeof(a); i++)
    if (is_safe_string(b[i]))
      a[i]+="=\"" +b[i] + "\"";
    else
      // Bug inserted again. Grmbl.
      a[i]+="=\""+replace(b[i], ({ "\"", "<", ">" //, "&"
      }) ,
                          ({ "&quot;", "&lt;", "&gt;" //, "&amp;"
                          }))+"\"";
  return a*" ";
}

//!  Build a tag with the specified name and attributes.
//! @param tag
//!  The name of the tag.
//! @param in
//!  The mapping with the attributes
//! @returns
//!  A string containing the tag with attributes.
string make_tag(string tag,mapping in) {
  string q = make_tag_attributes(in);
  return "<"+tag+(strlen(q)?" "+q:"")+">";
}

//!  Build a container with the specified name, attributes and content.
//! @param tag
//!  The name of the container.
//! @param in
//!  The mapping with the attributes
//! @param contents
//!  The contents of the container.
//! @returns
//!  A string containing the finished container
string make_container(string tag,mapping in, string contents) {
  return make_tag(tag,in)+contents+"</"+tag+">";
}

//! Add config part and prestate
//! @param url
//!  URL path to work with
//! @param config
//!  The Configuration parts to add
//! @param prestate
//!  Prestates to add
string add_config( string url, array config, multiset prestate) {
  if (!sizeof(config)) 
    return url;
  
  if (strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  
  return "/<" + config * "," + ">" + Caudium.add_pre_state(url, prestate);
}

//! Converts miliseconds to seconds
//!
//! @param t
//!  Number of miliseconds.
//!
//! @returns
//!  A string representation of the passed value converted to seconds.
//!
//! @fixme
//!   Gross and RIS code.
string msectos(int t) {
  if(t<1000) { /* One sec. */
    return sprintf("0.%02d sec", t/10);
  } else if(t<6000) {  /* One minute */
    return sprintf("%d.%02d sec", t/1000, (t%1000 + 5) / 10);
  } else if(t<3600000) { /* One hour */
    return sprintf("%d:%02d m:s", t/60000,  (t%60000)/1000);
  }
  
  return sprintf("%d:%02d h:m", t/3600000, (t%3600000)/60000);
}

//! Checks if the given filename ends with a backup extension
//! Backup extensions are: #, ~, .old and .bak
//! @param f
//!  The filename to check
//! @returns
//!  1 if the filename ends with a backup extension or is empty
//!  0 otherwise
//! @note
//!   RIS code ?
//! @fixme
//!   Optimize that since it is used in filesystem.pike (in C?).
int backup_extension( string f ) {
  if (!strlen(f)) 
    return 1;
  
  return (f[-1] == '#' || f[-1] == '~' 
          || (f[-1] == 'd' && sscanf(f, "%*s.old")) 
          || (f[-1] == 'k' && sscanf(f, "%*s.bak")));
}

//! Calculates the size (memory) usage of some element
//!
//! @param x
//!  Anything you want to measure the memory usage for.
//!
//! @returns
//!  Memory usage of the argument
//! @fixme
//!   Grosss !
int get_size(mixed x) {
  if (mappingp(x))
    return 8 + 8 + get_size(indices(x)) + get_size(values(x));
  else if (stringp(x))
    return strlen(x)+8;
  else if (arrayp(x)) {
    mixed f;
    int i;
    foreach(x, f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if (multisetp(x)) {
    mixed f;
    int i;
    foreach(indices(x), f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if (objectp(x) || functionp(x)) {
    return 8 + 16; // (refcount + pointer) + object struct.
    // Should consider size of global variables / refcount 
  }
  return 20; // Ints and floats are 8 bytes, refcount and float/int.
}

//!
//! @fixme
//!   Used only in oldaccessed thing. Gross and somewhat RIS code...
int ipow(int what, int how) {
  int r=what;
  if (!how)
    return 1;
  
  while (how-=1)
    r *= what;
  
  return r;
}

//! Simplifies the path by removing any relative elements in the middle of
//! it (like @tt{../.@} etc.
//!
//! @param file
//!  The path to be simplified
//!
//! @returns
//!  The simplified path string.
//!
//! @note
//!   Non-RIS code
string simplify_path(string file)
{
  string   ret;
  mixed    error = catch {
    ret = Stdio.simplify_path(file);
  };

  if (!error)
    return ret;
  
  return file; // better to return the original than 0
}

//! Converts a string representing a HTTP date into a UNIX time value.
//!
//! @param date
//!  The date string to be converted
//!
//! @returns
//!  The UNIX time value for the date or -1 if there is an error.
//!
//! @note
//!   Non-RIS implementation;
//! 
//! @fixme
//!   Make this in C !!!
int httpdate_to_time(string date) {
  if (intp(date))
    return -1;

  int   ret;
  mixed error = catch {
    ret = Calendar.parse("%e, %a %M %Y %h:%m:%s %z", date)->unix_time();
  };

  if (error) {
    //report_error("httpdate_to_time error: %O", error);
    return -1;
  }
  
  return ret;
}

//! Converts an integer into a Roman digit
//!
//! @param m
//!  The integer to be converted
//!
//! @returns
//!  A string representing the Roman equivalent of the passed integer.
//!
//! @note
//!  Non-RIS implementation
string int2roman(int m) {
  if (m>10000||m<0)
    return "que";

  mixed   error;
  string  ret;

  error = catch {
    ret = String.int2roman(m);
  };

  if (error)
    return "que";

  return ret;
}

//! Converts an integer number into a string
//!
//! @param num
//!  Integer to be converted
//!
//! @param params
//!  Mapping with parameters. Currently known parameters are:
//!
//!   @mapping
//!     @member string "type"
//!       Type of the returned string. Can be either of:
//!         @dl
//!           @item string
//!             A normal string representation of the integer. See below
//!             for the description of additional options available through
//!             the @tt{names@} parameter.
//!           @item roman
//!             A Roman representaion of the integer.
//!         @enddl
//!
//!     @member mixed "lower"
//!       If present, the resulting string will be all in lower case.
//!
//!     @member mixed "upper"
//!       If present, the resulting string will be all in upper case.
//!
//!     @member mixed "capitalize"
//!       If present, the resulting string will be capitalized.
//!   @endmapping
//!
//! @param names
//!  If the string type was chosen this parameter can be used to convert
//!  digits into their string representation in two ways. If mixed is a
//!  @tt{function@} then it will be called with the integer as a parameter
//!  and it is supposed to return a string representing the integer. If, on
//!  the other hand, this parameter is an array then each array element
//!  represents a name for the digit corresponding to its position in the
//!  array.
//!
//! @returns
//!  String representation of the passed integer.
//!
//! @note
//!  Non-RIS implementation
string number2string(int num ,mapping params, mixed names) {
  string ret;
  
  switch (params->type) {
      case "string":
        if (functionp(names)) {
          ret = names(num);
          break;
        }
        
        if (!arrayp(names) || num < 0 || num >= sizeof(names))
          ret = "";
        else
          ret = names[num];
        break;
        
      case "roman":
        ret = int2roman(num);
        break;
        
      default:
        return (string)num;
  }
  
  if (params->lower)
    return lower_case(ret);
  
  if (params->upper)
    return upper_case(ret);
  
  if (params->cap || params->capitalize)
    return String.capitalize(ret);
  
  return ret;
}

// used for image_from_type()
private static mapping(string:string) ift = ([
  "unknown" : "internal-gopher-unknown",
  "audio" : "internal-gopher-sound",
  "sound" : "internal-gopher-sound",
  "image" : "internal-gopher-image",
  "application" : "internal-gopher-binary",
  "text" : "internal-gopher-text"
]);

//! Gets image from type
//! @note
//!   non-RIS code
//! @fixme
//!   Undocumented.
string image_from_type(string t) {
  if (t) {
    sscanf(t, "%s/%*s", t);

    if (ift[t])
      return ift[t];
  }
  
  return ift->unknown;
}

//! Returns the size as a memory size string with suffix,
//! e.g. 43210 is converted into "42.2 kb". To be correct
//! to the latest standards it should really read "42.2 KiB",
//! but we have chosen to keep the old notation for a while.
//! The function knowns about the quantifiers kilo, mega, giga,
//! tera, peta, exa, zetta and yotta.
string sizetostring(int size) {
  if (size < 0)
    return "--------";
  return String.int2size(size);  
}

//! Encodes str for use as a value in an html tag.  
//!
//! @param str
//!   String to encode
string html_encode_tag_value(string str)  
{  
   return "\"" + replace(str, ({"&", "\""}), ({"&amp;", "&quot;"})) + "\"";  
}

//! This determines the full module name in approximately the same way
//! as the config UI.
//!
//! @param module
//!  Module object whos name is needed.
//!
//! @returns
//!  The module name
string get_modfullname (object module)
{
  if (module) {
    string name = 0;
    if (module->query_name)
      name = module->query_name();
    
    if (!name || !sizeof (name))
      name = module->register_module()[1];
    return name;
  } else
    return 0;
}

//! Quote content in a multitude of ways. Used primarily by do_output_tag
//!
//! @param val
//!  Value to encode.
//!
//! @param encoding
//!  Desired string encoding on return:
//!
//!  @dl
//!    @item none
//!      Returns the value verbatim
//!    @item http
//!      HTTP encoding.
//!    @item cookie
//!      HTTP cookie encoding
//!    @item url
//!      HTTP encoding, including special characters in URLs
//!    @item html
//!      For generic html text and in tag arguments. Does
//!      not work in RXML tags (use dtag or stag instead)
//!    @item dtag
//!      Quote quotes for a double quoted tag argument. Only
//!      for internal use, i.e. in arguments to other RXML tags
//!    @item stag
//!      Quote quotes for a single quoted tag argument. Only
//!      for internal use, i.e. in arguments to other RXML tags
//!    @item pike
//!      Pike string quoting (e.g. for use in the &lt;pike&gt; tag)
//!    @item js|javascript
//!      Javascript string quoting
//!    @item mysql
//!      MySQL quoting
//!    @item mysql-dtag
//!      MySQL quoting followed by dtag quoting
//!    @item mysql-pike
//!      MySQL quoting followed by Pike string quoting
//!    @item sql|oracle
//!      SQL/Oracle quoting
//!    @item sql-dtag/oracle-dtag
//!      SQL/Oracle quoting followed by dtag quoting
//!  @enddl
//!
//! @returns
//!  The encoded string
string roxen_encode( string val, string encoding )
{
  switch (encoding) {
      case "none":
      case "":
        return val;
   
      case "http":
        // HTTP encoding.
        return http_encode_string (val);
     
      case "cookie":
        // HTTP cookie encoding.
        return http_encode_cookie (val);
     
      case "url":
        // HTTP encoding, including special characters in URL:s.
        return http_encode_url(val);
       
      case "html":
        // For generic html text and in tag arguments. Does
        // not work in RXML tags (use dtag or stag instead).
        return _Roxen.html_encode_string (val);
     
      case "dtag":
        // Quote quotes for a double quoted tag argument. Only
        // for internal use, i.e. in arguments to other RXML tags.
        return replace (val, "\"", "\"'\"'\"");
     
      case "stag":
        // Quote quotes for a single quoted tag argument. Only
        // for internal use, i.e. in arguments to other RXML tags.
        return replace(val, "'", "'\"'\"'");
       
      case "pike":
        // Pike string quoting (e.g. for use in a <pike> tag).
        return replace (val,
                        ({ "\"", "\\", "\n" }),
                        ({ "\\\"", "\\\\", "\\n" }));

      case "js":
      case "javascript":
        // Javascript string quoting.
        return replace (val,
                        ({ "\b", "\014", "\n", "\r", "\t", "\\", "'", "\"" }),
                        ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
                           "\\'", "\\\"" }));
       
      case "mysql":
        // MySQL quoting.
        return replace (val,
                        ({ "\"", "'", "\\" }),
                        ({ "\\\"" , "\\'", "\\\\" }) );
       
      case "sql":
      case "oracle":
        // SQL/Oracle quoting.
        return replace (val, "'", "''");
       
      case "mysql-dtag":
        // MySQL quoting followed by dtag quoting.
        return replace (val,
                        ({ "\"", "'", "\\" }),
                        ({ "\\\"'\"'\"", "\\'", "\\\\" }));
       
      case "mysql-pike":
        // MySQL quoting followed by Pike string quoting.
        return replace (val,
                        ({ "\"", "'", "\\", "\n" }),
                        ({ "\\\\\\\"", "\\\\'",
                           "\\\\\\\\", "\\n" }) );
       
      case "sql-dtag":
      case "oracle-dtag":
        // SQL/Oracle quoting followed by dtag quoting.
        return replace (val,
                        ({ "'", "\"" }),
                        ({ "''", "\"'\"'\"" }) );
       
      default:
        // Unknown encoding. Let the caller decide what to do with it.
        return 0;
  }
}

//! method: string fix_relative(string file, object id)
//!  Transforms relative paths to absolute ones in the virtual filesystem
//! arg: string file
//!  The relative path to transform
//! arg: object id
//!  The caudium id object
//! returns:
//!  A string containing the absolute path in he virtual filesystem
string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') 
    ;
  else if(file != "" && file[0] == '#') 
    file = id->not_query + file;
  else
    file = dirname(id->not_query) + "/" +  file;
  
  return simplify_path(file);
}

/*
 * If you visit a file that doesn't containt these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
