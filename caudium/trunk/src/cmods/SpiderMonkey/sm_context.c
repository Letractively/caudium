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

static JSBool output_write(JSContext *ctx, JSObject *obj, uintN argc, jsval *argv, jsval *rval);
static JSBool output_writeln(JSContext *ctx, JSObject *obj, uintN argc, jsval *argv, jsval *rval);

/* Custom Caudium objects/functions */
static JSFunctionSpec output_functions[] = {
    {"write", output_write, 1, 0, 0},
    {"writeln", output_writeln, 1, 0, 0}
};

inline static void write_out(char *str, js_context *data)
{
    int    strbytes = strlen(str);
    
    if (data->output_buf_last + strbytes >= data->output_buf_len) {
        data->output_buf_len <<= 1; /* TODO: check for overflows and max
                                     * size limit */
        data->output_buf = (unsigned char*)realloc(data->output_buf, data->output_buf_len);
        if (!data->output_buf)
            Pike_error("Out of memory");
    }

    strncat(data->output_buf, str, data->output_buf_len);
    THIS->output_buf_last += strbytes;
}

static JSBool output_write(JSContext *ctx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)
{
    js_context   *data = (js_context*)JS_GetPrivate(ctx, obj);
    JSString     *str;
    uintN         i;
    
    if (!data)
        return JS_FALSE;

    if (!data->output_buf || !data->output_buf_len) {
        data->output_buf = (unsigned char*)malloc(sizeof(unsigned char) * DEF_OUTPUTBUF_LEN);
        if (!data->output_buf)
            Pike_error("Out of memory\n");
        data->output_buf_len = DEF_OUTPUTBUF_LEN;
        data->output_buf_last = 0;
        memset(data->output_buf, 0, data->output_buf_len);
    }
    
    for (i = 0; i < argc; i++) {
        str = JS_ValueToString(ctx, argv[i]);
        if (!str)
            return JS_FALSE;

        argv[i] = STRING_TO_JSVAL(str);
        write_out(JS_GetStringBytes(str), data);
    }

    return JS_TRUE;
}

static JSBool output_writeln(JSContext *ctx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)
{
    js_context   *data = (js_context*)JS_GetPrivate(ctx, obj);
    JSBool        ret = output_write(ctx, obj, argc, argv, rval);

    if (!ret)
        return JS_FALSE;

    if (data)
        write_out("\n", data);
    else
        return JS_FALSE;

    return JS_TRUE;
}

/*! @class Context
 *!
 *! The Context class implements a SpiderMonkey JavaScript engine
 *! context. Caudium creates one instance of such context per each backend
 *! thread running in the server. This is the actual workhorse of the
 *! Caudium JavaScript extension.
 */

/*! @decl void create(void|int version, void|int stacksize)
 *!
 *! Creates an instance of the Context class.
 *!
 *! @param version
 *!  This context will be initially made compatible with the specified
 *!  JavaScript version. The following constants are accepted as the value
 *!  of this parameter:
 *!
 *!   @dl
 *!    @item JSVERSION_1_0
 *!     JavaScript v1.0
 *!    @item JSVERSION_1_1
 *!     JavaScript v1.1
 *!    @item JSVERSION_1_2
 *!     JavaScript v1.2
 *!    @item JSVERSION_1_3
 *!     JavaScript v1.3 (ECMA)
 *!    @item JSVERSION_1_4
 *!     JavaScript v1.4 (ECMA)
 *!    @item JSVERSION_1_5
 *!     JavaScript v1.5 (ECMA)
 *!   @enddl
 *!
 *!  The default value is @b{JSVERSION_1_5@}
 *!
 *! @param stacksize
 *!  Sets the size of the private stack for this context. Value given in
 *!  bytes. Defaults to 8192.
 */
