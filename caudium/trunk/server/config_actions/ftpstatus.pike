/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

/* $Id$ */

inherit "wizard";

constant name= "Status//Current FTP sessions";
constant doc = "List all active FTP sessions and what files they are "
  "currently transferring.";
constant wizard_name = "Active FTP sessions";

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

static string describe_ftp(object ftp)
{
  string res = "<tr>";

  res += "<td>"+
    caudium->blocking_ip_to_host(((ftp->cmd_fd->query_address()||"")/" ")[0])+
    "</td>";

  if(ftp->session_auth)
    res += "<td>"+ftp->session_auth[1]+"</td>";
  else
    res += "<td><i>anonymous</i></td>";

  res += "<td>"+ftp->cwd+"</td>";

  if(ftp->curr_pipe || ftp->my_fd) {

    res += "<td>"+ftp->method+"</td><td>"+ftp->not_query+"</td>";

    if(ftp->curr_pipe) {
      int b;
      res += "<td>"+(b=ftp->curr_pipe->bytes_sent())+" bytes";
      if(ftp->file && ftp->file->len && ftp->file->len!=0x7fffffff)
	res += sprintf(" (%1.1f%%)", (100.0*b)/ftp->file->len);
      res += "</td>";
    } else if(ftp->my_fd) {
      int b;
      res += "<td>"+(b=ftp->my_fd->bytes_received())+" bytes";
      if(ftp->misc->len && ftp->misc->len!=0x7fffffff)
	res += sprintf(" (%1.1f%%)", (100.0*b)/ftp->misc->len);
      res += "</td>";
    }
  } else
    res += "<td><i>idle</i></td>";

  return res + "</tr>\n";
}

string page_0(object id)
{
  program p = ((program)"protocols/ftp");
  object pc = clone(p);
  multiset(object) ftps = (< >);
  object o = next_object();
  for(;;) {
    if(o && object_program(o) == object_program(pc) && o->cmd_fd)
      ftps += (<o>);
    if(catch(o = next_object(o)))
      break;
  }

  if(sizeof(ftps))
    return "<table border=0><tr align=left><th>From</th><th>User</th>"
      "<th>CWD</th><th>Action</th><th>File</th><th>Transferred</th></tr>\n"+
      Array.map(indices(ftps), describe_ftp)*""+"</table>\n";
  else
    return "There are currently no active FTP sessions.";
}

int verify_0()
{
  return 1;
}

string handle(object id)
{
  return wizard_for(id,0);
}
