/*
 * Caudium - An extensible World Wide Web server
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

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"


#include "guile_config.h"

#ifdef HAVE_GUILE

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <string.h>

#include "thr_queue.h"

static thr_queue_t thr_queue;

void thr_queue_init(int max_size)
{
  int i, rtn;
   
  /* initialize th fields */
  thr_queue.max_size = max_size;

  thr_queue.size = 0;
  thr_queue.q_head = NULL; 
  thr_queue.q_tail = NULL;
  if ((rtn = mt_init(&(thr_queue.q_lock))) != 0)
    fprintf(stderr,"mt_init %s",strerror(rtn)), exit(1);
  if ((rtn = co_init(&(thr_queue.q_not_empty))) != 0)
    fprintf(stderr,"co_init %s",strerror(rtn)), exit(1);
  if ((rtn = co_init(&(thr_queue.q_not_full))) != 0)
    fprintf(stderr,"co_init %s",strerror(rtn)), exit(1);
}

int thr_queue_write(char *code)
{
  int rtn;
  thr_queue_entry_t *workp;
  
  if ((rtn = mt_lock(&(thr_queue.q_lock))) != 0)
    fprintf(stderr,"mt_lock %d",rtn), exit(1);

  while( (thr_queue.size == thr_queue.max_size)) {
    printf("thr_queue_write: max size, sleeping\n");
    if ((rtn = co_wait(&(thr_queue.q_not_full),
		       &(thr_queue.q_lock))) != 0)
      fprintf(stderr,"co_wait %d",rtn), exit(1);
  }
  
  /* allocate work structure */
  if ((workp = (thr_queue_entry_t *)malloc(sizeof(thr_queue_entry_t))) == NULL)
    perror("malloc"), exit(1);
  workp->code = code;
  workp->next = NULL;
  
  if (thr_queue.size == 0) {
    thr_queue.q_tail = thr_queue.q_head = workp;
    
    if ((rtn = co_broadcast(&(thr_queue.q_not_empty))) != 0)
      fprintf(stderr,"co_signal %d",rtn), exit(1);;
  } else {
    thr_queue.q_tail->next = workp;
    thr_queue.q_tail = workp;
  }

  thr_queue.size++; 
  if ((rtn = mt_unlock(&(thr_queue.q_lock))) != 0)
    fprintf(stderr,"mt_unlock %d",rtn), exit(1);
  return 1;
}


thr_queue_entry_t *thr_queue_read()
{
  int rtn;
  thr_queue_entry_t *my_workp;
  /* Check queue for work */ 
  if ((rtn = mt_lock(&(thr_queue.q_lock))) != 0)
    fprintf(stderr,"mt_lock %d",rtn), exit(1);

  while ((thr_queue.size == 0)) {
    if ((rtn = co_wait(&(thr_queue.q_not_empty),
		       &(thr_queue.q_lock))) != 0)
      fprintf(stderr,"co_wait %d", rtn), exit(1);
  }
  
  /* Get to work, dequeue the next item */ 
  my_workp = thr_queue.q_head;
  thr_queue.size--;
  if (thr_queue.size == 0)
    thr_queue.q_head = thr_queue.q_tail = NULL;
  else
    thr_queue.q_head = my_workp->next;
  
  /* Handle waiting add_work threads */
  if ((thr_queue.size ==  (thr_queue.max_size - 1))) 
    if ((rtn = co_broadcast(&(thr_queue.q_not_full))) != 0)
      fprintf(stderr,"co_broadcast %d",rtn), exit(1);
  
  if ((rtn = mt_unlock(&(thr_queue.q_lock))) != 0)
    fprintf(stderr,"mt_unlock %d",rtn), exit(1);
  return my_workp;
}

#endif

 
