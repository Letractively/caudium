/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
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
 * $Id$
 */

/*
 *
 * The gFaq module and the accompanying code is 
 * Copyright © 2002 Davies, Inc
 *
 * This code is released under the LGPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *  Marek Habersack <grendel@caudium.net>
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#include <caudium.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_LOCATION | MODULE_PARSER;
constant module_name = "gFAQ module";
constant module_doc  = "Module implementing a FAQ filesystem.";
constant module_unique = 0;

static private string css_uri;

#define FAQPAGE_MAGIC 0xDEADBEEF
#define FAQEDIT_MAGIC 0xFEEDBEEF
#define FAQSUGGEST_MAGIC 0xBADBEEF

#define LOCATION_SAVE        "actions/save"
#define LOCATION_SUGGEST     "actions/suggest"
#define LOCATION_NEWSECTION  "actions/newsection"
#define LOCATION_CSS         "css/faq.css"

// FAQ entry mapping format. Such mapping(s) is(are) retrieved/sent to the
// storage provider. It is meant to make this module storage-independent
// although a storage module can put its own fields in the mapping, just
// the same as the access control module.
//
//   "contents" mapping
//        A mapping with the entry contents:
//
//          "title"    string
//             The entry title
//
//          "text"     string
//             The entry contents
//
//   "path"     string
//      Path that leads to this entry from the top in the following format:
//      /1/2/3/4
//
//   "level"    int
//      FAQ level on which the entry is found (path length - 1)
//
//   "num"      int
//      Entry number on its level
//
//   "is_qa"    int
//      If != 0 then the entry is a leaf, that is it represents a
//      Question/Answer pair. Otherwise the entry is a section which
//      contains Q&As.
//            
//   "see_also" array(string)
//      Array containing paths of related entries.
//
//   "groups" array(string)
//      Groups of users which can view this question. Eeach index is a
//      regexp.
//
//   "users" array(string)
//      Users which can view this question. Eeach index is a regexp.
//
//   "annotations"   array(mapping(string:string))
//      Entry annotations. An array of mappings in the following format:
//
//          "who"     string
//             Name/login of the user who added the annotation/note
//
//          "text"    string
//             Text of the annotation
//
void create()
{
  /* general */
  defvar("faq_name", "FAQ", "General: FAQ Name", TYPE_STRING,
         "Give this instance some name. It can be used by all the provider "
         "modules to tell various FAQs apart.");
  
  /* paths */
  defvar("mountpoint", "/FAQ/", "Paths: Mount point", TYPE_LOCATION, 
         "This is where the module will be inserted in the "+
         "namespace of your server.");

  /* providers */
  defvar("prov_storage", "faq_storage", "Providers: Storage", TYPE_STRING,
         "Name of the provider that implements storage for this module. Note "
         "that the storage providers usually affix some string to the value of "
         "this setting. For example the PostgreSQL module appends <em>_pg</em>.");
  defvar("prov_access", "faq_access", "Providers: Access Control", TYPE_STRING,
         "Name of the provider that implements access control for this module. "
         "FAQ Access control is different to the mountpoint access control - it "
         "determines whether a user may/may not edit/remove/add FAQ entries.");
  defvar("prov_css", "faq_css", "Providers: CSS provider", TYPE_STRING,
         "A module that provides CSS stylesheets for this module. If not found, an "
         "internal CSS will be used.");
  defvar("prov_ui", "faq_ui", "Providers: User Interface", TYPE_STRING,
         "This is the name of the provider module that can provide elements of "
         "the application UI. Currently defined elements that can be augmented by "
         "the provider are listed below. See the documentation for more information."
         "<br />"
         "<ul>"
         "<li><strong>navbar</strong></li>"
         "</ul><br />");
  
  /* HTML & CSS */
  defvar("html_charset", "iso-8859-1", "HTML and CSS: HTML Charset", TYPE_STRING,
         "The character set of the generated HTML code.");
  defvar("css_uri", "", "HTML and CSS: Stylesheet URI", TYPE_STRING,
         "URI of the CSS stylesheet to use with the module. If left empty, an "
         "internal stylesheet will be used.");
  defvar("html_title", "FAQ", "HTML and CSS: Page Title", TYPE_STRING,
         "Title of the HTML pages generated by this module.");

  /* Layouts */
  defvar("layout_location", "NONE", "Layouts: Location", TYPE_DIR,
         "Directory (in the physical filesystem) where the FAQ layout files can "
         "be found.");
  defvar("layout_default", "default", "Layouts: Default Layout", TYPE_STRING,
         "Name of the default layout to use. A file named LAYOUTNAME.rxml must exist "
         "in the layouts directory.");
}

