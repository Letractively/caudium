AC_INIT(caudium.c)
AC_CONFIG_HEADER(caudium_machine.h)

CAUDIUM_MODULE_INIT()

AC_HAVE_HEADERS(sys/mman.h linux/mman.h sys/file.h)
AC_HAVE_FUNCS(mmap munmap)

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

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS

AC_OUTPUT(Makefile.pre, [make -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
