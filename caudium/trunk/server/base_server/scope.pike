/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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

//! file: base_server/scope.pike
//!  The base scope class. Implements the default versions of all scope
//!  callback functions. It should be inherited by each scope.
//! cvs_version: $Id$


//! method: object set(string name, mixed value)
//!  Set the value of an entity in the current scope.
//! arg: string name
//!  The name of the entity.
//! arg: mixed value
//!  The value to set to the entity.
//! returns:
//!  0 for failure (ie read-only scope) and 1 for success.
int set(string name, mixed value) {
  return 0;
}

//! method: array(string)|string get(string name, mixed ... args)
//!  Get the value of an entity in the scope.
//! arg: string name
//!  The name of tne entity to retrieve.
//! arg: mixed ... args
//!  Various extra arguments passed by the parser.
//! returns:
//!  If a string, the entity will be replaced with this string which will
//!  be RXML-parsed. Return an array with the first and only element being
//!  a string to avoid re-parsing the result. If 0 is returned the entity
//!  is replaced by the empty string.
//! name: scope->get - get the value of an entity in a scope

int get(string name, mixed ... args) {
  return 0;
}

//! method: object clone()
//!  Return a clone of this object. This is done for each request to
//!  allow for request-local variables in the class. The default behavior
//!  simply returns itself. No actual cloning is needed unless the scope
//!  has request-local variables.
//! returns:
//!  A clone of the current scope object.
//! scope: private
//! name: scope->clone - return a clone of the current scope object

object clone()
{
  return this_object();
}

string name;

string query_name()
{
  return name;
}
