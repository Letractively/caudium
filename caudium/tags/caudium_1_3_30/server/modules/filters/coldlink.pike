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
 * Kai Voigt and Andreas.
 *
 * Portions created by the Initial Developer are Copyright (C)
 * Kai Voigt and Andreas & The Caudium Group. All Rights Reserverd.
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

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "ColdLink";
constant module_doc  = "Stops HOTlinks on this website.";
constant module_unique= 1;

void create() {

 defvar("hosts", "", "Referer hosts", TYPE_TEXT_FIELD,
	"allow referer hostlist<br>"
	"Syntax:<pre>"
	"	myfirstdomain.com:allow\n"
	"	www.myfirstdomain.com:allow\n"
	"	myotherdomain.com:allow\n"
	"	www.myotherdomain.com:allow\n"
	"	ex-girlfriends.com:deny:/block.html\n"
	"	bad.links.com:deny:/block.html");


defvar("extentions", "", "Extention rules ", TYPE_TEXT_FIELD,
	"extentions rules (<i>NOTE:</i> the hostlist overrides extentions) <br />"
	"Syntax:<pre>"
	"	jpg:/error.jpg\n"
	"	gif:/error.gif\n"
	"	mpg:/error.html\n"
	);



}

mixed filter(mapping res, object id)
	{
	if (!id->request_headers->referer)
		{ return 0; } //if no referer....


	string referer_host, my_host;
	sscanf(id->request_headers->referer, "%*s://%[^/:]", referer_host);
	referer_host = lower_case(referer_host);
	my_host = lower_case((id->request_headers->host/":")[0]);

// test hosts...
	if (referer_host == my_host)  // Locallink?
	{ return 0; }

	foreach(QUERY(hosts)/"\n",string tmp)
	{
	array tmp1= tmp/":";

	if(lower_case(tmp1[0]) == referer_host && lower_case(tmp1[1]) == "allow") // ALLOW host
		{ return 0; }

	if(lower_case(tmp1[0]) == referer_host && lower_case(tmp1[1]) == "deny")  // DENY host
		{
		if(id->not_query ==tmp1[2]) return 0;
		return (Caudium.HTTP.redirect(tmp1[2],id));
		}
	}

	// test extentions based
	array  tmp_ext = basename(id->not_query)/".";
	string file_ext =tmp_ext[sizeof(tmp_ext)-1];

	foreach(QUERY(extentions)/"\n",string tmp)
	{
	array tmp1= tmp/":";
	if(tmp1[0] ==file_ext) return (Caudium.HTTP.redirect(tmp1[1],id));
	}

return 0;
}
