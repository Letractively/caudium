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
  THIS->id = NULL;
}

static inline void free_njs_storage(struct object *obj) {
  if(THIS->interp != NULL) {
    js_destroy_interp(THIS->interp);
    THIS->interp = NULL;
  }
  if(THIS->id != NULL) {
    free_object(THIS->id);
    THIS->id = NULL;
  }
}
/* Used to scan the options mapping for create, if present */
#define OPT_IS(X)                                                        \
generic_compare_strings(X, strlen(X), 0,                                 \
                       sind->u.string->str, sind->u.string->len,         \
                       sind->u.string->size_shift)

/* Class constructor. If called in an existing object, the old
 * session is destroyed. Takes the following optional arguments:
 *
 * arg1: Request ID object
 * arg2: options mapping
 */
static void f_njs_create(INT_TYPE args) {
  JSInterpOptions options;
  struct svalue *sind, *sval;
  struct keypair *k;
  INT32 e;

  free_njs_storage(Pike_fp->current_object);

  js_init_default_options (&options);

  switch(args) {
   case 2: /* Got options mapping */    
    MY_MAPPING_LOOP(ARG(1).u.mapping, e, k) {
      sind = &k->ind;
      sval = &k->val;
      if(OPT_IS("stack_size")) {
	if(sval->type == T_INT)
	  options.stack_size = sval->u.integer;
      } else if(OPT_IS("verbose")) {
	if(sval->type == T_INT)
	  options.verbose = sval->u.integer;
      } else if(OPT_IS("no_compiler")) {
	options.no_compiler = !IS_ZERO(sval);
      } else if(OPT_IS("only_define_ecma")) {
	options.only_define_ecma = !IS_ZERO(sval);
      } else if(OPT_IS("stacktrace_on_error")) {
	options.stacktrace_on_error = !IS_ZERO(sval);
      } else if(OPT_IS("secure_builtin_file")) {
	options.secure_builtin_file = !IS_ZERO(sval);
      } else if(OPT_IS("secure_builtin_system")) {
	options.secure_builtin_system = !IS_ZERO(sval);
      } else if(OPT_IS("annotate_assembler")) {
	options.annotate_assembler = !IS_ZERO(sval);
      } else if(OPT_IS("debug_info")) {
	options.debug_info = !IS_ZERO(sval);
      } else if(OPT_IS("executable_bc_files")) {
	options.executable_bc_files = !IS_ZERO(sval);
      } else if(OPT_IS("warn_unused_argument")) {
	options.warn_unused_argument = !IS_ZERO(sval);
      } else if(OPT_IS("warn_unused_variable")) {
	options.warn_unused_variable = !IS_ZERO(sval);
      } else if(OPT_IS("warn_undef")) {
	options.warn_undef = !IS_ZERO(sval);
      } else if(OPT_IS("warn_shadow")) {
	options.warn_shadow = !IS_ZERO(sval);
      } else if(OPT_IS("warn_with_clobber")) {
	options.warn_with_clobber = !IS_ZERO(sval);
      } else if(OPT_IS("warn_missing_semicolon")) {
	options.warn_missing_semicolon = !IS_ZERO(sval);
      } else if(OPT_IS("warn_strict_ecma")) {
	options.warn_strict_ecma = !IS_ZERO(sval);
      } else if(OPT_IS("warn_deprecated")) {
	options.warn_deprecated = !IS_ZERO(sval);
      } else if(OPT_IS("optimize_peephole")) {
	options.optimize_peephole = !IS_ZERO(sval);
      } else if(OPT_IS("optimize_jumps_to_jumps")) {
	options.optimize_jumps_to_jumps = !IS_ZERO(sval);
      } else if(OPT_IS("optimize_bc_size")) {
	options.optimize_bc_size = !IS_ZERO(sval);
      } else if(OPT_IS("optimize_heavy")) {
	options.optimize_heavy = !IS_ZERO(sval);
      } else if(OPT_IS("fd_count")) {
	if(sval->type == T_INT)
	  options.fd_count = sval->u.integer;
      } 
    }
        
    /* FALL THROUGH */
   case 1: /* Got the request object */
    if(ARG(0).type != T_OBJECT) {
      if(!IS_ZERO((&ARG(0)))) {
	SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->create", 1,
			     "RequestID");
      }
    } else {
      add_ref((THIS->id = ARG(0).u.object));
    }
  }  

  THIS->interp = js_create_interp(&options);
  if(THIS->interp == NULL) {
    Pike_error("Failed to create NJS interpreter!\n");
  }
  pop_n_elems(args);
}

