#include <module.h>

/*
 * TODO:
 * 
 * this is somewhat broken since it does not handle modules having
 * multiple instances like the filesystem module.
 *
 */

/*
123session, camas, camas_auth_ldap, camas_features, camas_formbuttons, camas_global_addressbook, camas_html, camas_images, camas_imho, camas_imhoscreens, camas_language, camas_layout_default, camas_layout_fs, camas_logger, camas_runtime_admin, camas_tags
*/

inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_PARSER | MODULE_LOCATION;
constant module_name = "MCIF";
constant module_doc  = "The Meta Configuration Interface.";
constant module_unique = 1;

#define DEFVAR(var, def, type) defvar (var, def, var, type, "undocumented variable.")

void create () {
  defvar ("location", "/conf/", "Mountpoint", TYPE_LOCATION,
	  "MCIF location.");

  DEFVAR ("show_builtins", 1, TYPE_FLAG);
  DEFVAR ("modules", ({ "" }), TYPE_STRING_LIST);
}

string status () {
  string res = "";
  return res;
}

void|string check_variable (string var, mixed value) {
  switch (var) {
    
  break;
  }
}
    
void start (int num, object conf) {

}

void stop () {

}

string query_location () { return QUERY (location); }

array get_modules_names (object id) {
  array a = sort (indices (id->conf->modules) & QUERY(modules)) - ({ "" });
  //  write (sprintf ("a= %O\n", a));
  return a;
}

array get_module_variables (object id, string module) {
  object o = id->conf->modules[module]->master;
  
  array ret = ({ });
  mapping m = ([ ]);

  if (o) {
    write ("master module: " + module + "\n");
    m = o->variables;

    if (m)
      foreach (indices (m), string varname)
	ret |= ({ varname }); //+ "#0" });
  }
  else {
    write ("module with copies: " + module + "\n");
    
    foreach (indices (id->conf->modules[module]->copies), int c) {
      //m = id->conf->modules[module]->copies[c]->variables;
      
      if (m)
	foreach (indices (m), string varname)
	  ret |= ({ varname + "#" + (string)c });
    }
  }

  //  write (sprintf ("variables= %O\n", ret));

  return ret;
}

int _show_var (mixed stuff) {
  //  write (sprintf ("stuff= %O\n", stuff));
  if (stuff && sizeof (stuff) >= 6) {
    if (functionp (stuff[VAR_CONFIGURABLE])) {
      return !(stuff[VAR_CONFIGURABLE]) ();
      function f = (function)stuff[VAR_CONFIGURABLE];
      return !f ();
      }
  }
  return 1;
}

int show_variable (object id, string module, string variable) {
  if ((variable[0] == '_') && !QUERY (show_builtins))
    return 0;

  mixed stuff;

  if (!id->conf->modules[module]->master) {
    array foo = variable / "#"; // ({ variable_name, module_copy })
    write (sprintf ("foo= %O\n", foo));
    stuff = id->conf->modules[module]->copies[foo[1]]->variables[foo[0]];
  }
  else {
    stuff = id->conf->modules[module]->master->variables[variable];
  }

  return _show_var (stuff);
}

string field_text_field (object id, string module, string variable) {
  string res = "";

  mixed stuff = id->conf->modules[module]->master->variables[variable];

  res += "<br><textarea name=\"" + module + "." + variable + "\" cols=\"50\" rows=\"10\">";
  res += html_encode_string (stuff[VAR_VALUE]) + "</textarea>";

  if (id->prestate && id->prestate->doc)
    res += "<br><i>" + stuff[VAR_DOC_STR] + "</i>";

  return res;
}

string field_string (object id, string module, string variable) {
  string res = "";

  mixed stuff = id->conf->modules[module]->master->variables[variable];

  res += "<input type=\"text\" name=\"" + module + "." + variable + "\"";
  res += " value=\"" + html_encode_string ((string)stuff[VAR_VALUE]) + "\">";

  if (id->prestate && id->prestate->doc)
    res += "<br><i>" + stuff[VAR_DOC_STR] + "</i>";

  return res;
}

string field_flag (object id, string module, string variable) {
  string res = "";

  mixed stuff = id->conf->modules[module]->master->variables[variable];

  res += "<select name=\"" + module + "." + variable + "\">";
  res += "<option value=\"1\"";
  res += (stuff[VAR_VALUE]) ? " selected" : "";
  res += ">Yes</option>";
  res += "<option value=\"0\"";
  res += (stuff[VAR_VALUE]) ? "" : " selected";
  res += ">No</option>";
  res += "</select>";

  if (id->prestate && id->prestate->doc)
    res += "<br><i>" + stuff[VAR_DOC_STR] + "</i>";

  return res;
}

