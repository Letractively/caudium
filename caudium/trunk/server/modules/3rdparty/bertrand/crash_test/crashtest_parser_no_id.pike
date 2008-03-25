/* -*-Pike-*-
 *
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
 * $Id$
 *
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
 * Bertrand LUPART <bertrand AT caudium NET net>
 *
 * Portions created by the Initial Developer are Copyright (C)
 * Bertrand LUPART & The Caudium Group. All Rights Reserved.
 *
 * Contributor(s):
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

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_version = "$Id$";
constant module_type = MODULE_PARSER;

constant module_name = "Crash Test: Parse RXML with no RequestID object";
constant module_doc =
  "<p>This module simulates a parse_rxml() invocation with an empty RequestID "
	"object.</p>"
	"<p>Its main goal is to study a bug trigered in some cases by the CGI code "
	"and it doesn't have any interrest on its own.</p>"
	"<p>To use this module, please:<ul>"
	"<li>use the &lt;crashtest_parse_no_id&gt;&lt;/crashtest_parse_no_id&gt; "
	"container in a RXML-parsed guinea pig page</li>"
	"<li>activate the module in the configuration interface</li>"
	"<li>watch what happen in the error log when trying to serve the guinea pig "
	"page</li>"
	"</ul></p>"
  "<p><strong>Warning</strong>: this module is intended for educational "
  "purpose only, eg for monitoring systems testing.</p>";

constant module_unique = 1;
constant thread_safe = 1;



/*******************************************************************************
  Caudium API
*******************************************************************************/

//! Construtor for the module
void create()
{
  // Fool proof: don't do the test by default
  defvar(
    "i_know_what_im_doing",
    0,
    "Try to lock the server?",
    TYPE_FLAG,
    "<p>Do you really want this module to try to lock your Caudium server?</p>"
    );
}

mapping query_container_callers()
{
	return
		([
			"crashtest_parse_no_id" : container_crashtest_parse_no_id,
		]);
}



/*******************************************************************************
  Module-specific methods
*******************************************************************************/

string container_crashtest_parse_no_id(string tag_name, mapping m, string content, object id)
{
	object empty_id;

	werror("crashtest parse no id\n");
	if(QUERY(i_know_what_im_doing))
	{
		werror("Here we go...\n");
		content = parse_rxml(content, empty_id);
	}

	return Caudium.make_container("div", m , content);
}
