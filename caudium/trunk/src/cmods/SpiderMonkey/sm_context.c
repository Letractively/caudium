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
    if (!init_globals(ctx))
        Pike_error("Could not create a new context.");

    JS_SetVersion(THIS->ctx, version);
}

void init_context()
{
    ADD_FUNCTION("create", ctx_create,
                 tFunc(tOr(tVoid, tInt) tOr(tVoid, tInt), tVoid), 0);
}
#endif