void start(int cnt, object conf)
{
  module_dependencies(conf, ({"gsession", "gbutton", "graphic_text"}));

  if (QUERY(css_uri) != "")
    css_uri = QUERY(css_uri);
  else {
    object css_prov = conf->get_provider(QUERY(prov_css));
    mixed  error;
    
    if (css_prov && objectp(css_prov) && functionp(css_prov->get_css_uri)) {
      error = catch {
        css_uri = css_prov->get_css_uri(QUERY(mountpoint));
      };

      if (error)
        css_uri = QUERY(mountpoint) + LOCATION_CSS;
    } else
      css_uri = QUERY(mountpoint) + LOCATION_CSS;
  }
}

string query_location()
{
  return QUERY(mountpoint);
}

string status()
{
  return "Mounted on " + QUERY(mountpoint);
}

mixed find_file(string f, object id)
{
  array(int)       faqpath;
  int              parts;
  string           fmt, myfile = f;
  mixed            err;

  report_notice("find_file(%O,...)\n", f);
  
  switch(myfile) {
      case LOCATION_CSS:
        return send_faq_css(id);

      case LOCATION_SAVE:
        return save_edit_data(id);
        
      case "":
        myfile = "0";
        /* fall-through */
        
      default:
        parts = String.count(f, "/");
        break;
  }

  if (parts)
    fmt = "%d/" * parts;
  else
    fmt = "%d";

  if (myfile[-1] != '/') {
    parts++;
    fmt += "%d";
  }
  
  faqpath = array_sscanf(myfile, fmt);
  if (!faqpath || !arrayp(faqpath) || sizeof(faqpath) != parts)
    return Caudium.HTTP.error_answer(id);

  /* set up the environment */
  if (!id->variables)
    id->variables = ([]);

  string mp = QUERY(mountpoint);
  if (mp[-1] != '/')
    mp += "/";
  if (mp[0] != '/')
    mp = "/" + mp;

  string questnum = sprintf("%{%d.%}", faqpath);
  if (questnum && questnum[-1] == '.')
    questnum = questnum[0..(strlen(questnum) - 2)];
  
  id->variables->curpath = "/" + myfile;
  id->variables->curquestionnum = questnum;  
  id->variables->cursectionnum = "0";

  err = catch {
    id->variables->cursectiontitle = id->misc->session_variables->gfaq->last_section_title;
    id->variables->cursectionnum = id->misc->session_variables->gfaq->last_section_num;
  };
  
  if (err || !id->variables->cursectiontitle) {
    if (id->variables->curquestionnum == "0") {
      id->variables->cursectiontitle = "Index";
      id->variables->cursectionnum = "0";
    } else
      id->variables->cursectiontitle = "unknown";
  }
  
  id->variables->faqtitle = QUERY(faq_name);
  id->variables->baseurl = mp;
  id->variables->editurl = "/(edit)" + mp + myfile;
  id->variables->suggesturl = "/(suggest)" + mp + myfile;
  id->variables->indexurl = mp + "0/";

  id->misc->_faqpath = "/" + myfile;
  
  if (id->prestate->edit)
    id->variables->faqmode = "edit";
  else if (id->prestate->suggest)
    id->variables->faqmode = "suggest";
  else
    id->variables->faqmode = "view";
  
  /* try to find the current layout */
  object  lf;
  mixed   error;
  string  fname;

  fname = QUERY(layout_location) + "/" + QUERY(layout_default) + ".rxml";
  while(1) {
    error = catch {
      lf = Stdio.File(fname, "r");
    };

    if ((error || !lf) && QUERY(layout_default) != "default")
      fname = QUERY(layout_location) + "/" + "default.rxml";
    else
      break;
  }

  if (!lf || error) {
    report_error("gFAQ: the layout file not found.\n");
    return Caudium.HTTP.error_answer(id);
  }

  string lfile = lf->read();
  lf->close();

  // see cont_faqpage for explanation why we set this down here
  id->misc->faq_inpage = 0;
  id->misc->faq_inedit = 0;
  id->misc->faq_insuggest = 0;
  
  string    lparsed = parse_rxml(lfile, id);
  mapping   meta = ([]);

  if (id->misc->faq_module_navbar_contents)
    lparsed += id->misc->faq_module_navbar_contents;
  
  meta["one"] = ([
    "http-equiv" : "Content-Type",
    "content" : sprintf("text/html; charset=%s", QUERY(html_charset))
  ]);
  
  meta["two"] = ([
    "name" : "Generated",
    "content" : "Caudium WebServer"
  ]);

  string stitle = sprintf("%s: %s %s", QUERY(html_title),
                          id->variables->cursectionnum == "0" ? "" : id->variables->cursectionnum + ". ",
                          id->variables->cursectiontitle);
  
  return Caudium.HTTP.htmldoc_answer(lparsed, stitle, meta, css_uri);
}

