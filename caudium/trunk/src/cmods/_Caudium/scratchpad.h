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
#ifndef __SCRATCHPAD_H
#define __SCRATCHPAD_H

#include "global.h"
#include <stdlib.h>

/* these possibly should be configure-time parameters */
/* might also be runtime ones, if so - define them to refer to some external
 * variables of type size_t. Note that both of them should be powers of two
 * - just so that the lshift is nicely aligned.
 */
#define SPAD_MAX_SIZE       (1024*1024*32)
#define SPAD_INIT_SIZE      (1024*32)

/* this is for use in the lshift operation (i.e. a number of bits - each
 * bit is a power of 2) */
#define SPAD_GROWTH_FACTOR  1

typedef struct 
{
  unsigned char       *buf;
  size_t               buf_size;
  size_t               buf_max;
  size_t               buf_growth_factor;
} SCRATCHPAD;

void scratchpad_init(size_t max_size, size_t init_size, size_t grow_factor);
void scratchpad_done(SCRATCHPAD *spad);

static inline int scratchpad_grow(SCRATCHPAD *spad, size_t wanted_size)
{
  if (!spad)
    return -1;

  while (spad->buf_size < wanted_size) {
    if (spad->buf_size << spad->buf_growth_factor > spad->buf_max)
      return -2;
    spad->buf_size <<= spad->buf_growth_factor;
  }

  free(spad->buf);
  spad->buf = (unsigned char*)malloc(spad->buf_size * sizeof(*spad->buf));
  if (!spad->buf)
    Pike_error("Out of memory growing the scratchpad buffer\n");
  return 0;
}

#if defined(PIKE_THREADS) && defined(POSIX_THREADS)
static inline unsigned char *scratchpad_get(size_t wanted_size)
{
  extern pthread_key_t __scratch_key;
  SCRATCHPAD *spad = pthread_getspecific(__scratch_key);

  if (!spad)
    scratchpad_init(SPAD_MAX_SIZE, wanted_size, SPAD_GROWTH_FACTOR);
  else if (spad->buf_size < wanted_size) {
    switch(scratchpad_grow(spad, wanted_size)) {
        case -1:
          Pike_error("Impossible happened! Magic!\n");

        case -2:
          Pike_error("Wanted size (%lu) exceeds the maximum scratchpad size (%lu)\n",
                     wanted_size, spad->buf_max);
    }
  }
  return spad->buf;
}
#else
static inline unsigned char *scratchpad_get(size_t wanted_size)
{
  extern SCRATCHPAD *__scratch_pad;

  if (!__scratch_pad)
    scratchpad_init(SPAD_MAX_SIZE, wanted_size, SPAD_GROWTH_FACTOR);
  else if (__scratch_pad->buf_size < wanted_size) {
    switch(scratchpad_grow(__scratch_pad, wanted_size)) {
        case -1:
          Pike_error("Impossible happened! Magic!\n");

        case -2:
          Pike_error("Wanted size (%lu) exceeds the maximum scratchpad size (%lu)\n",
                     wanted_size, __scratch_pad->buf_max_size);
    }
  }
  return __scratch_pad->buf;
}
#endif /* PIKE_THREADS && POSIX_THREADS */

#endif /* !__SCRATCHPAD_H */
