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

#ifndef ALLOCA_KLUDGE_H
#define ALLOCA_KLUDGE_H

#ifdef __FreeBSD__
# if __FreeBSD_version < 50200
#  undef HAVE_ALLOCA
#  undef HAVE_ALLOCA_H
# endif
#endif

#ifdef __NetBSD__
# undef HAVE_ALLOCA
# undef HAVE_ALLOCA_H
#endif

#ifdef __OpenBSD__
# undef HAVE_ALLOCA
# undef HAVE_ALLOCA_H
#endif

#ifdef __APPLE__
# undef HAVE_ALLOCA
# undef HAVE_ALLOCA_H
#endif

/*
 * For INLINE with alloca
 */
#ifndef HAVE_ALLOCA
# if !defined(__OpenBSD__) && !defined(__APPLE__) && !defined(__NetBSD__)
#  ifdef __FreeBSD__
#   if __FreeBSD_version >= 502000
#    define DO_INLINE
#   endif
#  else
#   define DO_INLINE
#  endif 
# endif
#endif

#endif /* ALLOCA_KLUDGE_H */

