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

constant name= "Maintenance//Create you own server template...";
constant doc = "Puts togheter you own server templates.";
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
	  "your own prefered modules.");
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
  res  = "<font size=+1>Where should we save the new template?</font><br>";
  res += ("<font size=-1>Enter it without the <b>.pike</b> extension. It will be saved in the "
	  "directory<br>.../server_templates/<name>.pike.</font><p>"
	  "File name:<br><var name=fname size=30><p>");
  res += ("<font size=+1>What do you want to call the server template?</font><br>"
	  "Template name:<br><var name=tname size=30><p>");
  res += ("<font size=+1>Any description for the server template?</font><br>"
	  "Template description:<br><var name=description size=30><p>");

  return(res);
}

// Verify action...
array todo = ({});
string page_3(object id)
{
  if(! id->variables->fname ) {
    id->variables->_error = "No filename selected.";
    return "<font size=+2>You have not entered any filename to save this template as.</font>";
  }

  filter_checkbox_variables(id->variables);
  foreach(sort(indices(id->variables)), string s)
  {
    string module;
    if(sscanf(s, "M_%s", module))
      todo += ({ ({module}) });
  }

  string res = "<font size=+1>Summary: These modules will be used in the new template:</font><p>\n<ul>\n";

  foreach(todo, array a)
    res += "<li> " + a[0] + "\n";

  if(sizeof(todo)!=0)
    res += "<p><font size=+1>Filename: " + id->variables->fname + "</font>\n";

  res += "</ul>";

  if(sizeof(todo)==0)
    res = "<font size=+1>Summary: No actions will be taken</font><p>";
    
  return res + "</ul>";
}

string wizard_done(object id)
{
  string fname = "server_templates/" + id->variables->fname + ".pike";

  if( file_stat(fname) ) {
    id->variables->_error = "File already exists.";
    return "<font size=+2>Filename " + fname + " does already exists. Please choose another name!</font>";
  }

  object file = Stdio.File();
  object privs = Privs("Creating server template file");

  if(!file->open(fname, "wct", 0644)) {
    privs = 0;

    id->variables->_error = "Could not open file.";
    return "<font size=+2>Could not open file " + fname + "." + strerror(file->errno()) + "</font>\n";
  }
  privs = 0;

  file->write("/* Template created with the 'servertemplates.pike',\n");
  file->write(" * by Turbo Fredriksson <turbo@nocrew.org>\n");
  file->write(" */\n\n");

  file->write("constant selected = 0;\n");
  file->write("constant name = \"" + id->variables->tname + "\";\n");
  file->write("constant desc = \"" + id->variables->description + "\";\n\n");

  file->write("constant  modules = \({\n");
  foreach(todo, array a)
    file->write(" \"" + a[0] + "#0\",\n");
  file->write("});\n\n");

  file->write("void enable(object config)\n");
  file->write("{\n");
  file->write("  foreach(modules, string module)\n");
  file->write("    config->enable_module(module);\n");
  file->write("}\n");

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
