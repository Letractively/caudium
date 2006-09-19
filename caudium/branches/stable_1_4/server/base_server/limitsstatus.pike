/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2006 The Caudium Group
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

inherit "wizard";
constant name= "Status//Limits Status";

constant doc = ("Show data on the limits set by the operating system.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

int verify_0()
{
  return 1;
}

mixed page_0(object id, object conf)
{
	string out = "";

	out += "<table>";
	out += "<tr><th>Resource</th><th>Soft</th><th>Hard</th></tr>";
	foreach(System.getrlimits(); mixed resource; mixed limits)
	{
		out += sprintf("<tr><td>%s</td><td align='right'>%s</td><td align='right'>%s</td></tr>", (string)resource, ((string)limits[0]||""), ((string)limits[1]||"") );
	}
	out += "</table>";

	return out;
}

mixed handle(object id) { return wizard_for(id,0); }
