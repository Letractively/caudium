/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © 1998 Kai Voigt <k@123.org>
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
 * This module produces some nested navigation menus depending on the
 * current document.  Read the documentation in the config interface
 * for usage hints.
 */
 
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version  = "$Id$";
constant thread_safe  = 1;	// Kiwi: I think it should be... 
constant module_type  = MODULE_PARSER;
constant module_name  = "123 Layout";
constant module_doc   = "<p>Per's Layout remaked by Kai :)<br />"
                        "And based on Navigation module.</p>"
			"<p>To use this module you must add two file a the "
			"top of your virtual server : <tt>.config</tt> and "
			"<tt>.pathways</tt> and include the tag &lt;123navigation&gt; "
			"in the pages you need to have the navigation bar on.</p>"
			"<p>The <tt>.config</tt> file is the file where &lt;navigation"
			"&gt; tags are written. You can separate menu and submenu"
			" part with '**' separator.<br />"
			"<b>Example:</b><tt><pre>"
			"&lt;navigation maxwidth=150&gt;\n"
                        " &lt;textstyle left font=\"offensive\" scale=0.4 spacing=3&gt;\n"
                        "\n"
                        " &lt;boxstyle left text bg=white alpha=255&gt;\n"
                        " &lt;boxstyle left text current bg=white alpha=255&gt;\n"
                        " &lt;boxstyle left text selected bg=white alpha=255&gt;\n"
                        "\n"
                        " &lt;boxstyle middle text fg=\"#3333cc\" bg=white alpha=255&gt;\n"
                        " &lt;boxstyle middle text current fg=\"#999999\" bg=white alpha=255&gt;\n"
                        " &lt;boxstyle middle text selected fg=\"#cc3333\" bg=white alpha=255&gt;\n"
                        "\n"
                        " &lt;boxstyle right text bg=white alpha=255&gt;\n"
                        " &lt;boxstyle right text current bg=white alpha=255&gt;\n"
                        " &lt;boxstyle right text selected bg=white alpha=255&gt;\n"
                        "**\n"
                        "&lt;submenu indent=10&gt;\n"
                        " &lt;textstyle left font=\"offensive\" scale=0.35 spacing=3&gt;\n"
                        "\n"
                        " &lt;boxstyle width=1 left text bg=white alpha=0&gt;\n"
                        " &lt;boxstyle width=1 left text current bg=white alpha=0&gt;\n"
                        " &lt;boxstyle width=1 left text selected bg=white alpha=0&gt;\n"
                        "\n"
                        " &lt;boxstyle middle text fg=\"#3333cc\" bg=white alpha=255&gt;\n"
                        " &lt;boxstyle middle text current fg=\"#999999\" bg=white alpha=255&gt;\n"
                        " &lt;boxstyle middle text selected fg=\"#cc3333\" bg=white alpha=255&gt;\n"
                        "\n"
                        " &lt;boxstyle right text bg=white alpha=255&gt;\n"
                        " &lt;boxstyle right text current bg=white alpha=255&gt;\n"
                        " &lt;boxstyle right text selected bg=white alpha=255&gt;\n"
                        "**\n"
                        "&lt;submenu indent=10&gt;\n"
                        " &lt;textstyle left font=\"offensive\" scale=0.35 spacing=3&gt;\n"
                        "\n"
                        " &lt;boxstyle width=1 left text alpha=0&gt;\n"
                        " &lt;boxstyle width=1 left text current alpha=0&gt;\n"
                        " &lt;boxstyle width=1 left text selected alpha=0&gt;\n"
                        "\n"
                        " &lt;boxstyle middle text fg=\"#3333cc\" bg=white alpha=255&gt;\n"
                        " &lt;boxstyle middle text current fg=\"#999999\" bg=white alpha=255&gt;\n"
                        " &lt;boxstyle middle text selected fg=\"#cc3333\" bg=white alpha=255&gt;\n"
                        "\n"
                        " &lt;boxstyle right text bg=white alpha=255&gt;\n"
                        " &lt;boxstyle right text current bg=white alpha=255&gt;\n"
                        " &lt;boxstyle right text selected bg=white alpha=255&gt;\n"
			"</pre></tt></p>"
			"<p>The <tt>.pathways</tt> file is used to setup the menus names. "
			"Please note the space are replaced by '_' instead.<br />"
			"<b>Example:</b><tt><pre>"
			"Home		/\n"
			"Products	/products/\n"
			"|Bounce_Pro	/products/bouncepro/\n"
			"|Anti_Spam	/products/antispam/\n"
			"|Shopping	/products/shopping/\n"
			"Team		/team/\n"
			"|Marketing	/team/marketing/\n"
			"|Lead		/team/lead/\n"
			"|Hummm		/team/hmm.html\n"
			"Contacts	/contacts.html\n"
			"Search		/search.html\n"
			"</pre></tt></p>"
			"<p><b>Note:</b> You can use the <i>\"refresh\"</i> prestate to "
			"force reload the config files...</p>"
			"";
constant module_unique= 1;