// This is our default CSS
static mapping default_css_desc = ([
  "body" : ([
    "background-color" : "#EEEEEE",
    "font-family" : "Helvetica, Arial, sans-serif",
    "font-size" : "10pt"
  ]),
  
  "div.navbar" : ([
    "margin-bottom" : "1em",
    "border-bottom-width" : "2px",
    "border-bottom-color" : "#FF0000"
  ]),

  "div.faqentrytitle" : ([
    "margin-bottom" : "5px",
    "font-weight" : "bold",
    "background-color" : "#000066",
    "color" : "#EEEEEE",
    "width" : "70%",
    "padding-left" : "5px",
    "padding-right" : "-5px"
  ]),

  "div.faqentrytitle a" : ([
    "font-weight" : "bold",
    "text-decoration" : "none",
    "color" : "#EEDFCC"
  ]),

  "div.faqentrytitle a:hover" : ([
    "font-weight" : "bold",
    "text-decoration" : "none",
    "color" : "#FFFF00"
  ]),
  
  "div.faqentrybody" : ([
    "background-color" : "#CCCCCC",
    "font-style" : "italic",
    "width" : "70%",
    "margin-bottom" : "1em",
    "margin-left" : "2px",
    "padding-left" : "3x"
  ]),

  "div.faqpath" : ([
    "margin-bottom" : "10px",
    "margin-top" : "5px",
    "font-family" : "andale mono,courier,monospace",
    "font-size" : "10pt",
    "background-color" : "#DDDDDD",
    "width" : "70%"
  ]),

  "div.faqpath a" : ([
    "font-weight" : "bold",
    "text-decoration" : "none",
    "color" : "#000080"
  ]),

  "div.faqpath a:hover" : ([
    "font-weight" : "bold",
    "text-decoration" : "none",
    "color" : "#4682B4"
  ]),
]);

static string default_css = "";

private static mixed send_faq_css(object id)
{

  if (default_css != "")
    return Caudium.HTTP.string_answer(default_css, "text/css");
  
  foreach(sort(indices(default_css_desc)), string idx) {
    mapping entry = default_css_desc[idx];
    
    default_css += idx + "{";
    foreach(sort(indices(entry)), string idx2)
      default_css += sprintf("%s: %s; ", idx2, entry[idx2]);
    default_css += "}\n";
  }
  
  return Caudium.HTTP.string_answer(default_css, "text/css");
}

// variables we copy from the form to the local storage
private static multiset form_variables = (<
  "text", "number", "full_number", "section",
  "users", "groups", "see_also", "entry_path"
>);

