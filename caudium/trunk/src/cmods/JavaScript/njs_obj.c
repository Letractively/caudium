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

/* Implements the core NJS class.
 */

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "njs_config.h"

#ifdef HAVE_NJS

/* Storage init and freeing routines */
static void init_njs_storage(struct object *obj) {
  THIS->interp = NULL;
}

static void free_njs_storage(struct object *obj) {
  if(THIS->interp != NULL) {
    js_destroy_interp(THIS->interp);
    THIS->interp = NULL;
  }
}


/* Class constructor. If called in an existing object, the old
 * session is destroyed.
 */
static void f_njs_create(INT32 args) {
  free_njs_storage(fp->current_object);
  THIS->interp = js_create_interp(NULL);
  if(THIS->interp == NULL) {
    Pike_error("Out of memory!\n");
  }
  
}

/* Evaluate the given string and return the result */
static void f_njs_eval(INT32 args) {
  int res;
  JSType ret;
  if(args != 1) {
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpretor()->eval",1);
  }
  if(sp[-1].type != T_STRING || sp[-1].u.string->size_shift) {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpretor()->eval", 1,
			 "string(8-bit)");
  }
  res = js_eval_data(THIS->interp, sp[-1].u.string->str, sp[-1].u.string->len);
  if(!res) {
    char *err = js_error_message(THIS->interp);
    if(err != NULL) {
      ONERROR tmp;
      char *msg = malloc(strlen(err)+2);
      sprintf(msg, "%s\n", err);
      SET_ONERROR(tmp, free, msg);
      Pike_error(msg);
      UNSET_ONERROR(tmp);
    } else {
      Pike_error("unknown error\n");
    }
  } else {
    js_result(THIS->interp, &ret);
    pop_n_elems(args);
    push_js_type(ret);
  }
}

/* Class initialization */
void njs_init_interpreter_program(void) {
  start_new_program();
  ADD_STORAGE( njs_storage  );
  ADD_FUNCTION("create", f_njs_create,   tFunc(tVoid,tVoid), 0);
  ADD_FUNCTION("eval",   f_njs_eval,     tFunc(tString,tMixed), 0);
  set_init_callback(init_njs_storage);
  set_exit_callback(free_njs_storage);
  end_class("Interpreter", 0);
}


#endif /* HAVE_MHASH */

/*
 * Local variables:
 * c-basic-offset: 2
 * End:
 */
