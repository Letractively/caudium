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
 * $Id$
 */
/*
 * Based on :
 * Version: servertemplates.pike 0.4 1999/05/15 20:41 Turbo Fredriksson <turbo@nocrew.org>
 *
 */

#include <roxen.h>
#include <config.h>

inherit "wizard";

constant name= "Maintenance//Create your own server template...";
constant doc = "Lets you create custom server templates by choosing modules from a list.";
constant wizard_name = "Server template creator";

mapping extract_module_info(array from)
{
  string fname;
  mapping m = ([]);
  sscanf(from[1], "%*s<b>Loaded from:</b> %s<", fname);
  m->fname = fname;
  if(fname)
    string mod = Stdio.read_bytes(fname);

  m->name = from[0];
  m->doc  = from[1];
  m->type = from[2];
  return m;
}

// ----------------------------------------------------------------------

// Welcoming page...
string page_0(object id)
{
  return ("<b>Welcome to the server template creation wizard.</b>"
	  "<p>This action will create your own server template, with "
	  "your own preferred modules.");
}

// Check modules in module path.
string page_1(object id)
{
  int num;
  string res = ("<font size=+2>All available modules.</font><p>"
		"Select the box to add the module to the list of modules to "
		"be added to the new server template<p></b>\n");
  res += "<ul>";

  // Reload module cache...
  roxen->rescan_modules();
  mapping modules = copy_value(roxen->allmodules);

  // Get name and filename of module
  mapping rm = ([]);
  foreach(indices(modules), string mod) {
    mapping m = extract_module_info(modules[mod]);
    rm[mod] = m;
  }
  modules = rm;

  // Get all modules availible...
  array tbl = ({});
  foreach(sort(indices(modules)), string m) {
    num++;
    tbl += ({ ({"<var type=checkbox name=M_"+m+">",
    		modules[m]->name,
		modules[m]->fname}) });
  }
  
  if(num)
    return res + html_table ( ({ "", "Module", "File"}), tbl );
}

// Ask for filename...
string page_2(object id)
{
  string res;
  res  = ("<b>Server template file name:</b><p>"
	  "<font size=-1>This is the file name of your template, without the ending <b>.pike</b> "
	  "extension. It will be saved as ../server_templates/<name>.pike.</font><p>"
	  "<var name=fname size=30><p>"
	  "<b>Server template name:</b><p>"
	  "<font size=-1>This is the name that the user sees when adding a new virtual server.</font><p>"
	  "<var name=tname size=30><p>"
	  "<b>Server template description:</b><p>"
	  "<font size=-1>This is the description on the add virtual server page.</font>"
	  "<var name=description type=text><p>");

  return(res);
}

// Verify action...

array get_modules(mapping vars)
{
  array todo = ({});
  filter_checkbox_variables(vars);
  foreach(sort(indices(vars)), string s)
  {
    string module;
    if(sscanf(s, "M_%s", module))
      todo += ({ module });
  }
  return todo;
}

string page_3(object id)
{
  array todo;
  string res;
  if(! id->variables->fname ) {
    id->variables->_error = "No filename selected.";
    return "<font size=+2>You have not entered any filename to save this template as.</font>";
  }
  res = "<font size=+1>Summary: These modules will be used in the new template:</font><p>\n<ul>\n";
  
  foreach(todo = get_modules(id->variables), array a)
    res += "<li> " + a[0] + "\n";

  if(sizeof(todo))
    res += "<p><font size=+1>Filename: " + id->variables->fname + "</font>\n";

  res += "</ul>";

  if(!sizeof(todo))
    res = "<font size=+1>Summary: No actions will be taken</font><p>";
    
  return res + "</ul>";
}

#define safe(x) replace(x-"\r", ({ "\"", "\n"}), ({"\\\"", "\\n"}))

string wizard_done(object id)
{
  id->variables->fname -= "/";
  id->variables->fname -= "..";
  string fname = "server_templates/" + id->variables->fname + ".pike";

  if( file_stat(fname) ) {
    id->variables->_error = "File already exists.";
    return "<font size=+2>The file " + fname + "  already exists. Please choose another file name!</font>";
  }
  werror("%s\n", safe(id->variables->description));
  object file = Stdio.File();
  object privs = Privs("Creating server template file");

  if(!file->open(fname, "wct", 0644)) {
    privs = 0;

    id->variables->_error = "Could not open file.";
    return "<font size=+2>Could not open file " + fname + "." + strerror(file->errno()) + "</font>\n";
  }
  privs = 0;

  file->write("// Template created with the server template action,\n"
	      "// originally written by Turbo Fredriksson <turbo@nocrew.org>\n\n"
	      "constant selected = 0;\n"
	      "constant name = \"" + safe(id->variables->tname) + "\";\n"
	      "constant desc = \"" + safe(id->variables->description)+ "\";\n\n"
	      "constant  modules = \({\n");
 foreach(get_modules(id->variables), string mod)
    file->write(" \"" + safe(mod) + "#0\",\n");
  file->write("});\n\n"
	      "void enable(object config)\n"
	      "{\n"
	      "  foreach(modules, string module)\n"
	      "    config->enable_module(module);\n"
	      "}\n");

  // Close the file, we are done!
  file->close();

  //  return (html_border(res+
  //		      "<form action=/Actions/>"
  //		      "<input type=hidden name=action value=reloadconfiginterface.pike>"
  //		      "<input type=hidden name=unique value="+time()+">"
  //		      "<input type=submit value=' OK '>"
  //		      "</form>",0,5));
}

// ----------------------------------------------------------------------

string handle(object id)
{
  return wizard_for(id,0);
}
