/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
constant module_type = MODULE_PRECACHE;

constant module_name = "Crash Test: memory leak";
constant module_doc = 
	"<p>This module simulates a memory leak.</p>"
	"<p>For each request in the virtual host it is set up, the module will grow "
	"from the amount specified in the CIF.</p>"
	"<p><strong>Warning</strong>: this module is intended for educational "
	"purpose only, eg for monitoring systems testing.</p>";

constant module_unique = 1;
constant thread_safe = 1;


// Global variables
array leaked = ({ });		// Object refering strings leaked
int leak_scount = 0;		// The total size of strings leaked 
int leak_ncount = 0;		// The number of strings leaked



/*******************************************************************************
  Caudium API
*******************************************************************************/


//! Construtor for the module
void create()
{
	// Fool proof: don't grow Caudium by default
	defvar(
		"i_know_what_im_doing",
		0,
		"Leak",
		TYPE_FLAG,
		"<p>Do you really want this module to leak and Caudium to indefinitely "
		"grow in size?</p>"
		"<p><strong>Warning:</strong> enabling this and running the watchdog with "
		"GET method will make Caudium grow in size.</p>");

	defvar(
		"leak_size",
		0,
		"Leak size (in bytes)",
		TYPE_INT,
		"<p>By what size do you want Caudium to grow for each request?</p>",
		0,
		dont_show_cif_leaksize);
}


//! Method called first for every request within this 1st level virtual host
void precache_rewrite()
{
	if(QUERY(i_know_what_im_doing))
	{
		report_debug("CT Memory leak: Growing\n");

		int leak_size = QUERY(leak_size);

		if(leak_size)
		{
			string leak = random_string(leak_size);
			// The leaked strings have a local scope...
			leaked += ({ leak });
			// ...but since they're referenced by a global array, the garbage
			// collector don't collect them
			leak_scount += leak_size;
			leak_ncount++;
		}
	}
}


//! Display the of status in the CIF
string status()
{
	string out = "";

	if(QUERY(i_know_what_im_doing))
		out += "<p>Leaking <strong>is enabled</strong></p>";
	else
		out += "<p>Leaking <strong>is not enabled</strong></p>";

	out += 
		"<p>This modules currently leaks: "+
		"<ul><li>"+leak_ncount+" strings</li>"+
		"<li>"+leak_scount+" bytes</li></ul></p>";

	return out;
}



/*******************************************************************************
  Module-specific methods
*******************************************************************************/

//! Decide wether to show the leaking size option in the CIF or not
//!
//! @returns
//!  1 if the option should be shown
//!  0 otherwise
int dont_show_cif_leaksize()
{
	int show = QUERY(i_know_what_im_doing);
	return !show;
}
