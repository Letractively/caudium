/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "caudium_machine.h"
#include "scratchpad.h"

#include <unistd.h>
#include <stdlib.h>

#if defined(PIKE_THREADS) && defined(POSIX_THREADS)
#include <pthread.h>
#elif defined(PIKE_THREADS)
#warning Pike with threads but scratchpad not thread-safe. Use locking!
#endif


#if defined(PIKE_THREADS) && defined(POSIX_THREADS)
pthread_key_t          __scratch_key;
static pthread_once_t  scratch_key_once = PTHREAD_ONCE_INIT;
#else
SCRATCHPAD            *__scratch_pad;
#endif

static SCRATCHPAD *scratchpad_allocate(size_t max_size,
                                       size_t init_size,
                                       size_t growth_factor)
{
  SCRATCHPAD *spad = (SCRATCHPAD*)malloc(sizeof(*spad));
  
  if (!spad)
    Pike_error("Error allocating the scratchpad\n");
  
  spad->buf_size = init_size > max_size ? max_size : init_size;
  spad->buf_max = max_size;
  spad->buf_growth_factor = growth_factor;
  spad->buf = (unsigned char*)calloc(sizeof(unsigned char), init_size);
  if (!spad->buf) {
    free(spad);
    Pike_error("Error allocating the scratchpad buffer\n");
  }

  return spad;
}

#if defined(PIKE_THREADS) && defined(POSIX_THREADS)
static void scratchpad_destroy(void *_spad)
{
  scratchpad_done((SCRATCHPAD*)_spad);
  if (_spad)
    free(_spad);
  
  pthread_setspecific(__scratch_key, NULL);
}

static void scratchpad_key_alloc()
{
  pthread_key_create(&__scratch_key, scratchpad_destroy);
}

void scratchpad_init(size_t max_size, size_t init_size, size_t growth_factor)
{
  SCRATCHPAD    *spad = scratchpad_allocate(max_size, init_size, growth_factor);
  
  pthread_once(&scratch_key_once, scratchpad_key_alloc);  
  pthread_setspecific(__scratch_key, spad);
}
#else
static scratchpad_at_exit(void)
{
  scratchpad_done(__scratch_pad);
  __scratch_pad = NULL;
}

void scratchpad_init(size_t max_size, size_t init_size, size_t grow_factor)
{
  __scratch_pad = scratchpad_allocate(max_size, init_size, grow_factor);
  atexit(scratchpad_at_exit);
}
#endif

void scratchpad_done(SCRATCHPAD *spad)
{
  if (spad && spad->buf) {
    spad->buf = NULL;
    spad->buf_size = 0;
    spad->buf_max = 0;
  }
  
}