private static mixed save_edit_data(object id)
{
  string ret = "<pre>";

  if (!id->misc->session_variables->gfaq || !id->misc->session_variables->gfaq->current_entry)
    return ({"<!-- session corrupted -->"});
  
  foreach(sort(indices(id->variables)), string idx)
    ret += sprintf("\t%s == %s\n", idx, id->variables[idx]);

  object  storage = id->conf->get_provider(QUERY(prov_storage));
  
  if (!storage ||
      !objectp(storage) ||
      !functionp(storage->put_entries))
    return ({"Error saving data - no put_entries in the storage module" });
  // TODO: the above should be handled by the error handler tag whose
  // contents is set by the designer. The tag's contents should be parsed
  // only when an error occurs.

  mapping     data = ([]);
  
  foreach(indices(form_variables), string idx) {
    if (id->variables[idx])
      data[idx] = id->variables[idx];
    else
      data[idx] = "";
  }
  
  string|int  puterr = 0;
  mixed       error = catch {
    puterr = storage->put_entries(id, data, ({id->misc->session_variables->gfaq->current_entry}));
  };

  if (error) {
    report_error("Storage exception: %O\n", error);
    
    if (arrayp(error))
      return ({ error[0] });
    else
      return ({ "Error in the storage module. Data not saved." });
  }

  if (puterr && stringp(puterr)) {
    report_error("Storage error: %O\n", puterr);
    return ({ puterr });
  }
  
//  return Caudium.HTTP.redirect(sprintf("%s/%s", QUERY(mountpoint), id->variables->entry_path));

  return Caudium.HTTP.string_answer(ret);
}

private static array(mapping) get_entries(object id, mapping options, string|void path)
{
  object  storage = id->conf->get_provider(QUERY(prov_storage));
  
  if (!storage ||
      !objectp(storage) ||
      !functionp(storage->get_entries))
    return ({});

  array(mapping) ret;
  mixed          error;
  
  error = catch {
    ret = storage->get_entries(id, options, path);
  };
  
  if (error) {
    report_error("FAQ:: storage module failed to fetch entries. Error and backtrace:\n%O",
                 error);
    return ({ });
  }
  
  return ret || ({});
}

// tags
array(string) cont_faqnavbar(string tag, mapping args, string contents,
                             object id, object f, mapping defines,
                             object fd) 
{  
  string   ret;
  mapping  div = ([
    "class" : "faqnavbar"
  ]);

  ret = parse_rxml(contents, id);
  ret = Caudium.make_container("div", div, ret);
  
  if (!args || (args && (!args->bottom || lower_case(args->bottom) == "yes")))
    id->misc->faq_module_navbar_contents = ret;
  else
    id->misc->faq_module_navbar_contents = 0;
  
  return ({ ret });
}

array(string) cont_faqpage(string tag, mapping args, string contents,
                           object id, object f, mapping defines,
                           object fd)
{
  string          ret;
  array(mapping)  entries;
  mapping         div = ([
    "class" : "faqpage"
  ]);
  
  if (id->prestate->edit || id->prestate->suggest)
    return ({""});

  entries = get_entries(id, ([]), id->misc->_faqpath ? id->misc->_faqpath : 0);
  id->misc->faq_entries = entries;
  if (!entries || !sizeof(entries))
    return ({""});

  // we could use spider.parse_html_lines instead, but that way we'd lost the
  // other tags for the inside of the <faqpage> container, which we don't
  // want to lose. And at the same time we do not want any of the inner
  // tags parsed outside of this container.
  id->misc->faq_inpage = FAQPAGE_MAGIC;
  ret = parse_rxml(contents, id);
  id->misc->faq_inpage = 0;
  
  ret = Caudium.make_container("div", div, ret);

  return ({ ret });
}

static private int find_matching_entry(mixed entry, string path)
{
  if (!mappingp(entry))
    return 0;

  if (entry->path == path)
    return 1;

  return 0;
}

array(string) cont_faqpath(string tag, mapping args, string contents,
                             object id, object f, mapping defines,
                             object fd)
{
  if (!id->misc->faq_inpage || id->misc->faq_inpage != FAQPAGE_MAGIC)
    return ({""});
  
  if (!id->variables->curpath || !sizeof(id->variables->curpath))
    return ({""});

  array(string)  thepath = (id->variables->curpath / "/") - ({""});
  array(mapping) outvars = ({});
  string         lastpath = "";
  int            i;
  
  outvars += ({([])});
  outvars[0]->URL = QUERY(mountpoint);
  outvars[0]->name = "Index";
  outvars[0]->isfirst = "yes";
  outvars[0]->islast = "no";
  
