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
  if (!THIS->id)
    return JS_FALSE;
  
  return JS_TRUE;
}

JS_FUNCDEF(caudium_pikever)
{
  JSString       *str;
  void           *verbytes;
  
  f_version(0);
  
  verbytes = JS_malloc(ctx, Pike_sp[-1].u.string->len + 1);
  if (!verbytes)
    return JS_FALSE;

  memcpy(verbytes, Pike_sp[-1].u.string->str, Pike_sp[-1].u.string->len + 1);
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
