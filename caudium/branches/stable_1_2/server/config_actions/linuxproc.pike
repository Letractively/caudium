/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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
constant name= "Status//Extended process status";
constant doc = "Shows detailed process status and process tree on Linux machines.";

constant more=1;

void create()
{
  if(!file_stat("/usr/bin/pstree")) {
    throw("You need /usr/bin/pstree to be installed\n");
  }
  if(!file_stat("/proc/1/status")) {
    throw("You need a kernel with the proc filesystem mounted.\n");
  }
}
string format_env_line(string in, int ipid)
{
  if(!strlen(in))
    return "";

  array line = in / "=";
  if(sizeof(line) < 2)
    return "";
  return sprintf(" <tr valign=top>\n  <th align=left>%s</th>\n  <td>%-=70s</td>\n </tr>\n",
		 line[0], line[1..]*"=");
  
}

string format_proc_line(string in, int ipid)
{
  string pre, opts="";
  int end, begin;
  int pid;
  sscanf(in, "%*s(%d)%*s", pid);
  if(!pid)
    sscanf(in, "%*s(%*s,%d)%*s", pid);

  in = replace(in, ({"|-", "`-"}), ({"+-", "+-"}));
  if(in[0] == ' ')
    begin = search(in, "+-") + 2;
  if((end = search(in, ") ")) == -1 &&(end = search(in, ")")) == -1) 
    end =  strlen(in) -1;
  else
    opts =  html_encode_string(replace(sprintf("%-=65s", in[end+1..]), "\n",
				       "\n" + " "*(end+2)));
  //  perror("%d %d %s\n", begin, end, in[begin..end], in[end+1..]);

  if(search(in,"/proc/")==-1)
    return ((begin ? html_encode_string(in[0..begin-1]) :"")+
	    "<a href=?action=linuxproc.pike&pid="+pid+"&unique="+time()+">"+
	    (ipid==pid?"<b>":"")+
	    html_encode_string(in[begin..end])+
	    (ipid==pid?"</b>":"")+"</a>"+opts+
	    "\n");
  return "";
}

