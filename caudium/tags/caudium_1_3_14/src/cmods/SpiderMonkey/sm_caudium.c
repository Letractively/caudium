/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
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
#include "sm_config.h"

#ifdef HAVE_LIB_SMJS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <jsapi.h>

#include "sm_globals.h"
#include "sm_context.h"

JS_FUNCDEF(caudium_version);
JS_FUNCDEF(caudium_pikever);
JS_FUNCDEF(caudium_log_message);

static struct svalue   caudium_prog;

/*
 * The Caudium JS object.
 * Contains functions that provide information about the whole server and
 * ones that allow the programmer to output messages logged in the Caudium
 * debug log.
 */
static JSFunctionSpec caudium_functions[] = {
  {"version", caudium_version, 1, 0, 0},
  {"pikever", caudium_pikever, 1, 0, 0},
  {"log_message", caudium_log_message, 1, 0, 0},
  {0, 0, 0, 0, 0}
};

static JSClass caudium_class = {
  "Caudium", JSCLASS_HAS_PRIVATE | JSCLASS_NEW_ENUMERATE | JSCLASS_NEW_RESOLVE,
  JS_PropertyStub, JS_PropertyStub, JS_PropertyStub, JS_PropertyStub,
  JS_EnumerateStub, JS_ResolveStub, JS_ConvertStub, JS_FinalizeStub,
  NULL, NULL, NULL, NULL, NULL, NULL, 0, 0
};

JS_FUNCDEF(caudium_version)
{
  struct svalue    sv, res;
  JSString        *str;
  void            *verbytes;
  
  if (!THIS->id)
    return JS_FALSE;

  if (caudium_prog.type == PIKE_T_UNKNOWN) {
    /* find the caudium program */
    push_text("caudium");
    push_int(0);
    SAFE_APPLY_MASTER("resolv", 2);
    if (Pike_sp[-1].type == T_OBJECT) {
      push_text("caudium");
      f_index(2);
      caudium_prog.u.program = program_from_svalue(&Pike_sp[-1]);
      caudium_prog.type = T_PROGRAM;
    }
    pop_n_elems(1);
  }

  if (caudium_prog.type == PIKE_T_UNKNOWN)
    return JS_FALSE;

  sv.type = T_PROGRAM;
  sv.u.program = THIS->id->prog;
  
  if (!is_equal(&caudium_prog, &sv))
    return JS_FALSE;

  sv.type = T_STRING;
  sv.u.string = make_shared_string("real_version");

  object_index_no_free2(&res, THIS->id, &sv);
  if (!res.type == T_STRING)
    return JS_FALSE;

  verbytes = JS_malloc(ctx, res.u.string->len);
  if (!verbytes)
    return JS_FALSE;

  memcpy(verbytes, res.u.string->str, res.u.string->len);
  str = JS_NewString(ctx, verbytes, res.u.string->len);
  *rval = STRING_TO_JSVAL(str);
  
  return JS_TRUE;
}

JS_FUNCDEF(caudium_pikever)
{
  JSString       *str;
  void           *verbytes;
  
  f_version(0);
  
  verbytes = JS_malloc(ctx, Pike_sp[-1].u.string->len);
  if (!verbytes)
    return JS_FALSE;

  memcpy(verbytes, Pike_sp[-1].u.string->str, Pike_sp[-1].u.string->len);
  str = JS_NewString(ctx, verbytes, Pike_sp[-1].u.string->len);
  
  *rval = STRING_TO_JSVAL(str);

  pop_stack();
  
  return JS_TRUE;
}

JS_FUNCDEF(caudium_log_message)
{
  JSString    *str;

  if (argc < 1)
    return JS_FALSE;

  str = JS_ValueToString(ctx, argv[0]);
  if (!str)
    return JS_FALSE;

  /* just spit it to stderr */
  fprintf(stderr, JS_GetStringBytes(str));
  
  return JS_TRUE;
}

JSObject *init_caudium(JSContext *ctx)
{
  JSObject   *c;

  caudium_prog.type = PIKE_T_UNKNOWN;
  
  c = JS_DefineObject(ctx, global, "Caudium", &caudium_class, NULL, 0);

  if (!c)
    return NULL;

  if (!JS_DefineFunctions(ctx, c, caudium_functions))
    return NULL;
  
  return c;
}
#endif
/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