static void ctx_create(INT32 args)
{
    INT32      version = JSVERSION_1_5;
    INT32      stacksize = 8192;

    switch(args) {
        case 2:
            get_all_args("create", args, "%i%i", &version, &stacksize);
            break;

        case 1:
            get_all_args("create", args, "%i", &version);
            break;
    }

    THIS->ctx = JS_NewContext(smrt, stacksize);
    if (!THIS->ctx)
        Pike_error("Could not create a new context\n");
    
    if (!init_globals(THIS->ctx))
        Pike_error("Could not initialize the new context.\n");

    if (!JS_DefineFunctions(THIS->ctx, global, output_functions))
        Pike_error("Could not populate the global object with output functions\n");
    
    JS_SetVersion(THIS->ctx, version);

    /* create some privacy for us */
    if (!JS_SetPrivate(THIS->ctx, global, THIS))
        Pike_error("Could not set the private storage for the global object\n");
    
    pop_n_elems(args);
}

static void ctx_evaluate(INT32 args)
{
    JSBool              ok;
    JSString           *str;
    jsval               rval;
    struct pike_string *script;
    INT32               version = -1, oldversion = -1;

    if (!THIS->ctx) {
        pop_n_elems(args);
        push_int(0);
        return;
    }
    
    switch(args) {
        case 2:
            get_all_args("evaluate", args, "%S%i", &script, &version);
            break;

        case 1:
            get_all_args("evaluate", args, "%S", &script);
            break;

        default:
            Pike_error("Not enough arguments\n");
    }

    if (version != -1)
        oldversion = JS_SetVersion(THIS->ctx, version);
    
    /* TODO: filename should indicate the actual location of the script */
    ok = JS_EvaluateScript(THIS->ctx, global,
                           script->str, script->len,
                           "Caudium/js", 0, &rval);

    if (oldversion != -1)
        JS_SetVersion(THIS->ctx, oldversion);
    
    pop_n_elems(args);
    
    if (!ok) {
        push_int(-1);
        return;
    }

    if (!JSVAL_IS_NULL(rval) && !JSVAL_IS_VOID(rval)) {
        struct pike_string    *ret;
        unsigned char         *tmp = NULL, *tval;
        size_t                 blen = 0;
        
        str = JS_ValueToString(THIS->ctx, rval);

        tval = JS_GetStringBytes(str);
        
        if (THIS->output_buf && THIS->output_buf_last) {
            blen = strlen(tval) + strlen(THIS->output_buf) + 1;
            tmp = (unsigned char*)alloca(blen);
            if (!tmp)
                Pike_error("Out of memory\n");
        }

        if (tmp) {
            strncpy(tmp, THIS->output_buf, blen);
            strncat(tmp, tval, blen - strlen(tmp));
            memset(THIS->output_buf, 0, THIS->output_buf_len);
            THIS->output_buf_last = 0;
        } else
            tmp = tval;
        
        push_text(tmp);
    } else
        push_text("");
}

static void ctx_init(struct object *obj)
{
    THIS->ctx = NULL;
    THIS->output_buf = NULL;
    THIS->output_buf_len = THIS->output_buf_last = 0;
}

static void ctx_exit(struct object *obj)
{
    if (THIS->ctx) {
        JS_DestroyContext(THIS->ctx);
        THIS->ctx = NULL;
    }

    if (THIS->output_buf) {
        free(THIS->output_buf);
        THIS->output_buf = NULL;
        THIS->output_buf_len = THIS->output_buf_last = 0;
    }
}

void init_context()
{
    set_init_callback(ctx_init);
    set_exit_callback(ctx_exit);
    
    ADD_STORAGE(js_context);
    ADD_FUNCTION("create", ctx_create,
                 tFunc(tOr(tVoid, tInt) tOr(tVoid, tInt), tVoid), 0);
    ADD_FUNCTION("evaluate", ctx_evaluate,
                 tFunc(tString tOr(tVoid, tInt), tOr(tString, tInt)), 0);
}
#endif
