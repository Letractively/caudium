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
 * $Id$
 */
#ifndef __SM_CONTEXT_H
#define __SM_CONTEXT_H

typedef struct 
{
    JSContext       *ctx;
    struct object   *id;
    unsigned char   *output_buf;
    unsigned int     output_buf_len;
    unsigned int     output_buf_last;
} js_context;

#define THIS ((js_context*)(Pike_interpreter.frame_pointer->current_storage))
#define JS_FUNCDEF(name) static JSBool name (JSContext *ctx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)

#define DEF_OUTPUTBUF_LEN 8192

/* in sm_caudium.c */
JSObject *init_caudium(JSContext*);
#endif
/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
