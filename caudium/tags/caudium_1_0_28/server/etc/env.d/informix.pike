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
  string infdir;
  write("Checking for Informix...");
  if(!(infdir=getenv("INFORMIXDIR")))
    foreach(({"/opt/informix","/usr/opt/informix","/usr/informix",
	      "/usr/local/informix","/mp/informix"}), string dir)
      if(file_stat(combine_path(dir, "bin/oninit"))) {
	infdir = dir;
	break;
      }
  if(!infdir)
    infdir = env->get("INFORMIXDIR");
  if(!infdir) {
    write("no\n");
    return;
  }
  write("\n  => INFORMIXDIR="+infdir+"\n");
  env->set("INFORMIXDIR", infdir);
  env->append("LD_LIBRARY_PATH", infdir+"/cli/dlls:"+infdir+"/lib/esql:"+
	      infdir+"/lib");
}