string get_status(int pid)
{
  mapping data = ([ "state": "unknown", "name": "No name is a bad name"]);
  string wd = getcwd();

  //  cd("/proc/"+pid+"/cwd/"); 
//  cwd = getcwd();
//  cd(wd);
  array tmp;
  string status = Stdio.read_file("/proc/"+pid+"/status");
  if(!status || !strlen(status))
    return "<i>Failed to read /proc/. Process died?</i>";
  foreach(status / "\n", string line)
  {
    tmp = line / ":";
    if(sizeof(tmp) != 2)
      continue;
    string unmod = tmp[1];
    tmp[1] -= " ";
    tmp[1] -= "\t";
    tmp[0] = lower_case(tmp[0]);
    switch(tmp[0])
    {
     case "name":
      data->name = tmp[1];
      break;
      
     case "state":
      sscanf(tmp[1], "%*s(%s)", data->state);
      break;

     case "ppid":
     case "vmrss":
     case "vmdata":
     case "vmstk":
     case "vmexe":
     case "vmlck":
     case "vmlib":
     case "vmsize":
      data[ tmp[0] ] = (int)tmp[1];
      break;

     case "uid":
      data->uid = unmod / "\t" - ({""});
#if constant(getpwuid)
      for(int i = 0; i < sizeof(data->uid); i++)
	catch {
	  data->uid[i] = getpwuid((int)data->uid[i])[0];
	};
#endif
      break;

     case "gid":
      data->gid = unmod / "\t" - ({""});
#if constant(getgrgid)
      for(int i = 0; i < sizeof(data->gid); i++)
	catch {
	  data->gid[i] = getgrgid((int)data->gid[i])[0];
	};
#endif
      break;
    }
  }
  data->ppids = "";
  while(data->ppid != 0)
  {
    if(strlen(data->ppids))
      data->ppids += " => ";
    data->ppids += sprintf("<a href=/Actions/?action=linuxproc.pike&pid=%d&"
			   "unique=%d>%d</a>", data->ppid, time(), data->ppid);
    status = Stdio.read_file("/proc/"+data->ppid+"/status");
    if(!stringp(status) || !strlen(status))
    {
      data->ppids += " => [ failed, process died? ]";
      break;
    }
    sscanf(status, "%*sPPid:\t%d\n%*s", data->ppid);
  }

  if(!strlen(data->ppids))
    data->ppids = "None";

  data->fds   = "";
  if((tmp = get_dir("/proc/"+pid+"/fd/")) && sizeof(tmp))
    data->fds = sprintf("<b>Num open fd's:</b> %d\n", sizeof(tmp));

  string out = sprintf("<b>Process name:</b>  %s\n"
		       "<b>Process state:</b> %s\n"
		       "<b>Parent pid(s):</b> %s\n"
		       "%s" // fds
//		       "<b>CWD:</b>           %s\n\n"
		       "<b>Memory usage</b>:\n\n"
		       "  Size (incl. mmap): %6d kB"
		       "    RSS:          %6d kB\n"
		       "  Data:              %6d kB"
		       "    Stack:        %6d kB\n"
		       "  Locked:            %6d kB"
		       "    Executable:   %6d kB\n"
		       "  Libraries:         %6d kB\n\n"
		       "<b>User and group information:</b>\n\n"
		       "  <b>    %8s  %12s</b>\n"
		       "  <b>uid</b> %8s  %12s\n"
		       "  <b>gid</b> %8s  %12s\n\n",
		       data->name, data->state,
		       data->ppids, data->fds,
		       //		       cwd,
		       data->vmsize,
		       data->vmrss, data->vmdata, data->vmstk, data->vmlck,
		       data->vmexe, data->vmlib,
		       "real", "effective",
		       data->uid[0], data->uid[1], 
		       data->gid[0], data->gid[1]);
  status = Stdio.read_file("/proc/"+pid+"/stat");
  if(!stringp(status) || !strlen(status))
    return out;
  array stat = status / " ";
  out += sprintf("\n"
		 "<b>                            Process     In children</b>\n"
		 "<b>Page Faults (non I/O) :</b>  %10s      %10s\n"
		 "<b>Page Faults (I/O)     :</b>  %10s      %10s\n",
		 stat[9], stat[10], stat[11], stat[12]);
		 
  return out;
}

mixed page_1(object id, object mc)
{
  int pid = (int)id->variables->pid || caudium->roxenpid || caudium->startpid;
  string environ =
    Array.map(sort((Stdio.read_file("/proc/"+pid+"/environ") || "") / "\0"),
	      format_env_line, pid)*"";
  if(strlen(environ))
    environ = sprintf("<table width=100%% cellspacing=0 cellpadding=1>\n <tr align=left>\n  <th>Variable</th>\n  "
		      "<th>Value</th>\n </tr>\n%s"
		      "</table>", environ);
  return ("<h2>Process environment for "+pid+"</h2><h3>Cmdline: "+
	  replace(Stdio.read_file("/proc/"+pid+"/cmdline") || "???",
		  "\0", " ") +"</h3>" +
	  environ);
}

mixed page_0(object id, object mc)
{
  object p = Privs("Process status");
  int pid = (int)id->variables->pid || caudium->roxenpid || caudium->startpid;
 
  string tree = Array.map((Array.map(popen("/usr/bin/pstree -pa "+pid)/"\n" -
				     ({""}), format_proc_line, pid)*"") / "\n",
			  lambda(string l) {
			    l = reverse(l);
			    sscanf(l, "%*[ ]%s", l);
			    return reverse(l);
			  })*"\n";
  
  return ("<h2>Process Tree for "+pid+"</h2><pre>\n"+
	  tree+"</pre>"+
	  (caudium->euid_egid_lock ? 
	   "<p><i>Please note that when using threads on Linux, each "
	   "thread is more or less<br> a separate process, with the exception "
	   "that they share all their memory.</b>" : "")+
	  "<h3>Misc status for "+pid
	  +"</h3><pre>"+get_status(pid)+"</pre>");
}

mixed handle(object id) { return wizard_for(id,0); }









