/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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
 * The Manual Tag
 *
 * Fredrik Noring
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER;
constant module_name = "Manual tag";
constant module_doc  = "This tag is the manual librarian.<p>"
      "See <tt>&lt;manual help&gt</tt> for more information.\n\n<p>"+doc();
constant module_unique = 1;

static private int loaded;

static private string doc()
{
  return !loaded?"":replace(Stdio.read_bytes("modules/tags/doc/manual")||"",
			    ({ "{", "}" }), ({ "&lt;", "&gt;" }));
}

array file_finder(string entry, int lvl)
{
  array files = ({}), fs = file_stat(entry);
  if(!fs || lvl > 500)
    return files;
  switch(fs[1]) {
  case -2:
  case -3:
    foreach(get_dir(entry)||({}), string dir)
      files += file_finder(combine_path(entry, dir), ++lvl);
    break;
  default:
    files = ({ entry });
  }
  return files;
}

array module_files()
{
  array files = ({});
  foreach(caudium->query("ModuleDirs"), string dir)
    files += file_finder(dir, 0);
  return files;
}

string read_manual(string file)
{
  return !loaded?"":replace(Stdio.read_bytes(file)||"<b>File not found.</b>",
			    ({ "{", "}" }), ({ "&lt;", "&gt;" }));
}

string tag_manual(string tag_name, mapping args, object id,
		  object file, mapping defines)
{
  array a = glob("*manual.html", module_files());
  mapping files = ([]);
  foreach(a, string m)
    sscanf((m/"/")[-1], "%s.manual.html", files[m]);
  mapping manuals = mkmapping(values(files), indices(files));

  if(!sizeof(args) || args["help"])
    return "<h3>Manual</h3>This tag is the manual librarian.<p>";

  if(args["list-manuals"])
    return (sizeof(manuals)?sort(indices(manuals))*"<br>":
	    "<b>No manuals found.</b>");

  string man = indices(args)[0];
  if(sizeof(man) && manuals[man])
    return read_manual(manuals[man]);
  return ("<b>Manual ``"+man+"'' not found.</b> "
	  "See <tt>&lt;manual help&gt</tt> for more information.<p>");
}

array register_module()
{
  return ({
    MODULE_PARSER,
      "Manual tag",
      "This tag is the manual librarian.<p>"
      "See <tt>&lt;manual help&gt</tt> for more information.\n\n<p>"+doc(),
      0, 1 });
}

void start(int num, object configuration)
{
  loaded = 1;
}

mapping query_tag_callers()
{
  return ([ "manual":tag_manual, ]);
}
