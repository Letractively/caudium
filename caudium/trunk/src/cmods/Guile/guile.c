/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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

#include "guile_config.h"
#ifdef HAVE_GUILE
#include <guile/gh.h>
#endif

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"

#include <stdio.h>
#include <fcntl.h>

#ifdef HAVE_GUILE
#include "guile_defs.h"

void guile_main(int argc, char *argv[])
{
  thr_queue_entry_t *workp;
  for(;;) {
    /* Fetch a new entry to execute. This call will block until there is
     * something to do.
     */
    workp = thr_queue_read();
    if(workp->code)
      gh_eval_str(workp->code);
  }
}
void start_guile_main(void *nil)
{
  gh_enter(0, NULL, guile_main);
}


#endif  

/* Initialize and start module */
void pike_module_init( void )
{
#ifdef HAVE_GUILE
  thr_queue_init(MAX_QUEUE_SIZE);

  /* This initialized the Guile interpreter and starts the
   * Guile loop. Since exiting the guile main loop will exit
   * the process, we never do exit it but instead use a thread queue
   * system. We create a new thread for this blocking execution thread.
   */
  th_farm(start_guile_main, NULL);

  /*
    thr_queue_write("(define (quit) (display \"quit disabled\n\"))");
    thr_queue_write("(display \"hello world\")(newline)");
    thr_queue_write("(display \"how are you?\")(newline)");
    thr_queue_write("(display \"I am fine\")(newline)"); 
    thr_queue_write("(display \"hello world 2\")(newline)");
    thr_queue_write("(display \"how are you 2?\")(newline)");
    thr_queue_write("(quit)");
  */
#endif
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

 
