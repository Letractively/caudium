#include <module.h>

// Faster debugging (thanks kiwi :) )
#define CAMAS_DEBUG
#ifdef CAMAS_DEBUG
# define DEBUG(X)	if(QUERY(debug)) werror("CAMAS TAGS: "+X+"\n");
#else
# define DEBUG(X)
#endif

inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Oliv3's source module";
constant module_doc  = "Show the sources."

  " <font color=\"#ff0000\"><b><br />  <u>WARNING</u>: this module *IS*"
  " *NOT* a safe module, as it shows visitors the RXML source of your pages."
  " Use at your own risks...</b></font>";

constant module_unique = 1;

#define DEFVAR(var, def, type) defvar (var, def, var, type, "undocumented variable.")

#define LT "&mylt;"
#define GT "&mygt;"

// ==============================================================================

constant html4_containers = ({ 
  "a", "abbr", "acronym", "address", "applet", "area", "b", "base", "bdo", 
  "big", "blockquote", "button", "caption", "center", "cite", "code", 
  "colgroup", "dd", "del", "dfn", "dir", "dl", "dt", "em", "fieldset", 
  "form", "font", "frameset", "h1", "h2", "h3", "h4", "h5", "h6",
  "i", "iframe", "ins", "isindex", "kbd", "label",
  "legend", "li", "map", "menu", "noframes", "noscript", "object",
  "ol", "optgroup", "option", "p", "pre", "q", "s", "samp", "script", "select",
  "small", "strike", "strong", "sub", "sup", "table", "tbody", "td",
  "textarea", "tfoot", "th", "thead", "tr", "tt", "u", "ul", "var"
});

constant html4_tags = ({
  "area", "base", "basefont", "br", "col", "hr", "frame", "img", "input",
  "meta", "param"
});

constant html4_css = ({
  "div", "span", "style", /* not HTML 4.01: */ "layer"
});

constant html4_c = html4_containers + html4_css + ({ "html", "head", "body", "title" });
constant html4_t = html4_tags;

// ==============================================================================

void create () {
  defvar ("xml_style", 0, "XML-like output", TYPE_FLAG, "if yes, add \" /\""
	  " at the end of tags.");
  
  defvar ("prolog", "<hr /><h1><font color=\"blue\">The source...</font></h1><pre>",
	  "Prolog", TYPE_STRING,
	  "The prolog. <b>Can't contain RXML</b>.");
  
  defvar ("epilog", "</pre>", "Epilog", TYPE_STRING,
	  "The epilog. <b>Can't contain RXML</b>.");

  DEFVAR ("attr_color", "violet", TYPE_STRING);
  DEFVAR ("arg_color", "#ddffdd", TYPE_STRING);

  DEFVAR ("base_url", "http://caudium.net/cdocs/modules/server", TYPE_STRING);
}

#if 0 // unused for now
void start (int num, object conf) {

}

void stop () {

}
#endif

object find_module_by_container (string container) {
  foreach (indices (my_configuration ()->modules), string s) {
    mapping m = my_configuration ()->modules[s];
    if (m->type & MODULE_PARSER) {
      object mod = my_configuration ()->find_module (m->sname);
      if (mod->query_container_callers
	  && has_value (indices (mod->query_container_callers ()), container))
	return mod;
    }
  }
  return 0;
}

object find_module_by_tag (string tag) {
  foreach (indices (my_configuration ()->modules), string s) {
    mapping m = my_configuration ()->modules[s];
    if (m->type & MODULE_PARSER) {
      object mod = my_configuration ()->find_module (m->sname);
      if (mod->query_tag_callers
	  && has_value (indices (mod->query_tag_callers ()), tag))
	return mod;
    }
  }
  return 0;
}

string my_make_attributes (mapping m, int highlight) {
  string ret = "";
  foreach (sort (indices (m)), string attr) {
    if (_highlight) { // oliv3 FIXME
      ret += " " LT "font color=\"" + QUERY (attr_color);
      ret += "\"" GT + attr;
      ret += LT "/font" GT;
    }
    else
      ret += " \"" + attr + "\"";

    ret += "=";

    if (_highlight) {
      ret += "\"" LT "font color=\"" + QUERY (arg_color);
      ret += "\"" GT + m[attr];
      ret += LT "/font" GT "\"";
    }
    else
      ret += "\"" + m[attr] + "\"";
      
  }
  return ret;

  string q = make_tag_attributes (m);

  return (strlen(q) ? " " + q : "");
}

