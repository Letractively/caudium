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
 *
 */
/*
 * $Id$
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#ifndef _XOPEN_SOURCE
#define _XOPEN_SOURCE
#endif

#ifndef _XOPEN_SOURCE_EXTENDED
#define _XOPEN_SOURCE_EXTENDED
#endif

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "caudium_machine.h"
#include <fd_control.h>
#ifdef HAVE_STDIO_H
#include <stdio.h>
#else
#error "Your system doesn't seem to have the stdio.h header."
#endif
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#ifdef TIME_WITH_SYS_TIME_H
# include <sys/time.h>
# include <time.h>
#else
# ifdef HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif

#include <locale.h>

#include "caudium.h"
#include "getdate.h"
#include "datetime.h"

/* FreeBSD strptime() doesn't seems to be thread-safe */
#ifdef __FreeBSD__
#undef HAVE_STRPTIME
#endif

static struct pike_string *gd_bad_format;

#if defined(HAVE_GETDATE) || defined(HAVE_GETDATE_R)
static struct pike_string *getdate_errors[9];
#endif

#ifdef HAVE_STRPTIME
/* the first three formats are specified in the RFC2068 document, section
 * 3.3.1
 * The formats with is_anal == 1 are weird formats not specified in any RFC
 * - they are disabled by default.
 */
struct 
{
  char           *fmt;
  unsigned char   is_anal;
} is_modified_formats[] = {
  {"%a, %d %b %Y %H:%M:%S", 0}, /* RFC1123 */
  {"%A, %d %b %y %H:%M:%S", 0}, /* RFC850 */
  {"%a %b %d %H:%M:%S %Y", 0}, /* ANSI C asctime() format */
  {"%d-%m-%Y %H:%M:%S", 1},
  {"%d-%m-%y %H:%M:%S", 1},
  {"%a, %d %b %y %H:%M:%S", 1},
  {"%a %b %d %H:%M:%S %y", 1},
  {"%d %b %Y %H:%M:%S", 1},
  {"%d %b %Y %H:%M:%S", 1},
  {"%d %b %y %H:%M:%S", 1},
  {NULL, 0},
};

