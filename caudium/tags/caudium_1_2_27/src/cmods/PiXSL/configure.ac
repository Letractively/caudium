AC_INIT(sablot.c)
AC_CONFIG_HEADER(sablot_config.h)

CAUDIUM_MODULE_INIT()

AC_PROG_INSTALL

dnl Solaris have math functions in libm
dnl so this is needed to linking libsablot
AC_CHECK_LIB(m, floor)
if test "$ac_cv_lib_m_floor" != "yes"; then 
  AC_CHECK_LIB(m, ceil)
fi

dnl FreeBSD of Sablot + Expart uses iconv lib 
dnl when linking
AC_CHECK_LIB(iconv, iconv)
dnl There is also another call in libiconv that can
dnl be used
AC_CHECK_LIB(iconv, libiconv)

dnl Check if libexpat exist (some calls)
AC_CHECK_LIB(expat, XML_Parse)
AC_CHECK_LIB(expat, XML_SetBase)
AC_CHECK_LIB(expat, XML_SetEncoding)

AC_CHECK_HEADERS( sablot.h )
dnl  if we need this, use em.
dnl No need to continue unless the header is found...
if test "$ac_cv_header_sablot_h" = "yes"; then
    unset ac_cv_lib_sablot_SablotProcess
    OLDLIBS="$LIBS"
    LIBS=""
    AC_CHECK_LIB(sablot, SablotProcess,
    [
      AC_DEFINE(HAVE_LIBSABLOT)
  	  LIBS="-lsablot $OLDLIBS"
  	], [
  	  unset ac_cv_lib_sablot_SablotProcess
  	  AC_CHECK_LIB(sablot, SablotProcess,
  	  [
  		AC_DEFINE(HAVE_LIBSABLOT)
  		LIBS="-lsablot -lexpat $OLDLIBS"
  	  ], [
  		unset ac_cv_lib_sablot_SablotProcess
  		AC_CHECK_LIB(sablot, SablotProcess,
  		[
  		  AC_DEFINE(HAVE_LIBSABLOT)
  		  LIBS="-lsablot -lxmlparse -lxmltok $OLDLIBS"
  		],[], -lxmlparse -lxmltok $OLDLIBS)
  	  ], -lexpat  $OLDLIBS)
  	], $OLDLIBS)
fi

if test "$ac_cv_header_sablot_h" != "yes" -o \
	    "$ac_cv_lib_sablot_SablotProcess" != "yes"; then
cat << EOF
*************************************************************
**** The Sablotron XSLT processing library couldn't be found.
**** PiXSL will not be built. You can get Sablotron from
**** http://www.gingerall.com/
*************************************************************
EOF
fi

AH_TOP([
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2001,2002 The Caudium Group
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

#ifndef SABLOT_CONFIG_H
#define SABLOT_CONFIG_H

])

AH_BOTTOM([
#undef HAVE_LIBSABLOT
#if defined(HAVE_SABLOT_H) && defined(HAVE_LIBSABLOT)
# define HAVE_SABLOT
#endif

void pike_module_init( void );
void pike_module_exit( void );

#endif

])

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS
AC_OUTPUT(Makefile.pre pixsl, [make -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
