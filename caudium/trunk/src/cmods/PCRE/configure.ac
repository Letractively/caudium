AC_INIT(pcre.c)
AC_CONFIG_HEADER(pcre_config.h)

CAUDIUM_MODULE_INIT([PCRE])

AC_PROG_INSTALL

AC_CHECK_HEADERS( locale.h )
AC_CHECK_FUNCS( setlocale )
AC_CHECK_HEADERS( pcre.h )
AC_CHECK_LIB(pcre, pcre_complile)

if test "$ac_cv_header_pcre_h" != "yes"; then
cat << EOF
************************************************************
***** Cannot find PCRE regexp on your system. You will have
***** Some functions that will not work on Caudium 1.3.
***** Please install lib PCRE to get a fully fonctionnal 
***** Caudium.
************************************************************
EOF
fi

AH_TOP([

/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2001-2003 The Caudium Group
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

#ifndef PCRE_CONFIG_H
#define PCRE_CONFIG_H

])

AH_BOTTOM([
#undef HAVE_LIBPCRE
#if defined(HAVE_PCRE_H) && defined(HAVE_LIBPCRE)
#include <pcre.h>
#define HAVE_PCRE


#define THIS ((PCRE_Regexp *)Pike_fp->current_storage)

typedef struct
{
  pcre *regexp;
  pcre_extra *extra;
  struct pike_string *pattern;
} PCRE_Regexp;

#endif
void f_pcre_create(INT32);
void f_pcre_match(INT32);
void f_pcre_split(INT32);
void pike_module_init(void);
void pike_module_exit(void);
static void free_regexp(struct object *);
#endif

])

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS

AC_OUTPUT(Makefile.pre, [make -f Makefile.pre depend])

dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
