/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2007 The Caudium Group
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
/*
 * $Id$
 */

//! Storage Module : None Method

/*
 * The Storage module and the accompanying code is Copyright © 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   Bill Welliver	<hww3@caudium.net>
 *
 */

//!
constant storage_type    = "None";

//!
constant storage_doc     = "";

//!
static string version = sprintf("%d.%d.%d", __MAJOR__, __MINOR__, __BUILD__); 

//!
void create() {
}

//!
void store(string namespace, string key, string value) {
}

//!
mixed retrieve(string namespace, string key) {
    return 0;
}

//!
void unlink(string namespace, void|string key) {
}

//!
void unlink_regexp(string namespace, string regexp) {
}

//!
int size(string namespace) {
  return 0;
}

//!
array list(string namespace) {
 ({});
}