  foreach(thepath, string part) {
    if (part == "0")
      continue;
    
    outvars += ({([])});
    outvars[-1]->URL = replace(QUERY(mountpoint) + lastpath + "/" + part, "//", "/");
    lastpath += "/" + part;
    outvars[-1]->isfirst = "no";

    if (i == sizeof(thepath) - 1)
      outvars[-1]->islast = "yes";
    else
      outvars[-1]->islast = "no";

    int  idx = Array.search_array(id->misc->faq_entries, find_matching_entry, id->variables->curpath);
    if (idx >= 0)
      outvars[-1]->title = id->misc->faq_entries[idx]->contents->title;
    else
      outvars[-1]->title = id->variables->cursectiontitle;
    
    outvars[-1]->name = replace(lastpath[1..], "/", ".");
    i++;
  };

  return ({ do_output_tag(args, outvars, contents, id) });
}

array(string) cont_faqoutput(string tag, mapping args, string contents,
                             object id, object f, mapping defines,
                             object fd)
{
  if (!id->misc->faq_inpage || id->misc->faq_inpage != FAQPAGE_MAGIC)
    return ({""});
  
  array(mapping)  outvars;
  array(mapping)  entries = id->misc->faq_entries;

  if (!entries || !sizeof(entries))
    return ({""});
  
  /* build an array of mappings with the output variables */
  int     i = 0;
  string  in_section = "no";

  if (id->misc->session_variables->gfaq && id->misc->session_variables->gfaq->current_entry)
    if (id->misc->session_variables->gfaq->current_entry->contents->isqa == "no")
      in_section = "yes";
  
  outvars = allocate(sizeof(entries));
  foreach(entries, mapping entry) {
    outvars[i] = entry->contents;
    outvars[i]->in_section = in_section;
    if (QUERY(mountpoint)[-1] != '/') // for beauty... :P
      outvars[i++]->URI = QUERY(mountpoint) + entry->path;
    else
      outvars[i++]->URI = QUERY(mountpoint) + entry->path[1..];
  };
  
  return ({ do_output_tag(args, outvars, contents, id) });
}

array(string) cont_faqsections(string tag, mapping args, string contents,
                               object id, object f, mapping defines,
                               object fd)
{
  if (!id->misc->faq_inedit || id->misc->faq_inedit != FAQEDIT_MAGIC)
    if (!id->misc->faq_inpage || id->misc->faq_inedit != FAQPAGE_MAGIC)
      return ({""});

  if (!id->misc->session_variables->gfaq || !id->misc->session_variables->gfaq->current_entry)
    return ({"<!-- session corrupted -->"});
  
  if (!id->misc->faq_sections)
    id->misc->faq_sections = get_entries(id, (["sections":1]));
  
  array(mapping)  outvars;
  array(mapping)  sections = id->misc->faq_sections;
  array(string)   tpath = id->misc->session_variables->gfaq->current_entry->path / "/";
  string          cursect = tpath[0..(sizeof(tpath)-2)] * "/";
  int             i = 0;

  outvars = allocate(sizeof(sections));
  foreach(sections, mapping entry) {
    outvars[i] = entry->contents;
    if (cursect == entry->path)
      outvars[i++]->current = "yes";
    else
      outvars[i++]->current = "no";
  }

  return ({ do_output_tag(args, outvars, contents, id) });
}

array(string) cont_faqeditarray(string tag, mapping args, string contents,
                                object id, object f, mapping defines,
                                object fd)
{
  if (!id->misc->faq_inedit || id->misc->faq_inedit != FAQEDIT_MAGIC)
    return ({""});

  if (!id->misc->session_variables->gfaq || !id->misc->session_variables->gfaq->current_entry)
    return ({"<!-- session corrupted -->"});
  
  array(mapping)  outvars;
  array(string)   thearray;
  mapping         entry = id->misc->session_variables->gfaq->current_entry;
  int             i = 0;

  if (!args)
    args = ([]);

  string  what = tag == "faqeditarray" ? args->which : 0;

  switch(what || tag) {
      case "faqeditusers":
      case "users":
        thearray = entry->users;
        break;

      case "faqeditgroups":
      case "groups":
        thearray = entry->groups;
        break;

      case "faqeditseealso":
      case "seealso":
        thearray = entry->see_also;
        break;
  }

  
  if (!thearray || !sizeof(thearray))
    return ({ "" });

  outvars = allocate(sizeof(thearray));
  foreach(thearray, string idx) {
    outvars[i] = ([]);
    outvars[i++]->name = idx + "\n";
  }

