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

/* Glue for the embeddable NJS JavaScript Interpreter. See
 * http://www.bbassett.net/njs/
 */

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "njs_config.h"

#ifdef HAVE_NJS

/* Utility function to convert a JavaScript type to a Pike type and
 * push it onto the stack.
 */

void push_js_type(JSType val) {
  unsigned int i;
  switch(val.type) {
   case JS_TYPE_UNDEFINED:
   case JS_TYPE_NULL:
    push_int(0);
    break;
   case JS_TYPE_BOOLEAN:
   case JS_TYPE_INTEGER:
    push_int64(val.u.i);
    break;
   case JS_TYPE_STRING:
    push_string(make_shared_binary_string(val.u.s->data, val.u.s->len));
    break;
   case JS_TYPE_DOUBLE:
    push_float(val.u.d);
    break;
   case JS_TYPE_ARRAY:
    for(i = 0; i < val.u.array->length; i++) {
      push_js_type(val.u.array->data[i]);
    }
    push_array(aggregate_array(val.u.array->length));
    break;
   case JS_TYPE_BUILTIN:
    /* FIXME: these are builtin classes. How should we handle them? */
    push_int(0);
    break;
  }
}

/* Convert a pike type to a javascript type if possible. Returns 1 if
 * it succeeded, 0 otherwise.
 */
int pike_type_to_js_type(JSInterpPtr interp,
			  struct svalue *from, JSType *to) {
  INT32 i;
  switch(from->type) {
   case T_STRING:
    js_type_make_string(interp, to, from->u.string->str, from->u.string->len);
    break;

   case T_INT:
    to->type = JS_TYPE_INTEGER;
    to->u.i = from->u.integer;
    break;

   case T_FLOAT:
    to->type = JS_TYPE_DOUBLE;
    to->u.d = from->u.float_number;
    break;

   case T_ARRAY:
    js_type_make_array(interp, to, from->u.array->size);
    for(i = 0; i < from->u.array->size; i++) {
      pike_type_to_js_type(interp, & (ITEM(from->u.array)[i]), 
			   & (to->u.array->data[i]));
    }
    break;
   default:
    to->type = JS_TYPE_UNDEFINED;
    return 0;
  }
  return 1;
}

/* Init the module */
void pike_module_init(void)
{  
  njs_init_interpreter_program();
}

/* Restore and exit module */
void pike_module_exit( void ) { }

#else /* HAVE_NJS */
void pike_module_exit( void ) { }

void pike_module_init( void ) { }
#endif /* HAVE_MHASH */

/*
 * Local variables:
 * c-basic-offset: 2
 * End:
 */