/*! @decl int strptime(string date, string format)
 *!  Parse the specified date according to the given format and put the
 *!  broken-down time in the mapping passed to the function.
 *!
 *! @param date
 *!  The date string to parse
 *!
 *! @param format
 *!  The format to be used when parsing the date. The format may contain
 *!  printf-style formatting codes consisting of a percent character
 *!  followed by a single character. The following formatting codes are
 *!  recognized:
 *!
 *!  @dl
 *!   @item %%
 *!    The % character.
 *!   @item %a or %A
 *!    The weekday name according to the current locale, in abbreviated
 *!    form or the full name.
 *!   @item %b or %B or %h
 *!     The month name according to the current locale, in abbreviated form
 *!     or the full name.
 *!   @item %c
 *!    The date and time representation for the current locale.
 *!   @item %C
 *!    The century number (0-99).
 *!   @item %d or %e
 *!    The day of month (1-31).
 *!   @item %D
 *!    Equivalent  to  %m/%d/%y.  (This  is the American style date, very
 *!    confusing to non-Americans, especially since %d/%m/%y is widely used
 *!    in Europe.  The ISO 8601 standard format is %Y-%m-%d.)
 *!   @item %H
 *!    The hour (0-23).
 *!   @item %I
 *!    The hour on a 12-hour clock (1-12).
 *!   @item %j
 *!    The day number in the year (1-366).
 *!   @item %m
 *!    The month number (1-12).
 *!   @item %M
 *!    The minute (0-59).
 *!   @item %n
 *!    Arbitrary whitespace.
 *!   @item %p
 *!    The locale's equivalent of AM or PM. (Note: there may be none.)
 *!   @item %r
 *!    The 12-hour clock time (using the locale's AM or PM).  In the POSIX
 *!    locale equivalent to %I:%M:%S %p.   If  t_fmt_ampm  is  empty  in
 *!    the LC_TIME part of the current locale then the behaviour is
 *!    undefined.
 *!   @item %R
 *!    Equivalent to %H:%M.
 *!   @item %S
 *!    The second (0-60; 60 may occur for leap seconds; earlier also 61 was
 *!    allowed).
 *!   @item %t
 *!    Arbitrary whitespace.
 *!   @item %T
 *!    Equivalent to %H:%M:%S.
 *!   @item %U
 *!    The week number with Sunday the first day of the week (0-53).  The
 *!    first Sunday of January is the first day of week 1.
 *!   @item %w
 *!    The weekday number (0-6) with Sunday = 0.
 *!   @item %W
 *!    The week number with Monday the first day of the week (0-53).  The
 *!    first Monday of January is the first day of week 1.
 *!   @item %x
 *!    The date, using the locale's date format.
 *!   @item %X
 *!    The time, using the locale's time format.
 *!   @item %y
 *!    The year within century (0-99).  When a century is not otherwise
 *!    specified, values in the range 69-99 refer to years in the twentieth
 *!    century (1969-1999); values in the range 00-68 refer to years in the
 *!    twenty-first century (2000-2068).
 *!   @item %Y
 *!    The year, including century (for example, 1991).
 *!  @enddl
 *!
 *! Some field descriptors can be modified by the E or O modifier
 *! characters to indicate that an alternative format or specification
 *! should be used. If the alternative format or specification does not
 *! exist in the current locale, the unmodified field descriptor is used.
 *! The E modifier specifies that the input string may contain alternative
 *! locale-dependent versions of the date and time representation:
 *!
 *!  @dl
 *!   @item %Ec
 *!    The locale's alternative date and time representation.
 *!   @item %EC
 *!    The name of the base year (period) in the locale's alternative representation.
 *!   @item %Ex
 *!    The locale's alternative date representation.
 *!   @item %EX
 *!    The locale's alternative time representation.
 *!   @item %Ey
 *!    The offset from %EC (year only) in the locale's alternative
 *!    representation.
 *!   @item %EY
 *!    The full alternative year representation.
 *!  @enddl
 *!
 *! The O modifier specifies that the numerical input may be in an
 *! alternative locale-dependent format:
 *!
 *!  @dl
 *!   @item %Od or %Oe
 *!    The day of the month using the locale's alternative numeric symbols;
 *!    leading zeros are permitted but not required.
 *!   @item %OH
 *!    The hour (24-hour clock) using the locale's alternative numeric
 *!    symbols.
 *!   @item %OI
 *!    The hour (12-hour clock) using the locale's alternative numeric
 *!    symbols.
 *!   @item %Om
 *!    The month using the locale's alternative numeric symbols.
 *!   @item %OM
 *!    The minutes using the locale's alternative numeric symbols.
 *!   @item %OS
 *!    The seconds using the locale's alternative numeric symbols.
 *!   @item %OU
 *!    The week number of the year (Sunday as the first day of the week)
 *!    using the locale's alternative numeric symbols.
 *!   @item %Ow
 *!    The number of the weekday (Sunday=0) using the locale's alternative
 *!    numeric symbols.
 *!   @item %OW
 *!    The week number of the year (Monday as the first day of the week)
 *!    using the locale's alternative numeric symbols.
 *!   @item %Oy
 *!    The year (offset from %C) using the locale's alternative numeric
 *!    symbols.
 *!  @enddl
 *!
 *! @returns
 *!  The date in the Unix time format.
 */
static void f_strptime(INT32 args)
{
  struct tm            tmret;
  struct pike_string  *date, *format;
  time_t               ret;
  
  get_all_args("strptime", args, "%S%S", &date, &format);
  pop_n_elems(args);
  
  strptime(date->str, format->str, &tmret);
  ret = mktime(&tmret);

  push_int(ret);
}
#endif /* STRPTIME */

