/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
constant name= "Status//Open files";

constant doc = ("Show a list of all open files.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

int verify_0()
{
  return 1;
}

#include <stat.h>

// Debug functions.  List _all_ open filedescriptors
inline static private string fix_port(string p) {
  array(string) a = p / " ";
  if(a[0] == "0.0.0.0") 
    a[0] = "*";
  if(a[1] == "0")
    a[1] = "ANY";
  return a * ":";
}

string page_0()
{
  return
    ("<h1>Active filedescriptors</h1>\n"+
     sprintf("<pre><b>%-5s  %-9s  %-10s   %-10s</b>\n\n",
	     "fd", "type", "mode", "details")+
	     
     (Array.map(spider.get_all_active_fd(),
	  lambda(int fd) 
	  {
		object f = Stdio.File(fd);
		object stat = f->stat();

		string type;
		mixed err = catch{
			type = ([
				"reg":"File",
				"dir":"Dir",
				"lnk":"Link",
				"chr":"Special",
				"blk":"Device",
				"fifo":"FIFO",
				"sock":"Socket",
				"unknown":"Unknown",
			])[stat->type] || "Unknown";
		};
		if (err)
			type = "Unknown";

		// Doors are not standardized yet....
		if ((type == "Unkown") && ((stat->mode & 0xf000) == 0xd000))
			type = "Door";

		string details = "-";

		if(stat->isreg) 
			details = Caudium.sizetostring(stat->size);
		if(stat->ino)
			details += sprintf(", inode: %d", stat->ino);
		else if (stat->issock) {
			string remote_port = f->query_address();
			string local_port = f->query_address(1);
			if(!remote_port) {
				if(local_port && (local_port != "0.0.0.0 0")) {
					type = "Port";
					details = fix_port(local_port);
				}
			} else {
				details = sprintf("%s &lt;=&gt; %s",
						local_port?fix_port(local_port):"-",
						fix_port(remote_port));
			}
		}
		return sprintf("%-5s  %-9s  %-10s  %-12s",
				(string)fd, type, stat->mode_string, details);
	  })*"\n")+
     "</pre>");
}

mixed handle(object id) { return wizard_for(id,0); }

