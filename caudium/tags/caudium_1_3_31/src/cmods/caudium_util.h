/*5 2001/02/20 05:52:12
 * Pike Extension Modules - A collection of modules for the Pike Language
 * Copyright © 2000-2001 The Caudium Group
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
#include "stralloc.h"
#include "svalue.h"
#include "threads.h"
#include "bignum.h"
#include "version.h"
#include "operators.h"

#if (PIKE_MAJOR_VERSION == 7 && PIKE_MINOR_VERSION == 1 && PIKE_BUILD_VERSION >= 12) || PIKE_MAJOR_VERSION > 7 || (PIKE_MAJOR_VERSION == 7 && PIKE_MINOR_VERSION > 1)
# include "pike_error.h"
#else
# include "error.h"
# ifndef Pike_error
#  define Pike_error error
# endif
#endif


/* This allows calling of pike functions from functions called by callbacks
 * in code running in threaded mode.
 */
/* This allows execution of c-code that requires the Pike interpreter to 
 * be locked from the Sablotron callback functions.
 */
#if defined(PIKE_THREADS) && defined(_REENTRANT)
#define THREAD_SAFE_RUN(COMMAND)  do {\
  struct thread_state *state;\
 if((state = thread_state_for_id(th_self()))!=NULL) {\
    if(!state->swapped) {\
      COMMAND;\
    } else {\
      mt_lock(&interpreter_lock);\
      SWAP_IN_THREAD(state);\
      COMMAND;\
      SWAP_OUT_THREAD(state);\
      mt_unlock(&interpreter_lock);\
    }\
  }\
} while(0)
#else
#define THREAD_SAFE_RUN(COMMAND) COMMAND
#endif

/* Pike 7.x and newer */
#define MY_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->data->hashsize; COUNT++ ) \
	for(KEY=md->data->hash[COUNT];KEY;KEY=KEY->next)

#ifndef ARG
#define ARG(_n_) Pike_sp[-((args - _n_) + 1)]
#endif

/*
 * This allow run a module using dmalloc library http://www.dmalloc.org/
 */
#ifdef WITH_DMALLOC
# include <dmalloc.h>
#endif

#ifdef HAVE_ALLOCA
#define USE_ALLOCA 1
#endif

#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__APPLE__)
# if !(__FreeBSD_version >= 50200)
#  undef USE_ALLOCA
# endif
#endif

#ifdef USE_ALLOCA
#define CAUDIUM_ALLOCA(_size_) alloca((_size_))
#define CAUDIUM_UNALLOCA(_ptr_) 
#else
#define CAUDIUM_ALLOCA(_size_) malloc((_size_))
#define CAUDIUM_UNALLOCA(_ptr_) if ((_ptr_)) free((_ptr_))
#endif

#define CAUDIUM_PTR_VALID(_ptr_) if (!(_ptr_)) Pike_error("Out of memory\n")
