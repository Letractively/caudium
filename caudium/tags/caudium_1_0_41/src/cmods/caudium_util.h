/*
 * Pike Extension Modules - A collection of modules for the Pike Language
 * Copyright © 2000-2002 The Caudium Group
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

/* This file should be included by ALL source code. It includes various
 * stuff to maintain source code compatibility between Pike versions.
 *
 * $Id$
 */
 
/* Standard Pike include files. */
#include "array.h"
#include "builtin_functions.h"
#include "constants.h"
#include "fdlib.h"
#include "interpret.h"
#include "mapping.h"
#include "module_support.h"
#include "multiset.h"
#include "object.h"
#include "pike_macros.h"
#include "pike_types.h"
#include "program.h"
#include "stralloc.h"
#include "svalue.h"
#include "threads.h"
#include "version.h"

#if (PIKE_MAJOR_VERSION == 7 && PIKE_MINOR_VERSION == 1 && PIKE_BUILD_VERSION >= 12) || PIKE_MAJOR_VERSION > 7 || (PIKE_MAJOR_VERSION == 7 && PIKE_MINOR_VERSION > 1)
# include "pike_error.h"
#else
# include "error.h"
# ifndef Pike_error
#  define Pike_error error
# endif
#endif
