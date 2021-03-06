/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2002 The Caudium Group
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
#include "sm_main.h"
#include "sm_context.h"

#ifndef RT_MAXBYTES
#define RT_MAXBYTES (8L * 1024L * 1024L)
#endif

/* shared stuff, initialized only once */
JSRuntime      *smrt = NULL; /* the runtime */
JSObject       *global = NULL; /* the global object */
JSObject       *caudium = NULL;

static JSClass global_class = {
    "global", JSCLASS_NEW_RESOLVE,
    JS_PropertyStub, JS_PropertyStub,
    JS_PropertyStub, JS_PropertyStub,
    global_enumerate, (JSResolveOp)global_resolve,
    JS_ConvertStub, JS_FinalizeStub,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0
};

static JSBool global_enumerate(JSContext *ctx, JSObject *obj)
{
    return JS_EnumerateStandardClasses(ctx, obj);
}

static JSBool global_resolve(JSContext *ctx, JSObject *obj, jsval id, uintN flags, JSObject **objp)
{
    if (!(flags && JSRESOLVE_ASSIGNING)) {
        JSBool   resolved;

        if (!JS_ResolveStandardClass(ctx, obj, id, &resolved))
            return JS_FALSE;

        if (resolved) {
            *objp = obj;
            return JS_TRUE;
        }
    }

    return JS_TRUE;
}

int init_globals(JSContext *ctx)
{
  if (global || !smrt || !ctx)
    return 0;

  global = JS_NewObject(ctx, &global_class, NULL, NULL);
  if (!global) {
    fprintf(stderr, "SMJS: Failed to create the global object\n");
    return 0;
  }

  /*
   * The standard classess will be resolved when requested in the
   * global_resolve function, thus we don't have to initialize the
   * standard classes for the global object over here. That might speed
   * things up a bit.
   */
  JS_SetGlobalObject(ctx, global);

  caudium = init_caudium(ctx);
  return 1;
}

void pike_module_init(void)
{
  fprintf(stderr, "Initializing the JavaScript engine. ");

  smrt = JS_NewRuntime(RT_MAXBYTES);
  if (!smrt) {
    fprintf(stderr, "Failed.\n");
    return;
  }
  
  fprintf(stderr, "Succeeded.\n");

  add_integer_constant("JSVERSION_1_0", JSVERSION_1_0, 0);
  add_integer_constant("JSVERSION_1_1", JSVERSION_1_1, 0);
  add_integer_constant("JSVERSION_1_2", JSVERSION_1_2, 0);
  add_integer_constant("JSVERSION_1_3", JSVERSION_1_3, 0);
  add_integer_constant("JSVERSION_1_4", JSVERSION_1_4, 0);
  add_integer_constant("JSVERSION_1_5", JSVERSION_1_5, 0);
    
  start_new_program();
  init_context();
  end_class("Context", 0);
}

void pike_module_exit(void)
{
  if (!smrt)
    return;

  JS_DestroyRuntime(smrt);
  smrt = NULL; /* just in case... */
  global = NULL;
  JS_ShutDown();
}
#else
void pike_module_init(void)
{}

void pike_module_exit(void)
{}
#endif
/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
