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

#ifdef HAVE_TIME_H
#include <time.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

#include "caudium.h"

#if defined(HAVE_GETDATE) || defined(HAVE_GETDATE_R)
static struct pike_string *getdate_errors[9];
#endif

#ifdef HAVE_STRPTIME
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
  time_t               ret;
  int                  err = -1;
  struct pike_string  *date;
  struct array        *aret;
  
  get_all_args("getdate", args, "%S", &date);
  pop_n_elems(args);
  
#ifdef HAVE_GETDATE_R
  err = getdate_r(date->str, &tmret);
  tmptr = &tmret;
#else
  tptr = getdate(date->str);
  err = getdate_err;
#endif

  if (err || !tmptr) {
    push_int(err);
    if (err > sizeof(getdate_errors) - 1 || err < 1)
      push_string(getdate_errors[0]);
    else
      push_string(getdate_errors[err]);
    aret = aggregate_array(2);
    push_array(aret);
  } else{
    ret = mktime(tmptr);
    push_int(ret);
  }
}
#endif

static void f_parse_date(INT32 args)
{}

static void f_difftime(INT32 args)
{}

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
  
  ADD_FUNCTION("getdate", f_getdate, tFunc(tString tOr(tInt, tVoid)), 0);
#endif
  
#ifdef HAVE_STRPTIME
  ADD_FUNCTION("strptime", f_strptime, tFunc(tString tString tMapping, tInt), 0);
#endif
  
  ADD_FUNCTION("parse_date", f_parse_date, tFunc(tString, tInt), 0);
  ADD_FUNCTION("difftime", f_difftime, tFunc(tInt tInt, tInt), 0);
}