static void f_njs_set_id_object(INT_TYPE args) {
  if(args == 1 && sp[-1].type == T_OBJECT) {
    if(THIS->id != NULL) {
      free_object(THIS->id);
      THIS->id = NULL;
    }
    add_ref((THIS->id = sp[-1].u.object));
  } else {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->set_id_object", 1,
			 "RequestID");
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

  NJS_PROCESS_EVAL_RESULT();
}

/* Evaluate the given file name (null terminates) and return the result */
static void f_njs_eval_file(INT_TYPE args) {
  int res;
  JSType ret;
  char *file;
  JSInterpPtr interp;
  if(args != 1) {
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->eval_file",1);
  }
  if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->eval_file", 1,
			 "string(8-bit)");
  }

  if((unsigned int)ARG(0).u.string->len != strlen(ARG(0).u.string->str)) {
    Pike_error("JavaScript.Interpreter()->eval_file: file name cannot "
	       "contain null characters.\n");
  }
  
  interp = THIS->interp;
  file = ARG(0).u.string->str;

  THREADS_ALLOW();
  res = js_eval_file(interp, file);
  THREADS_DISALLOW();

  NJS_PROCESS_EVAL_RESULT();
}

/* Execute the given bytecode and return the result */
static void f_njs_execute(INT_TYPE args) {
  int res;
  JSType ret;
  int bc_len;
  char *bc;
  JSInterpPtr interp;
  if(args != 1) {
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->eval",1);
  }
  if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->eval", 1,
			 "string(8-bit)");
  }

  interp = THIS->interp;
  bc = ARG(0).u.string->str;
  bc_len = ARG(0).u.string->len;

  THREADS_ALLOW();
  res = js_execute_byte_code(interp, bc, bc_len);
  THREADS_DISALLOW();

  NJS_PROCESS_EVAL_RESULT();
}

/* Compile the given data into bytecode and return the result
 * This can later be used by JavaScript.Interpreter->execute()
 */
static void f_njs_compile(INT_TYPE args) {
  int res;
  JSType ret;
  int data_len;
  unsigned int bc_len;
  char *data;
  unsigned char *bc_str;
  JSInterpPtr interp;
  if(args != 1) {
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->compile",1);
  }
  if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->compile", 1,
			 "string(8-bit)");
  }
  interp = THIS->interp;
  data = ARG(0).u.string->str;
  data_len = ARG(0).u.string->len;

  THREADS_ALLOW();
  res = js_compile_data_to_byte_code(interp, data, data_len,
				     &bc_str, &bc_len);
  THREADS_DISALLOW();

  NJS_PROCESS_COMPILE_RESULT();
}

/* Compile the given file into bytecode and return the result
 * This can later be used by JavaScript.Interpreter->execute()
 */
static void f_njs_compile_file(INT_TYPE args) {
  int res;
  JSType ret;
  unsigned int bc_len;
  char *file;
  unsigned char *bc_str;
  JSInterpPtr interp;
  if(args != 1) {
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->compile",1);
  }
  if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
    SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->compile", 1,
			 "string(8-bit)");
  }
  if((unsigned int)ARG(0).u.string->len != strlen(ARG(0).u.string->str)) {
    Pike_error("JavaScript.Interpreter()->eval_file: file name cannot "
	       "contain null characters.\n");
  }
  interp = THIS->interp;
  file = ARG(0).u.string->str;

  THREADS_ALLOW();
  res = js_compile_to_byte_code(interp, file, &bc_str, &bc_len);
  THREADS_DISALLOW();

  NJS_PROCESS_COMPILE_RESULT();
}


static void njs_free_scope_data(void *context) {
  free_string(SCOPE->name);
  free_svalue(& SCOPE->get);
  free_svalue(& SCOPE->set);
  free(context);
}

static void low_njs_scope_get(JSInterpPtr interp,struct pike_string *scope,
			      struct object *id, const char *var,
			      unsigned int varlen, struct svalue get,
			      JSType *ret) {
  push_string(make_shared_binary_string(var, varlen));
  ref_push_string(scope);
  if(id != NULL) {
    ref_push_object(id);
    apply_svalue(&get, 3);
  } else {
    apply_svalue(&get, 2);
  }

  if(sp[-1].type == T_ARRAY && sp[-1].u.array->size == 1) {
    // Currently the nice special case of "don't parse me pls"
    pike_type_to_js_type(interp, &(ITEM(sp[-1].u.array)[0]), ret);
  } else {
    pike_type_to_js_type(interp, &sp[-1], ret);
  }
  pop_stack();
}