/*
 * In navlabels we store the left hand side of the .pathway structure.
 * I.e. the data representing the navigation tree.  In navtargets, we
 * put the according URLs for the labels.  activelabel will point to
 * the index that represents the current document.
 */
array (array (string)) navlabels;
array (string) navtargets;
array (string) config;
int activelabel;

/*
 * From the .config file, we read the code fragments for the
 * <navigation> module.  The single config elements are separated
 * by "**"'s.
 */
void read_config(object request_id)
{
 string s = request_id->conf->try_get_file("/.config", request_id);
 config = s/"**";
}

/*
 * Some parsing of the .pathways content.  Each line represents a
 * path in the navigation tree.  For each line in .pathways, we
 * compute the full path and store it together with the target.
 */
void parse_pathways(object request_id)
{
 string s = request_id->conf->try_get_file("/.pathways", request_id);

 string result = "";
 array (string) curpath = ({});

 navlabels = ({});
 navtargets = ({});

 foreach(s/"\n", string line)
 {
  /* counting the depth of the current line */
  int depth=0;
  while(line[depth..depth] == "|") {
   depth++;
  }

  /* we're splitting the line into left and right hand side */
  array (string) pair = replace(line[depth..], "\t", " ")/" "-({});
  string label = replace(pair[0], "_", " ");
  string target = pair[sizeof(pair)-1]; // pair[1] does not work! strange

  /* just in case we get a empty line */
  if ((target == "") || (label == "")) {
   continue;
  }

  /* if we're descending, so let's add the element to the current path,
     otherwise strip the path */
  if (sizeof(curpath) <= depth) {
   curpath += ({label});
  } else {
   curpath = curpath[..depth-1]+({label});
  }

  /* append the entries to the global arrays */
  navlabels += ({curpath});
  navtargets += ({target});
 }
}

/*
 * We search for the matching path.  The algorithm is simple:
 * let /a/b/c/ be the current document path.  We then check for
 * /a/b/c/, /a/b/, /a/ and / (i.e. successive reducing the path)
 * if it fits to one of the targets in the navigation targets.
 */
int navelement(string dirname)
{
 string result = "";

 array (string) paths = dirname/"/";
 string testit = "";

 for (int i=sizeof(paths)-2; i>=0; i--) {
  testit = paths[..i]*"/"+"/";
  for (int j=0; j<sizeof(navtargets); j++) {
   if (testit == navtargets[j]) {
    return j;
   }
  }
 }
}

/*
 * the next three functions to the output. list_label() prints
 * an element and checks if it's the active one or not.  open_level()
 * prints the code for the <navigation> module depending on the
 * depth, close_level() closes the level by outputting the correct
 * closing container.
 */
string list_label(int i)
{
 array (string) navlabel = navlabels[i];
 string navtarget = navtargets[i];

 if (i == activelabel) {
  return "<mi selected href=\""+navtarget+"\">"+navlabel[-1]+"</mi>\n";
 } else {
  return "<mi href=\""+navtarget+"\">"+navlabel[-1]+"</mi>\n";
 }
}

string open_level(int curdepth)
{
 return config[curdepth];
}

string close_level(int curdepth)
{
 if (curdepth != 1) {
  return "</submenu>\n";
 } else {
  return "</navigation>\n";
 }
}

/*
 * Here, we're creating the code for the <navigation> module.
 */
string create_navigation()
{
 string result = "";
 int curdepth = 0;

 /* we're probing every entry */
 for (int i=0; i<sizeof(navlabels); i++) {
  /* navlabel is the path to be checked, testit is the same without
     the ending component */
  array (string) navlabel = navlabels[i];
  array (string) testit = navlabel[..sizeof(navlabel)-2];

  /* this is smart: if testit isn't a prefix of the active path,
     then don't print it. */
  if (!equal(navlabels[activelabel][..sizeof(testit)-1], testit)) {
   continue;
  }

  /* Depending on the depth, we have to open, or close a level.
     In any case, we print the element */
  if (curdepth < sizeof(navlabel)) {
   result += open_level(curdepth);
   result += list_label(i);
   curdepth = sizeof(navlabel);
  } else {
   if (curdepth == sizeof(navlabel)) {
    result += list_label(i);
   } else { // curdepth > sizeof(navlabel)
    while (curdepth > sizeof(navlabel)) {
     result += close_level(curdepth);
     curdepth--;
    }
    result += list_label(i);
   }
  }
 }

 /* now, we're closing any open levels */
 while (curdepth > 0) { 
  result += close_level(curdepth);
  curdepth--;
 }
 return (result);
}

//! tag: 123navigation
//!  Insert the navigation into the page that call this tag.
//! note: You can use prestate "refresh" to force the refresh
//!  of the navigation menus.
string tag_123navigation(string tag_name, mapping arguments,
                object request_id, object file, mapping defines)
{
 if ((!navlabels) || (request_id->prestate->refresh)) {
  parse_pathways(request_id);
  read_config(request_id);
 }
 activelabel = navelement(request_id->not_query);
 return create_navigation();
}

mapping query_tag_callers()
{
 return (["123navigation":tag_123navigation]);
}

void start(int cnt, object conf)
{
  module_dependencies(conf, ({ "navigation" }));
}
