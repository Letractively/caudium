/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

/*
 * File licensing and authorship information block.
 *
 * Version: MPL 1.1/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 *
 * David Hedbor <david@caudium.net>.
 *
 * Portions created by the Initial Developer are Copyright (C) Marek
 * Habersack & The Caudium Group. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Marek Habersack <grendel@caudium.net>, Xavier Beaudouin <kiwi@caudium.net>
 * and all the Caudium Group.
 *
 * Alternatively, the contents of this file may be used under the terms of
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the LGPL, and not to allow others to use your version
 * of this file under the terms of the MPL, indicate your decision by
 * deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL or the LGPL.
 *
 * Significant Contributors to this file are:
 *
 */

//!
constant cvs_version = "$Id$";

#if 0

//!  Return the scope and variable name based on the input data.
//! @param variable
//!  The variable to parse. Should be either "variable" or "scope.variable".
//!  If a specific scope is sent to the function, the variable is uses as-is
//!  for the variable name.
//! @param scope
//!  The optional scope. If present, this overrides any scope specification
//!  in the variable name. If left out, the scope is parsed from the variable
//!  name. 
//! @returns
//!  An array consisting of the scope and the variable.
//!
//! @note
//!  Non-RIS code
array(string) parse_var(string variable, string|void scope)
{
  array scvar = allocate(2);
  if (scope) {
    scvar[0] = scope;
    scvar[1] = variable;
  } else {
    if (sscanf(variable, "%s.%s", scvar[0], scvar[1]) != 2) {
      scvar[0] = "form";
      scvar[1] = variable;
    }
  }
  
  return scvar;
}

//!  Return the value of the specified variable in the specified scope.
//! @param variable
//!  The variable to fetch from the scope.
//! @param scope
//!  The scope of the variable. If zero, the scope will be extracted from
//!  the variable using [parse_scope_var].
//! @param id
//!  The request id object.
//! @returns
//!  The value of the variable or zero if the variable or scope doesn't
//!  exist.
//! @seealso
//!   @[set_var()], @[parse_var()]
//!
//! @note
//!  Non-RIS code
mixed get_var(string variable, void|string scope, object id)
{
  function _get;

  if (!id->misc->_scope_status) {
    if (id->variables && id->variables[variable])
      return id->variables[variable];
    return 0;
  }
  
  if(!scope)
    [scope,variable] = parse_var(variable);
  
  if(!id->misc->scopes[scope])
    return 0;
  
  if(!(_get = id->misc->scopes[scope]->get))
    return 0;
  
  return _get(variable, id);
}

//!  Set the specified variable in the specified scope to the value.
//! @param variable
//!  The variable to fetch from the scope.
//! @param scope
//!  The scope of the variable. If zero, the scope will be extracted from
//!  the variable using [parse_scope_var].
//! @param value
//!  The value to set the variable to.
//! @param id
//!  The request id object.
//! @returns
//!  1 if the variable was set correctly, 0 if it failed.
//! 
//! @seealso
//!  @[get_var()], @[parse_var()]
//!
//! @note
//!  non-RIS code
int set_var(string variable, void|string scope, mixed value, object id)
{
  function _set;

  if (!id->misc->_scope_status) {
    id->variables[variable] = value;
    return 1;
  }
  
  if(!scope)
    [scope,variable] = parse_var(variable);
  
  if(!id->misc->scopes[scope])
    return 0;
  
  if(!(_set = id->misc->scopes[scope]->set))
    return 0;
  
  return _set(variable, value, id);
}

//!  Parse the data for entities.
//! @param data
//!  The text to parse.
//! @param cb
//!  The function called when an entity is encountered. Arguments are:
//!  the parser object, the entity scope, the entity name, the request id
//!  and any extra arguments specified.
//! @param id
//!  The request id object.
//! @param extra
//!  Optional arguments to pass to the callback function.
//! @returns
//!  The parsed result.
//!
//! @note
//!  non-RIS code
static mixed cb_wrapper(object parser, string entity, object id, function cb,
                        mixed ... args) {
  string scope, name, encoding;
  array tmp = (parser->tag_name()) / ":";
  entity = tmp[0];
  encoding = tmp[1..] * ":";

  if (!encoding || !strlen(encoding))
    encoding = (id && id->misc->_default_encoding) || "html";
  if (sscanf(entity, "%s.%s", scope, name) != 2)
    return 0;
  
  mixed ret = cb(parser, scope, name, id, @args);
  
  if(!ret)
    return 0;
  if(stringp(ret))
    return roxen_encode(ret, encoding);
  if(arrayp(ret))
    return Array.map(ret, roxen_encode, encoding);    
}

//! Parse the passed string looking for entities referring to the scopes
//! defined in Caudium.
//!
//! @param data
//!  The string to parse
//!
//! @param cb
//!  The callback for extra data found in the string.
//!
//! @param id
//!  The request ID in which context the function is called.
//!
//! @param extra
//!  Extra parameters sent to the @tt{cb@} callback
//!
//! @returns
//!  The input string with all the defined entities replaced.
//!
//! @note
//!  non-RIS code
string parse_scopes(string data, function cb, object id, mixed ... extra) {
  object mp = Parser.HTML();
  mp->lazy_entity_end(1);
  mp->ignore_tags(1);
  mp->set_extra(id, cb, @extra);

  mp->_set_entity_callback(cb_wrapper);
  return mp->finish(data)->read();
}

#endif

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