static void low_njs_scope_set(JSInterpPtr interp, struct pike_string *scope,
			      struct object *id, const char *var,
			      unsigned int varlen, struct svalue set,
			      JSType set_to, int *success)
{
  push_string(make_shared_binary_string(var, varlen));
  ref_push_string(scope);
  push_js_type(set_to);
  if(id != NULL) {
    ref_push_object(id);
    apply_svalue(&set, 4);
  } else {
    apply_svalue(&set, 3);
  }
  
  if(sp[-1].type == T_INT && sp[-1].u.integer == 0) {
    *success = 0;
  } else {
    *success = 1;
  }
  pop_stack();
}

static JSMethodResult njs_scope_get(JSClassPtr cls, void *instance_context,
				    JSInterpPtr interp, int argc,
				    JSType *argv, JSType *result_return,
				    char *error_return) {
  GET_SCOPE();
  if(argc != 1) {
    js_snprintf(error_return, 1024, "Got %d arguments, expected 1.", argc);
    return JS_ERROR;
  }
  if(argv[0].type != JS_TYPE_STRING) {
    /* In reality we shouldn't require the key to be limited to a string
     * but for now this is fine
     */
    strcpy(error_return, "Invalid argument 1, expected string.");
    return JS_ERROR;
  }
  THREAD_SAFE_RUN(low_njs_scope_get(interp, SCOPE->name, SCOPE->parent->id,
				    argv[0].u.s->data,
				    argv[0].u.s->len, SCOPE->get,
				    result_return));
  return JS_OK;
}

static JSMethodResult njs_scope_set(JSClassPtr cls, void *instance_context,
				    JSInterpPtr interp, int argc,
				    JSType *argv, JSType *return_type,
				    char *error_return) {
  int set_ok;
  GET_SCOPE();
  if(argc != 2) {
    js_snprintf(error_return, 1024,"Got %d argument%s, expected 2.", argc,
	    argc == 1 ? "" : "s");
    return JS_ERROR;
  }
  if(SCOPE->set.type == T_INT) {
    /* Immutable scope, i.e read-only */
    strcpy(error_return, "Scope is read-only.");
    return JS_ERROR;
  }
  if(argv[0].type != JS_TYPE_STRING) {
    /* In reality we shouldn't require the key to be limited to a string
     * but for now this is fine
     */
    strcpy(error_return, "Invalid argument 1, expected string.");
    return JS_ERROR;
  }
  
  if(argv[1].type == JS_TYPE_BUILTIN) {
    /* We don't yet handle the NJS objects type. Setting this variable
     * would result in a zero being set.
     */
    strcpy(error_return, "Invalid argument 2, class/object not allowed.");
    return JS_ERROR;
  }

  THREAD_SAFE_RUN(low_njs_scope_set(interp, SCOPE->name, SCOPE->parent->id,
				    argv[0].u.s->data,
				    argv[0].u.s->len, SCOPE->set,
				    argv[1], &set_ok));
  if(set_ok) {
    return_type->type = JS_TYPE_BOOLEAN;
    return_type->u.i = 1;
    return JS_OK;
  } else {
    js_snprintf(error_return, 1024,
		"Failed to set variable '%s' in scope '%s'.",
		SCOPE->name->str, argv[0].u.s->data);
    return JS_ERROR;
  }
}

static JSGenericResult
  njs_scope_property(JSClassPtr cls, void *instance_context,
		     JSInterpPtr interp, const char *property,
		     int setp, JSType *value, char *error_return) {
  GET_SCOPE();
  if(!setp) {
    /* Fetch a value */
    THREAD_SAFE_RUN(low_njs_scope_get(interp, SCOPE->name, SCOPE->parent->id,
				      property, strlen(property), SCOPE->get,
				      value));
    return JS_HANDLED;
  } else {
    int set_ok;
    if(SCOPE->set.type == T_INT) {
      /* Immutable scope, i.e read-only */
      strcpy(error_return, "Scope is read-only.");
      return JS_FAILED;
    }
    
    if(value->type == JS_TYPE_BUILTIN) {
      /* We don't yet handle the NJS objects type. Setting this variable
       * would result in a zero being set.
       */
      strcpy(error_return, "Invalid argument 2, class/object not allowed.");
      return JS_FAILED;
    }

    THREAD_SAFE_RUN(low_njs_scope_set(interp, SCOPE->name, SCOPE->parent->id,
				      property, strlen(property), SCOPE->set,
				      *value, &set_ok));
    if(set_ok) {
      value->type = JS_TYPE_BOOLEAN;
      value->u.i = 1;
      return JS_OK;
    } else {
      js_snprintf(error_return, 1024,
		  "Failed to set variable '%s' in scope '%s'.",
		  SCOPE->name->str, property);
      return JS_FAILED;
    }

    return JS_FAILED;
  }
}