/*
** method: string strftime(string f, int t)
**   strftime() function for pike
*/
#ifdef HAVE_STRFTIME
static void f_strftime(INT32 args) {
  time_t now;
  INT_TYPE timestamp = NULL;
  struct pike_string *ret;
  struct pike_string *format;
  /* FIXME:  Use dynamic loading... */
  char buf[1024];	/* I hate buf size... */

  get_all_args("_Caudium.strftime",args,"%S%i", &format, &timestamp);
  if(format->len > 1023)
    Pike_error("_Caudium.strftime(): Out of length in arg 1\n");
  if(format->len == 0)
    Pike_error("_Caudium.strftime(): Empty string in arg 1\n");
#ifdef DEBUG
  printf("IN : %s : %d\n",format->str, timestamp);
#endif
  now = (time_t)timestamp;
  strftime(buf, sizeof(buf), format->str, localtime(&now));
#ifdef DEBUG
  printf("Out : %s\n",buf);
#endif
  ret = make_shared_string(buf);
  pop_n_elems(args);
  push_string(ret);
}
#endif


#if defined(HAVE_GETDATE) || defined(HAVE_GETDATE_R)
/*! @decl int|array(int|string) getdate(string date)
 *!
 *! This method converts the passed date from the string format into the
 *! Unix time format. As it doesn't take the format string, it requires the
 *! DATEMSK environment variable to point to a file containing all the
 *! formats that are to be used in attempt to parse the passed date. The
 *! file must contain one format per line and the first matching line ends
 *! the parsing process. The matching is case-insensitive. See the
 *! @[strptime@] function for information on the formatting codes you can
 *! use in the pattern file.
 *!
 *! @param date
 *!  The date string to be parsed.
 *!
 *! @returns
 *!  The parsed date in the Unix time format or an array consisting of two
 *!  elements:
 *!
 *!  @array
 *!   @elem int 0
 *!    The error code as follows:
 *!    @int
 *!     @value 1
 *!      The DATEMSK environment variable is null or undefined.
 *!     @value 2
 *!      The template file cannot be opened for reading.
 *!     @value 3
 *!      Failed to get file status information.
 *!     @value 4
 *!      The template file is not a regular file.
 *!     @value 5
 *!      An error is encountered while reading the template file.
 *!     @value 6
 *!      Memory allocation failed (not enough memory available).
 *!     @value 7
 *!      There is no line in the file that matches the input.
 *!     @value 8
 *!      Invalid input specification.
 *!    @endint
 *!
 *!   @elem string 1
 *!    The error message corresponding to the error code.
 *!  @endarray
 *!
 *! @note
 *!  The API conforms to ISO 9899, POSIX 1003.1-2001
 */
static void f_getdate(INT32 args)
{
  struct tm            tmret, *tmptr;
  int                  err = -1;
  struct pike_string  *date;
  struct array        *aret;
  time_t               ret;
  
  get_all_args("getdate", args, "%S", &date);
  pop_n_elems(args);
  
#ifdef HAVE_GETDATE_R
  THREADS_ALLOW();
  err = getdate_r(date->str, &tmret);
  THREADS_DISALLOW();
  tmptr = &tmret;
#else
  tmptr = getdate(date->str);
  err = getdate_err;
#endif

  if (err || !tmptr) {
    push_int(err);
    if ((unsigned int)err > sizeof(getdate_errors) - 1 || err < 1)
      push_string(getdate_errors[0]);
    else
      push_string(getdate_errors[err]);
    aret = aggregate_array(2);
    push_array(aret);
  } else{
    ret = mktime(tmptr);
    if (ret >= 0)
      push_int(ret);
    else {
      push_int(8);
      push_string(getdate_errors[8]);
      aret = aggregate_array(2);
      push_array(aret);
    }
  }
}
#endif

/*! @decl int|string parse_date(string date)
 *!
 *! Parse the specified date and return its corresponding unix time
 *! value. This function uses the same parser code as the GNU date(1)
 *! utility.
 *!
 *! @param date
 *!  The date to be parsed.
 *!
 *! @returns
 *!  The integer unix time value on success, an error message otherwise.
 */
