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

/* Non-blocking sending of a string and/or data from a file object
 * to another file object. I.e data pipe function.
 */

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "caudium.h"

#define THIS ((nb *)(Pike_fp->current_storage))
extern int fd_from_object(struct object *o);

#define NB_DEBUG
#ifdef NB_DEBUG
# define DERR(X) do { fprintf(stderr, "** Caudium.nbio: "); X; } while(0)
#else
# define DERR(X) 
#endif

/* allocate / initialize the struct */
static void alloc_nb_struct(struct object *obj) {
  THIS->inputs     = NULL;
  THIS->last_input = NULL;
  THIS->outp       = NULL;
  THIS->args       = NULL;
  THIS->cb.type    = T_INT; 
}

/* Free an input */
static void free_input(input *inp) {
  if(inp->type == T_STRING) {
    free_string(inp->u.data);
  } else if(inp->type == T_OBJECT) {
    free_object(inp->u.file);
  }
  if(THIS->last_input == inp)
    THIS->last_input = NULL;
  if(THIS->inputs == inp)
    THIS->inputs = NULL;
  free(inp);
}

/* Allocate new input object and add it to our list */
static INLINE void new_input(struct svalue inval, int len) {
  input *inp;
  inp = calloc(sizeof(inp), 0);
  if(inp == NULL) {
    Pike_error("Out of memory!\n");
    return;
  }
  if(inval.type == T_STRING) {
    inp->type   = T_STRING;
    add_ref(inp->u.data = inval.u.string);
    inp->len    = inval.u.string->len << inval.u.string->size_shift;
    DERR(fprintf(stderr, "string input added: %d bytes\n", inp->len));
  } else if(inval.type == T_OBJECT) {
    inp->type   = T_OBJECT;
    inp->u.file = inval.u.object;
    inp->fd     = fd_from_object(inp->u.file);
    inp->len    = len;
    if(inp->fd == -1) {
      DERR(fprintf(stderr, "input object not a real FD\n"));
      if (find_identifier("read", inp->u.file->prog) < 0) {
	free(inp);
	Pike_error("Caudium.nbio()->input: Illegal file object, "
		   "missing read()\n");
	return;
      }
    } else {
      DERR(fprintf(stderr, "in FD == %d\n", inp->fd));
    }
    add_ref(inp->u.file);
  }
  if (THIS->last_input)
    THIS->last_input->next = inp;
  else
    THIS->inputs = inp;
  THIS->last_input = inp;
}


/* free output object */
static void free_output(output *outp) {
  free_object(outp->file);
  free(outp);
}

/* Free any allocated data in the struct */
static void free_nb_struct(struct object *obj) {
  input *inp;
  if(THIS->args != NULL) {
    free_array(THIS->args);
    THIS->args = NULL;
  }
  while((inp = THIS->inputs) != NULL) {
    THIS->inputs = inp->next;
    free_input(inp);
  }
  THIS->last_input = NULL;
  if(THIS->outp != NULL) {
    free_output(THIS->outp);
    THIS->outp = NULL;
  }
  free_svalue(&THIS->cb);
  THIS->cb.type = T_INT; 
}

/* Set the input file (file object, (max) bytes to read ) */
static void f_input(INT32 args) {
  int len = -1;
  switch(args) {
   case 2:
    if(ARG(1).type != T_INT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->input", 2, "integer");
    } else {
      len = ARG(1).u.integer;
    }
    /* FALL THROUGH */
   case 1:
    if(ARG(0).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->input", 1, "object");
    } else {
      /* Allocate a new input object and add it to our linked list */
      new_input(ARG(0), len);
    }
    break;
    
   case 0:
    SIMPLE_TOO_FEW_ARGS_ERROR("Caudium.nbio()->input", 1);
    break;
  }
  pop_n_elems(args);
  push_int(0);
}

/* Set the output file (file object) */
static void f_output(INT32 args) {
  if(args) {
    if(ARG(0).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->output", 1, "object");
    } else {
      output *outp;
      if(THIS->outp != NULL) {
	free_output(THIS->outp);
      }
      outp = calloc(sizeof(outp), 0);
      outp->file = ARG(0).u.object;
      outp->fd = fd_from_object(outp->file);
      outp->set_nb_off = find_identifier("set_nonblocking", outp->file->prog);
      outp->set_b_off  = find_identifier("set_blocking", outp->file->prog);
      outp->write_off  = find_identifier("write", outp->file->prog);

      if (outp->write_off < 0 || outp->set_nb_off < 0 || outp->set_b_off < 0) 
      {
	Pike_error("Caudium.nbio()->output: illegal file object%s%s%s\n",
		   ((outp->write_off < 0)?"; no write":""),
		   ((outp->set_nb_off < 0)?"; no set_nonblocking":""),
		   ((outp->set_b_off < 0)?"; no set_blocking":""));
      }
      
      add_ref(outp->file);
      THIS->outp = outp;
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("Caudium.nbio()->output", 1);
  }
  pop_n_elems(args);
  push_int(0);
}

/* Set the output data (string) */
static void f_write(INT32 args) {
  if(args) {
    if(ARG(0).type != T_STRING) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->write", 1, "string");
    } else {
      new_input(ARG(0), 0);
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("Caudium.nbio()->write", 1);
  }
  pop_n_elems(args);
  push_int(0);
}

/* Initialized the sender */
void init_nb_send(void) {
  start_new_program();
  ADD_STORAGE( nb );
  set_init_callback(alloc_nb_struct);
  set_exit_callback(free_nb_struct);
  ADD_FUNCTION("input",  f_input, tFunc(tObj tOr(tInt, tVoid), tVoid), 0);
  ADD_FUNCTION("write",  f_write, tFunc(tStr, tVoid), 0);
  ADD_FUNCTION("output", f_output, tFunc(tObj, tVoid), 0);
  end_class("nbio", 0);
}