string field_string_list (object id, string module, string variable) {
  string res = "";

  mixed stuff = id->conf->modules[module]->master->variables[variable];

  if (stuff[VAR_MISC]) {
    res += "<select name=\"" + module + "." + variable + "\">";

    foreach (stuff[VAR_MISC], string val) {
      res += "<option value=\"" + val + "\"";
      res += (val == stuff[VAR_VALUE]) ? " selected" : "";
      res += ">";
      res += val + "</option>";
    }
    
    res += "</select>";
  }

  if (id->prestate && id->prestate->doc)
    res += "<br><i>" + stuff[VAR_DOC_STR] + "</i>";

  return res;
}

mapping mcif (object id) {
  if (!id) {
    write ("Aarrrgh!!!\n");
    return 0;
  }
  
  string res = "";

  res += "<html>\n<head>\n<title>Title</title>\n</head>\n";
  res += "<body bgcolor=\"wheat\">\n";

  res += "<form action=\"set_conf\" method=\"post\" name=\"mcif\">\n";

  mapping data = ([ ]);

  array a = get_modules_names (id);

  foreach (a, string module) {
    data += ([ module: ([ ]) ]);
  
    foreach (sort (get_module_variables (id, module)), string var) {
      if (show_variable (id, module, var)) {
	object m = id->conf->modules[module]->master->variables[var];
	
	string lname = m[VAR_NAME];
	string section, vname;
	if (has_value (lname, ":")) {
	  array tmp = lname / ":";
	  section = tmp[0];
	  vname = tmp[1];
	}
	else {
	  section = "__misc";
	  vname = lname;
	}
	
	if (!data[module][section])
	  data[module][section] = ([ ]);

	//	write (sprintf ("data= %O\n", m));

	switch (m[VAR_TYPE]) {
	  
	case TYPE_TEXT_FIELD:
	  data[module][section] += ([ var: ({ vname, field_text_field (id, module, var) }) ]);
	  break;
	  
	case TYPE_STRING:
	case TYPE_INT:
	  data[module][section] += ([ var: ({ vname, field_string (id, module, var) }) ]);
	  break;
	  
	case TYPE_STRING_LIST:
	  data[module][section] += ([ var: ({ vname, field_string_list (id, module, var) }) ]);
	  break;
	  
	case TYPE_FLAG:
	  data[module][section] += ([ var: ({ vname, field_flag (id, module, var) }) ]);
	  break;
	  
	default:
	  
	  break;
	}
      }
    }
  }

  //#if 0
  foreach (sort (indices (data)), string module) {
    res += "<h1>" + id->conf->modules[module]->name + "</h1>\n";

    mapping stuff = data[module];
    //	write (sprintf ("stuff= %O\n", stuff));
    foreach (sort (indices (stuff)), string section) {
      string sname = (section == "__misc") ? "General" : section;
      res += "<table width=\"100%\" border=\"1\">\n";
      res += "<tr><th colspan=\"2\">" + sname + "</th></tr>\n";

      mapping stuff2 = data[module][section];
      //	write (sprintf ("stuff2= %O\n", stuff2));
      foreach (sort (indices (stuff2)), string f) {
	res += "<tr>\n";
	res += "<td width=\"50%\">" + stuff2[f][0] + "</td>\n";
	if (stuff2 && stuff2[f] && stuff2[f][1])
	  res += "<td>" + stuff2[f][1] + "</td>\n";
	else
	  res += "<td>&nbsp;</td>";
	res += "</tr>\n";
      }

      res += "</table>\n\n";
    }
  }
  //#endif

  res += "<input type=\"submit\" value=\"Save !\">\n";
  res += "</form>\n";

  res += "</body>\n";

  res += "</html>";

  id->misc->cacheable = 0;
  //id->misc->is_dynamic = 1;
  
  return http_rxml_answer (res, id);
}

mapping set_conf (object id) {
  //  write (sprintf ("set_conf: variables= %O\n", id->variables));

  foreach (indices (id->variables), string v) {
    array a = v / "."; // ({ module_name, variable_name });
    if (sizeof (a) == 2) {
      mapping stuff = id->conf->modules[a[0]]->master->variables[a[1]];
      
      switch (stuff[VAR_TYPE]) {
	
      case TYPE_STRING:
      case TYPE_TEXT_FIELD:
      case TYPE_STRING_LIST:
	stuff[VAR_VALUE] = id->variables[v];
	break;
	
      case TYPE_INT:
      case TYPE_FLAG:
	stuff[VAR_VALUE] = (int)id->variables[v];
	break;
	
      default:
	break;
      }
    }
  }
  
  id->misc->cacheable = 0;
  id->misc->is_dynamic = 1;

  id->conf->save ();

  return http_redirect (id->referrer);
}

void test (void | int i) {
  /* why the hell did i add this ? */
  /* should use zero_p (i) or whatever btw */
  if (zero_type (i)) {
    write ("void call\n");
  }
  else
    write ("value: " + i + "\n");
}

mapping find_file (string file, object id) {
  test (1);
  test (0);
  test ();

  switch (file) {

  case "": return mcif (id); break;
  case "set_conf": return set_conf (id); break;
    
  default: return 0;
  }
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: location
//! MCIF location.
//!  type: TYPE_LOCATION
//!  name: Mountpoint
//
