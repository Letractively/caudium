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

#ifndef NJS_CONFIG_H
#define NJS_CONFIG_H

@TOP@

@BOTTOM@

#undef HAVE_NJS
#ifdef HAVE_NJS
#include <njs/njs.h>
#include "njs_global.h"
#endif
#endif
