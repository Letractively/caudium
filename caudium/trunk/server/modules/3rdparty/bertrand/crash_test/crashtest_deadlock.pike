/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2005 The Caudium Group
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

constant module_name = "Crash Test: deadlock";
constant module_doc = 
	"<p>This module lock a mutex that is never released. Since this it is not "
	"declared as thread safe, this module can't be runned a second time, "
	"blocking the 1st level virtual server where it is enabled.</p>"
	"<p><strong>Warning:</strong> this module is intended for educational "
	"purpose only, eg watchdog testing.</p>";

constant module_unique = 1;
constant thread_safe = 0;


// Global variables
Thread.Mutex mutex = Thread.Mutex();
Thread.MutexKey key;



/*******************************************************************************
  Caudium API
*******************************************************************************/


//! Construtor for the module
void create()
{
	// Be fool proof: don't block Caudium by default
	defvar(
		"i_know_what_im_doing",
		0,
		"Block Caudium?",
		TYPE_FLAG,
		"<p>Do you really want to block Caudium?</p>"
		"<p>If yes, all the requests to your 1st level virtual host will be "
		"blocked.</p>"
		"<p>Watchdog behavior:"
		"<ul>"
		"<li><strong>PING</strong>: won't notice</li>"
		"<li><strong>GET</strong>: will notice</li>"
		"</ul>"
		"</p>");

	defvar(
		"sleeptime",
		0,
		"How many seconds to sleep?",
		TYPE_INT,
		"<p>How many seconds you want you Caudium to be asleep?</p>"
		"<p><strong>Warning:</strong> while Caudium is asleep, it can't handle "
		"any request, including other virtual servers and the CIF</p>"
		"<p><strong>Warning:</strong> If you change this value, you won't be able "
		"to reset it back using the CIF, since Caudium will be restarted before "
		"you'll be able to get this screen; you'll either have to edit your "
		"virtual server config file, either to start Caudium without the watchdog."
		"</p>"
		"<p>Watchdog behavior:"
		"<ul>"
		"<li><strong>PING</strong>: will notice</li>"
		"<li><strong>GET</strong>: will notice</li>"
		"</ul>"
		"</p>",
		0,
		dont_show_cif_sleeptime);
}


//! Method called first for every request within this 1st level virtual host
void precache_rewrite()
{
	if(QUERY(i_know_what_im_doing))
	{
		report_debug("CT Deadlock: Locking a mutex\n");
	
		// Lock a mutex, and never release it 
		// This will prevent this module from being run again 
		key = mutex->lock();

		int timetosleep = QUERY(sleeptime);
		report_debug("CT Deadlock: Sleeping "+timetosleep+" seconds\n");

		// Sleep: block everything	
		sleep(QUERY(sleeptime));
	}
}


//! Display of the status in the CIF
string status()
{
	string out = "";

	if(thread_safe)
		out += "<p>This module is declared as <strong>thread safe</strong></p>";
	else
		out += "<p>This module is declared as <strong>not thread safe</strong></p>";

	mixed keylock = mutex->current_locking_key();
	if(keylock)
	{
		out += "<p>The mutex <strong>is</strong> locked, all the requests to your ";
		out += "virtual server are blocked.</p>";
	}
	else
		out += "<p>The mutex <strong>is not</strong> locked</p>";

	return out;
}



/*******************************************************************************
  Module-specific code
*******************************************************************************/


//! Decide wether to show the sleeptime option in the CIF or not
//!
//! @returns
//!  1 if the option should be shown
//!  0 otherwise
int dont_show_cif_sleeptime()
{
	int show = QUERY(i_know_what_im_doing);
	return !show;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: i_know_what_im_doing
//! <p>Do you really want to block Caudium?</p><p>If yes, all the requests to your 1st level virtual host will be blocked.</p><p>Watchdog behavior:<ul><li><strong>PING</strong>: won't notice</li><li><strong>GET</strong>: will notice</li></ul></p>
//!  type: TYPE_FLAG
//!  name: Block Caudium?
//
//! defvar: sleeptime
//! <p>How many seconds you want you Caudium to be asleep?</p><p><strong>Warning:</strong> while Caudium is asleep, it can't handle any request, including other virtual servers and the CIF</p><p><strong>Warning:</strong> If you change this value, you won't be able to reset it back using the CIF, since Caudium will be restarted before you'll be able to get this screen; you'll either have to edit your virtual server config file, either to start Caudium without the watchdog.</p><p>Watchdog behavior:<ul><li><strong>PING</strong>: will notice</li><li><strong>GET</strong>: will notice</li></ul></p>
//!  type: TYPE_INT
//!  name: How many seconds to sleep?
//

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