static void f_parse_date(INT32 args)
{
  struct pike_string   *date;
  time_t                ret;
  
  get_all_args("parse_date", args, "%S", &date);
  pop_n_elems(args);

  ret = get_date(date->str, NULL);
  if (ret < 0)
    push_string(gd_bad_format);
  else
    push_int(ret);
}

/*! @decl int is_modified(string header, int tmod, int|void use_weird)
 *!
 *!  This method is specific to Caudium and is used to test whether the
 *!  unix time passed in the tmod parameter is newer than the date passed
 *!  in the header argument. This method accepts formats required by
 *!  RFC2068 for the If-Modified-Since header and it will NOT parse any
 *!  other formats.
 *!
 *! @param header
 *!  The value of the If-Modified-Since header
 *!
 *! @param tmod
 *!  The unix time value to compare the header against
 *!
 *! @param use_weird
 *!  Caudium and Roxen used to accept several weird date formats with this
 *!  function. This implementation optionally supports and parses them. Set
 *!  this parameter to 1 to enable parsing of the weird formats. By default
 *!  the formats are not parsed.
 *!
 *! @returns
 *!  0 if the file was modified, 1 if it wasn't
 */
static void f_is_modified(INT32 args)
{
  struct pike_string   *header;
  int                   tmod, use_weird = 0, i;
  time_t                ret;
#ifdef HAVE_STRPTIME
  struct tm             ttm;
#endif /* HAVE_STRPTIME */

  if (args == 3)
    get_all_args("is_modified", args, "%S%d%d", &header, &tmod, &use_weird);
  else
    get_all_args("is_modified", args, "%S%d", &header, &tmod);
  
  pop_n_elems(args);

#ifdef HAVE_STRPTIME
  i = 0;
  while(is_modified_formats[i].fmt) {
/*    char      *tmp; */
    
    if (!is_modified_formats[i].is_anal || use_weird)
      if (strptime(header->str, is_modified_formats[i].fmt, &ttm))
        break;
    
    i++;
  }
  if (!is_modified_formats[i].fmt) {
    push_string(gd_bad_format);
    return;
  }

  if (ttm.tm_year < 100) {
    if (ttm.tm_year <= 68)
      ttm.tm_year += 2000;
    else
      ttm.tm_year += 1900;
  }

  ret = mktime(&ttm);
  if (ret >= 0)
    push_string(gd_bad_format);  
#else /* HAVE_STRPTIME */
  ret = get_date(header->str, NULL);
  if (ret < 0)
    push_string(gd_bad_format);
#endif /* HAVE_STRPTIME */

  if (tmod > ret)
    push_int(0);
  else
    push_int(1);
}

void init_datetime(void)
{
#if defined(HAVE_GETDATE) || defined(HAVE_GETDATE_R)
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[0], "Unknown getdate error code.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[1], "The DATEMSK environment variable is null or undefined.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[2], "The template file cannot be opened for reading.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[3], "Failed to get file status information.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[4], "The template file is not a regular file.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[5], "An error is encountered while reading the template file.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[6], "Memory allocation failed (not enough memory available).");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[7], "There is no line in the file that matches the input.");
  MAKE_CONSTANT_SHARED_STRING(getdate_errors[8], "Invalid input specification.");
  MAKE_CONSTANT_SHARED_STRING(gd_bad_format, "Bad date format. Could not convert.");
  
  ADD_FUNCTION("getdate", f_getdate, tFunc(tString tOr(tInt, tVoid), tInt), 0);
#endif
  
#ifdef HAVE_STRPTIME
  ADD_FUNCTION("strptime", f_strptime, tFunc(tString tString tMapping, tInt), 0);
#endif

#ifdef HAVE_STRFTIME
  ADD_FUNCTION("strftime", f_strftime, tFunc(tString tInt, tString), 0);
#endif
  
  ADD_FUNCTION("parse_date", f_parse_date, tFunc(tString, tInt), 0);
  ADD_FUNCTION("is_modified", f_is_modified, tFunc(tString tInt tOr(tInt, tVoid), tInt), 0);
}
