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
  return Caudium.Parse.parse_html(data, tags, containers, @args);
#else
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
  return Caudium.Parse.parse_html_lines(data, tags, containers, @args);
#else
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

//! Return a short date string from a time @{int@}
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
