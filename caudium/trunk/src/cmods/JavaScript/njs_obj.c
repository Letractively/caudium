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
#include "string.h"
#include "ctype.h"
#ifdef HAVE_NJS

/* Storage init and freeing routines */
static void init_njs_storage(struct object *obj) {
  THIS->interp = NULL;
}

static inline void free_njs_storage(struct object *obj) {
  if(THIS->interp != NULL) {
    js_destroy_interp(THIS->interp);
    THIS->interp = NULL;
  }
}


/* Class constructor. If called in an existing object, the old
 * session is destroyed. Takes the following optional arguments:
 *
 * arg1: Request ID object
 */
static void f_njs_create(INT_TYPE args) {
  JSInterpOptions options;
  free_njs_storage(fp->current_object);

  if(args >= 1) {
    if(ARG(0).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->create", 1,
			   "RequestID");
    } else {
      add_ref((THIS->request_id = ARG(0).u.object));
    }
  }  
  js_init_default_options (&options);
  THIS->interp = js_create_interp(&options);
  if(THIS->interp == NULL) {
    Pike_error("Out of memory!\n");
  }
  pop_n_elems(args);
}

/* Evaluate the given string and return the result */
static void f_njs_eval(INT_TYPE args) {
  int res;
  JSType ret;
  int data_len;
  char *data;
  JSInterpPtr interp;
  if(args != 1) {
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->eval",1);
  }
  if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->eval", 1,
			 "string(8-bit)");
  }
  interp = THIS->interp;
  data = ARG(0).u.string->str;
  data_len = ARG(0).u.string->len;
  THREADS_ALLOW();
  res = js_eval_data(interp, data, data_len);
  THREADS_DISALLOW();
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

static void njs_free_scope_data(void *context) {
  free(SCOPE->name);
  free_svalue(& SCOPE->get);
  free_svalue(& SCOPE->set);
  free(context);
}

static void low_njs_scope_get(JSInterpPtr interp,struct pike_string *scope,
			     JSTypeString *var, struct svalue get,
			     JSType *ret) {
  ref_push_string(scope);
  push_string(make_shared_binary_string(var->data, var->len));
  apply_svalue(&get, 2);
  if(sp[-1].type == T_ARRAY && sp[-1].u.array->size == 1) {
    // Currently the nice special case of "don't parse me pls"
    pike_type_to_js_type(interp, &(ITEM(sp[-1].u.array)[0]), ret);
  } else {
    pike_type_to_js_type(interp, &sp[-1], ret);
  }
  pop_stack();
}

static JSMethodResult njs_scope_get(JSClassPtr cls, void *instance_context,
				    JSInterpPtr interp, int argc,
				    JSType *argv, JSType *result_return,
				    char *error_return) {
  GET_SCOPE();
  if(argc != 1) {
    sprintf(error_return, "Got %d arguments, expected 1.", argc);
    return JS_ERROR;
  }
  if(argv[0].type != JS_TYPE_STRING) {
    strcpy(error_return, "Invalid argument 1, expected string.");
    return JS_ERROR;
  }
  THREAD_SAFE_RUN(low_njs_scope_get(interp,
				    SCOPE->name, argv[0].u.s, SCOPE->get,
				    result_return), "get scope variable");
  return JS_OK;
}
static JSMethodResult njs_scope_set(JSClassPtr cls, void *instance_context,
				    JSInterpPtr interp, int argc,
				    JSType *argv, JSType *result_return,
				    char *error_return) {
  GET_SCOPE();
  if(argc != 2) {
    sprintf(error_return, "Got %d argument%s, expected 2.", argc,
	    argc == 1 ? "" : "s");
    return JS_ERROR;
  }
  printf("scope set\n");
  return JS_OK;
}

static JSMethodResult njs_scope_property(JSClassPtr cls,
					 void *instance_context,
					 JSInterpPtr interp, int setp,
					 JSType *value, char *error_return) {
  GET_SCOPE();
  printf("scope property\n");
  return JS_OK;
}

/* This function is rather Caudium specific. It adds a Caudium variable scope.
 * The first argument is the name of the scope (lowercase).
 * The second argument is the "get" function, which is called with the
 * scope name and variable name to retrieve the value of that attribute.
 * The third argument is the "set" function which is used for setting
 * variables.
 * It's also called with scope and variable name as well as the value.
 * The fourth argument is an array with the predefined variables (if any).
 * These predefined variables (static if you wish) can be accessed directly
 * using scope.var from javascript.
 */
static void f_njs_add_scope(INT_TYPE args) {
  struct array *predef = NULL;
  unsigned char *tmp;
  int i;
  scope_storage *storage;
  storage = calloc(1, sizeof(scope_storage));
  switch(args) {
   case 4:
    if(ARG(3).type != T_ARRAY || IS_ZERO(&ARG(3))) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 4,
			   "array(string)");
    }
    predef = ARG(3).u.array;

    /* FALL THROUGH */
   case 3:
    if(ARG(2).type != T_FUNCTION) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 3,
			   "function(string,string,mixed:int)");
    }
    if(ARG(1).type != T_FUNCTION) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 2,
			   "function(string,string:mixed)");
    }
    if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 1,
			   "string(8-bit)");
    }
    break;
   default:
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->add_scope",3);
    break;
  }
  add_ref(storage->name = ARG(0).u.string);
  assign_svalue_no_free(& storage->get, & ARG(1));
  assign_svalue_no_free(& storage->set, & ARG(2));

  storage->class = js_class_create((void *)storage, njs_free_scope_data, 0, 0);
  js_class_define_method(storage->class, "get", JS_CF_STATIC, njs_scope_get);
  js_class_define_method(storage->class, "set", JS_CF_STATIC, njs_scope_set);
  if(predef != NULL) {
    for(i = 0; i < predef->size; i++) {
      if(ITEM(predef)[i].type == T_STRING && 
	 !ITEM(predef)[i].u.string->size_shift) {
	js_class_define_property(storage->class,
				 ITEM(predef)[i].u.string->str,
				 JS_CF_STATIC|JS_CF_IMMUTABLE,
				 njs_scope_property);
      }	
    }
  }
  
  js_define_class(THIS->interp, storage->class, storage->name->str);
  pop_n_elems(args);
}

/* Class initialization */
void njs_init_interpreter_program(void) {
  start_new_program();
  ADD_STORAGE( njs_storage  );
  ADD_FUNCTION("create",    f_njs_create,    tFunc(tOr(tObj, tVoid),tVoid), 0);
  ADD_FUNCTION("eval",      f_njs_eval,
	       tFunc(tString,tMixed), OPT_SIDE_EFFECT);
  ADD_FUNCTION("add_scope", f_njs_add_scope,
	       tFunc(tString
		     tFunc(tString tString, tMixed)
		     tFunc(tString tString tMixed, tInt)
		     tOr(tVoid, tArr(tString)),
		     tVoid), OPT_SIDE_EFFECT);
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