  return ({ do_output_tag(args, outvars, contents, id) });
}

static private mapping faqedit_vars = ([
  "faqeditaction" : "",
  "faqannotated" : "",
  "faqeditnumber" : "",
  "faqedittext" : "",
  "faqfieldnumber" : "",
  "faqfieldtext" : ""
]);

array(string) cont_faqedit(string tag, mapping args, string contents,
                           object id, object f, mapping defines,
                           object fd)
{  
  if (!id->prestate->edit)
    return ({ "" });

  if (!id->misc->session_variables->gfaq || !id->misc->session_variables->gfaq->current_entry)
    return ({"<!-- session corrupted -->"});

  if (!args)
    args = ([]);
  
  string         epath = id->misc->session_variables->gfaq->current_entry->path;
  array(mapping) sections = get_entries(id, (["sections":1]));
  array(mapping) entries = get_entries(id, ([]), epath);

  if (!entries || sizeof(entries) != 1)
    return ({"<!-- no entries or multiple entries on this path -->"});
  
  string   ret;
  mapping  div = ([
    "class" : "faqedit"
  ]);

  // prepare the variables required in this tag
  id->variables->faqeditaction = sprintf("/(edit)%s%s", QUERY(mountpoint), LOCATION_SAVE);
  id->variables->faqannotated = entries[0]->contents->annotated;
  id->variables->faqedittext = entries[0]->contents->text;
  id->variables->faqeditnumber = replace(entries[0]->path, "/", ".")[1..];
  
  // same hack as in faqpage
  id->misc->faq_inedit = FAQEDIT_MAGIC;
  id->misc->faq_entries = entries;
  id->misc->faq_sections = sections;

  // now prepare the output variables and the <form> params (if we're doing
  // a form)
  array(mapping)  outvars = ({ ([]) });
  array(string)   tpath = entries[0]->path / "/";
  
  outvars[0]->text = entries[0]->contents->text;
  outvars[0]->fullnumber = replace(entries[0]->path, "/", ".")[1..];
  outvars[0]->section = sizeof(tpath) >= 2 ? (tpath[0..(sizeof(tpath)-2)] * ".")[1..] : "";
  outvars[0]->number = sizeof(tpath) >= 2 ? tpath[-1] : "";
  outvars[0]->action = sprintf("/(edit)%s%s", QUERY(mountpoint), LOCATION_SAVE);
  outvars[0]->name_text = "text";
  outvars[0]->name_number = "number";
  outvars[0]->name_fullnumber = "full_number";
  outvars[0]->name_section = "section";
  outvars[0]->name_users = "users";
  outvars[0]->name_groups = "groups";
  outvars[0]->name_seealso = "see_also";
  
  mapping  form = ([
    "action" : outvars[0]->action,
    "method" : "post"
  ]);
  mapping  hidden = ([
    "type" : "hidden"
  ]);

  ret = do_output_tag(args, outvars, contents, id);
  if (!args->form || args->form != "no") {
    hidden->name = "entry_path";
    hidden->value = entries[0]->path;
    
    ret = Caudium.make_container("form", form,
                         Caudium.make_tag("input", hidden) + ret);
  }
  
  id->misc->faq_entries = 0;
  id->misc->faq_sections = 0;
  id->misc->faq_inedit = 0;

  // clean the variable space up
  id->variables->faqeditaction = 0;
  id->variables->faqannotated = 0;
  id->variables->faqedittext = 0;
  id->variables->faqeditnumber = 0;
  
  ret = Caudium.make_container("div", div, ret);

  return ({ ret });
}

array(string) cont_faqsuggest(string tag, mapping args, string contents,
                              object id, object f, mapping defines,
                              object fd)
{
  if (!id->prestate->suggest)
    return ({ "" });

  string   ret;
  mapping  div = ([
    "class" : "faqsuggest"
  ]);

  ret = parse_rxml(contents, id);
  ret = Caudium.make_container("div", div, ret);

  return ({ ret });
}