/* This function is rather Caudium specific. It adds a Caudium variable scope.
 * The first argument is the name of the scope (lowercase).
 * The second argument is the "get" function, which is called with the
 * scope name and variable name to retrieve the value of that attribute.
 * The third argument is the "set" function which is used for setting
 * variables.
 * It's also called with scope and variable name as well as the value.
 */
static void f_njs_add_scope(INT_TYPE args) {
  struct array *predef = NULL;
  unsigned char *tmp;
  int i;
  scope_storage *storage;
  storage = malloc(sizeof(scope_storage));

  switch(args) {
   case 3:
    if(ARG(2).type != T_FUNCTION) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 3,
			   "function(string,string,mixed:int)");
    }
    
   default:
    if(ARG(1).type != T_FUNCTION) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 2,
			   "function(string,string:mixed)");
    }
    if(ARG(0).type != T_STRING || ARG(0).u.string->size_shift) {
      SIMPLE_BAD_ARG_ERROR("JavaScript.Interpreter()->add_scope", 1,
			   "string(8-bit)");
    }
    break;
   case 0: case 1: 
    SIMPLE_TOO_FEW_ARGS_ERROR("JavaScript.Interpreter()->add_scope", 2);
    break;
  }

  add_ref(storage->name = ARG(0).u.string);
  storage->parent = THIS;
  assign_svalue_no_free(& storage->get, & ARG(1));
  if(args < 3) { /* No set function */
    storage->set.type = T_INT;
  } else {
    assign_svalue_no_free(& storage->set, & ARG(2));
  }

  storage->class = js_class_create((void *)storage, njs_free_scope_data, 0, 0);
  js_class_define_method(storage->class, "get", JS_CF_STATIC, njs_scope_get);
  js_class_define_method(storage->class, "set", JS_CF_STATIC, njs_scope_set);
  js_class_define_generic_method(storage->class, JS_CF_STATIC, njs_scope_property);

  /* We have a 'var' scope. Transparently (to the Pike end) rename it to
   * vars in the JavaScript environment since it conflicts with the
   * statement 'var'.
   */
  if(storage->name->len == 3 && !memcmp(storage->name->str, "var", 3)) {
    js_define_class(THIS->interp, storage->class, "vars");
  } else {
    js_define_class(THIS->interp, storage->class, storage->name->str);
  }
  pop_n_elems(args);
}

/* Class initialization */
void njs_init_interpreter_program(void) {
  start_new_program();
  ADD_STORAGE( njs_storage  );
  ADD_FUNCTION("create",       f_njs_create,
	       tFunc(tOr(tObj, tVoid) tOr(tMapping, tVoid),tVoid), 0);
  ADD_FUNCTION("set_id_object",f_njs_set_id_object,
	       tFunc(tObj, tVoid), 0);
  ADD_FUNCTION("eval",         f_njs_eval,
	       tFunc(tString,tMixed), OPT_SIDE_EFFECT);
  ADD_FUNCTION("eval_file",    f_njs_eval_file,
	       tFunc(tString,tMixed), OPT_SIDE_EFFECT);
  ADD_FUNCTION("execute",      f_njs_execute,
	       tFunc(tString,tMixed), OPT_SIDE_EFFECT);
  ADD_FUNCTION("compile",      f_njs_compile,
	       tFunc(tString,tString), 0);
  ADD_FUNCTION("compile_file",  f_njs_compile_file,
	       tFunc(tString,tString), 0);
  ADD_FUNCTION("add_scope",     f_njs_add_scope,
	       tFunc(tString
		     tFunc(tString tString tOr(tObj, tVoid), tMixed)
		     tOr(tVoid, tFunc(tString tString tMixed tOr(tObj, tVoid),
				      tInt)),
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