string do_container (object parser, mapping m, string content, object id,
		     int highlight, int doc) {
  string ret = "";
  string cname = parser->tag_name ();

  ret += LT "b" GT "&lt;";
  if (_doc) { // oliv3 FIXME
    object mod = find_module_by_container (cname);
    if (mod) {
      string filename = caudium->filename (mod);
      //write("insert container doc from filename: [" + filename + "]\n");
	if (filename && !search (filename, "modules/")) {
	  string url = QUERY (base_url) + "/" + filename + ".xml#" + cname;
	  ret += LT "a target=\"new\" href=\"" + url + "\"" GT;
	  ret += cname;
	  ret += LT "/a" GT;
	}
	else
	  ret += cname;
    }
    else
      ret += cname;
  }
  else
    ret += cname;
  ret += my_make_attributes (m, highlight);
  ret += "&gt;" LT "/b" GT;
  ret += content;
  ret += LT "b" GT "&lt;/" + cname + "&gt;" LT "/b" GT;

  return ret;
}

string do_tag (object parser, mapping m, object id, int highlight, int doc) {
  string ret = "";
  string tname = parser->tag_name ();

  ret += LT "b" GT "&lt;";
  if (_doc) { // oliv3 FIXME
    object mod = find_module_by_tag (tname);
    if (mod) {
      string filename = caudium->filename (mod);
      //write("insert tag doc from filename: [" + filename + "]\n");
	if (filename && !search (filename, "modules/")) {
	  string url = QUERY (base_url) + "/" + filename + ".xml#" + tname;
	  ret += LT "a target=\"new\" href=\"" + url + "\"" GT;
	  ret += tname;
	  ret += LT "/a" GT;
	}
	else
	  ret += tname;
    }
    else
      ret += tname;
  }
  else
    ret += tname;

  ret += my_make_attributes (m, highlight);
  if (QUERY (xml_style)) ret += " /";
  ret += "&gt;" LT "/b" GT;

  return ret;
}

array(string) last_dirs=0, last_dirs_expand;

string load_from_dirs2 (array dirs, string f, object conf)
{
  string dir;
  object o;
  if (!equal(dirs,last_dirs))
  {
    last_dirs_expand = ({});
    foreach(dirs, dir)
      last_dirs_expand += caudium->expand_dir(dir);
    last_dirs = dirs;
  }

  foreach (last_dirs_expand, dir)
    if (file_stat(dir+f+".pike")) return dir+f+".pike";
  
  return 0;
}

mapping containers, tags;

object prepare_highlight (object id) {
  containers = ([ ]);
  tags = ([ ]);

  foreach (indices (id->conf->modules), string s) {
    mapping m = id->conf->modules[s];
    if (m->type & MODULE_PARSER) {
      //write(sprintf("found module: %O\n", m));
      object mod = id->conf->find_module (m->sname);
      //write ("name = " + caudium->filename(mod) + "\n");

      if (mod->query_tag_callers)
	foreach (indices (mod->query_tag_callers ()), string t)
	  tags += ([ t : do_tag ]);

      if (mod->query_container_callers)
	foreach (indices (mod->query_container_callers ()), string c)
	  containers += ([ c : do_container ]);
    }
  }
  
  foreach (html4_c, string c)
    containers += ([ c : do_container ]);

  foreach (html4_t, string t)
    tags += ([ t : do_tag ]);

  return id;
}

int _highlight = 0; // arg! ugly but set_extra doesn't work yet :( [ my fault ]
int _doc = 0; // as well

string do_highlight (string s, int highlight, int doc) {
  object p = Parser.HTML ();

  p->case_insensitive_tag (1);
  p->ignore_unknown (1);

  p->add_containers (containers);
  p->add_tags (tags);

  p->set_extra (highlight);
  // oliv3 FIXME
  // p->set_extra (doc);

  _highlight = highlight;
  _doc = doc;

  string ret = p->finish (s)->read ();
  destruct (p);

  // oliv3 FIXME et s'il y a '&mygt;' dans la page ? -> rajouter un
  // replace &mylt; &_mylt; :)
  ret = replace (ret, ({ LT, GT }), ({ "<", ">" }));
  
  return ret;
}

mapping filter (mapping result, object id) {
  if (!result || !result->type
      || search (result->type, "text/") || !stringp (result->data)
      || id->misc->source_filtered++)
    return 0;
  
  if (!id->prestate->source)
    return 0;

  if (id->realfile) {  
    string ret = result->data;

    ret += QUERY (prolog);
    
    string file = Stdio.read_bytes (id->realfile);
    if (file) {
      id = prepare_highlight (id); // oliv3 FIXME wrong name !!!
      file = do_highlight (file,
			   id->prestate->highlight,
			   id->prestate->doc);
      
      // ret += html_encode_string (file) + QUERY (epilog);
      ret += file + QUERY (epilog);
    }
    else {
      ret += "<h1><font color=red>Could not open file for reading...</font></h1>";
    }

    return http_string_answer (ret);
  }
  else
    return 0;
}

