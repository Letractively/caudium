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

void run(object env)
{
  object f = Stdio.File();
  array(string) oracles = ({});
  string sid, home, bootstart;
  write("Checking for Oracle...");
  if((sid = getenv("ORACLE_SID")) && (home = getenv("ORACLE_HOME")))
    oracles += ({ ({ sid, home }) });
  foreach(({"/var/opt/oracle/oratab", "/etc/oratab"}), string oratab)
    if(f->open(oratab, "r"))
    {
      foreach(f->read()/"\n", string line)
	if(sizeof(line) && line[0]!='#' &&
	   3==sscanf(line, "%s:%s:%s", sid, home, bootstart) &&
	   Array.search_array(oracles, equal, ({ sid, home })))
	  oracles += ({ ({ sid, home }) });
      f->close();
    }
  if(!sizeof(oracles) &&
     (sid=env->get("ORACLE_SID")) && (home=env->get("ORACLE_HOME")))
    oracles += ({ ({ sid, home }) });
  if(!sizeof(oracles)) {
    write("no\n");
    return;
  }
  write("\n");
  while(sizeof(oracles)>1) {
    write("Multiple Oracle instances found.  Please select your"
	  " preffered one:\n");
    foreach(indices(oracles), int i)
      write(sprintf("%2d) %s (in %s)\n", i+1, @oracles[i]));
    write("Enter preference (or 0 to skip this step) > ");
    string in = gets();
    int x;
    if(1==sscanf(in, "%d", x) && x>=0 && x<=sizeof(oracles))
      if(x==0)
	return;
      else
	oracles = ({ oracles[x-1] });
    else
      write("Invalid selection.\n");
  }
  write(sprintf("  => ORACLE_SID=%s, ORACLE_HOME=%s\n", @oracles[0]));
  env->set("ORACLE_SID", oracles[0][0]);
  env->set("ORACLE_HOME", oracles[0][1]);
  env->append("LD_LIBRARY_PATH", oracles[0][1]+"/lib");
}
