AC_INIT(caudium.c)
AC_CONFIG_HEADER(caudium_machine.h)

CAUDIUM_MODULE_INIT()

AC_HAVE_HEADERS(sys/mman.h linux/mman.h sys/file.h stdio.h stdlib.h time.h sys/time.h)
AC_HAVE_FUNCS(mmap munmap free)

dnl Test for snprintf..
AC_HAVE_FUNCS(snprintf,[AC_DEFINE(HAVE_SNPRINTF,,[Define to 1 if you have the snprintf function.])],[
	AC_MSG_ERROR([Your system lacks the snprintf function. Please send a bug report with OS/environment details to bugs@caudium.info. Caudium can not be built on your system.])])

dnl For _Caudium.cern_http_date() function
AC_STRUCT_TIMEZONE
AC_CHECK_MEMBER(struct tm.tm_gmtoff, [AC_DEFINE(STRUCT_TM_TM_GMTOFF,,[Define if you have struct tm/tm_gmtoff])],,[
#include <sys/types.h>
#include <$ac_cv_struct_tm>
])
AC_MSG_CHECKING([whether timezone is scalar])
AC_TRY_COMPILE([
#include <sys/types.h>
#include <$ac_cv_struct_tm
   ],
   [timezone = 42L],
   [
       AC_MSG_RESULT(yes)
       AC_DEFINE(HAVE_SCALAR_TIMEZONE,,[Define if your timezone is a scalar number]),
   ],
   [   AC_MSG_RESULT(no)    ])

AH_TOP([
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2001 The Caudium Group
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

#ifndef CAUDIUM_MACHINE_H
#define CAUDIUM_MACHINE_H

])

AH_BOTTOM([
#endif
])

AC_CHECK_HEADERS([stdio.h alloca.h])

AC_OUTPUT(Makefile.pre, [make -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