string tag_faqbutton(string tag, mapping m, object id)
{
  string   ret;
  string   tagname = 0, tagtext;
  mapping  btn;

  if (!m || !mappingp(m) || !sizeof(m))
    return "";

  if (!m->fname || !m->ftype)
    return "";

  btn = m + ([]);
  tagtext = m->flabel;
  m_delete(btn, "fname");
  m_delete(btn, "ftype");
  m_delete(btn, "flabel");
  
  switch(lower_case(m->ftype)) {
      case "gbutton":
        tagname = "gbutton";
        break;

      case "text":
        tagname = "a";
        break;

      case "url":
        break;
  }
  
  string prestate = 0;
  
  switch(lower_case(m->fname)) {
      case "edit":
        prestate = "/(edit)";
        if (!tagtext)
          tagtext = "Edit";
        break;

      case "suggest":
        prestate = "/(suggest)";
        if (!tagtext)
          tagtext = "Suggest";
        break;

      case "index":
        if (!tagtext)
          tagtext = "Index";
        break;

      default:
        return "";
  }

  btn->href = (prestate ? prestate : "") + QUERY(mountpoint);
  if (btn->href[-1] != '/')
    btn->href += "/";
  if (btn->href[0] != '/')
    btn->href = "/" + btn->href;
  
  if (!tagname)
    return btn->href;

  btn->class = "faqbutton";

  ret = parse_rxml(Caudium.make_container(tagname, btn, tagtext), id);
  
  return ret;
}

mapping query_tag_callers()
{
  return ([
    "faqbutton" : tag_faqbutton
  ]);
}

mapping query_container_callers()
{
  return ([
    "faqnavbar" : cont_faqnavbar,
    "faqpage" : cont_faqpage,
    "faqoutput" : cont_faqoutput,
    "faqedit" : cont_faqedit,
    "faqsections" : cont_faqsections,
    "faqeditusers" : cont_faqeditarray,
    "faqeditgroups" : cont_faqeditarray,
    "faqeditseealso" : cont_faqeditarray,
    "faqeditarray" : cont_faqeditarray,
    "faqsuggest" : cont_faqsuggest,
    "faqpath" : cont_faqpath
  ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: faq_name
//! Give this instance some name. It can be used by all the provider modules to tell various FAQs apart.
//!  type: TYPE_STRING
//!  name: General: FAQ Name
//
//! defvar: mountpoint
//! This is where the module will be inserted in the 
//!  type: TYPE_LOCATION
//!  name: Paths: Mount point
//
//! defvar: prov_storage
//! Name of the provider that implements storage for this module. Note that the storage providers usually affix some string to the value of this setting. For example the PostgreSQL module appends <em>_pg</em>.
//!  type: TYPE_STRING
//!  name: Providers: Storage
//
//! defvar: prov_access
//! Name of the provider that implements access control for this module. FAQ Access control is different to the mountpoint access control - it determines whether a user may/may not edit/remove/add FAQ entries.
//!  type: TYPE_STRING
//!  name: Providers: Access Control
//
//! defvar: prov_css
//! A module that provides CSS stylesheets for this module. If not found, an internal CSS will be used.
//!  type: TYPE_STRING
//!  name: Providers: CSS provider
//
//! defvar: prov_ui
//! This is the name of the provider module that can provide elements of the application UI. Currently defined elements that can be augmented by the provider are listed below. See the documentation for more information.<br /><ul><li><strong>navbar</strong></li></ul><br />
//!  type: TYPE_STRING
//!  name: Providers: User Interface
//
//! defvar: html_charset
//! The character set of the generated HTML code.
//!  type: TYPE_STRING
//!  name: HTML and CSS: HTML Charset
//
//! defvar: css_uri
//! URI of the CSS stylesheet to use with the module. If left empty, an internal stylesheet will be used.
//!  type: TYPE_STRING
//!  name: HTML and CSS: Stylesheet URI
//
//! defvar: html_title
//! Title of the HTML pages generated by this module.
//!  type: TYPE_STRING
//!  name: HTML and CSS: Page Title
//
//! defvar: layout_location
//! Directory (in the physical filesystem) where the FAQ layout files can be found.
//!  type: TYPE_DIR
//!  name: Layouts: Location
//
//! defvar: layout_default
//! Name of the default layout to use. A file named LAYOUTNAME.rxml must exist in the layouts directory.
//!  type: TYPE_STRING
//!  name: Layouts: Default Layout
//
