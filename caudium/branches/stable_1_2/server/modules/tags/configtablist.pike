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

//
//! module: Config tab-list
//!  Adds some tags for making a config-interface look-alike tab-list.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER | MODULE_LOCATION
//! cvs_version: $Id$
//
//! container: config_tablist
//!  Generates a list of tabs, like the one in the configuration interface.
//!  
//!  Theis container tag does not take any arguments, but it
//!  must always contain one or more &lt;tab&gt; container tags.
//
//! tag: tab
//!  Generates a single config tab.
//
//! attribute: [alt]
//!  Alternative text for the image. The default is to use ascii-art
//!  to make it look like a tablist.
//
//! attribute: [bgcolor]
//!  Set the background color. Default is white.
//          
//! attribute: [border]
//!  Set the width of the border of the image. Default is zero.
//          
//! attribute: [selected]
//!  Make this tab the selected tab.
//

/*
 * $Id$
 *
 * Makes a tab-list like the one in the config-interface.
 *
 * $Author$
 */

constant cvs_version="$Id$";
constant thread_safe=1;

#define use_contents_cache 0
#define use_gif_cache      1
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER | MODULE_LOCATION; 
constant module_name = "Config tab-list";
constant module_doc  = "Adds some tags for making a config-interface "
	      "look-alike tab-list.<br>\n"
	      "Usage:<br>\n"
	      "<ul><pre>&lt;config_tablist&gt;\n"
	      "&lt;tab href=\"/tab1/\"&gt;Some text&lt;/tab&gt;\n"
	      "&lt;tab href=\"/tab2/\"&gt;Some more text&lt;/tab&gt;\n"
	      "&lt;tab href=\"a/strange/place/\"&gt;Tab 3&lt;/tab&gt;\n"
	      "&lt;/config_tablist&gt;\n"
	      "</pre></ul>Attributes for the &lt;tab&gt; tag:<br>\n"
	      "<ul><table border=0>\n"
	      "<tr><td><b>selected</b></td><td>Whether the tab is selected "
	      "or not.</td></tr>\n"
	      "<tr><td><b>bgcolor</b></td><td>What color to use as background. "
	      "Defaults to white.</td></tr>\n"
	      "<tr><td><b>alt</b></td><td>Alt-text for the image (default: "
	      "\"_/\" + text + \"\\_\").</td></tr>\n"
	      "<tr><td><b>border</b></td><td>Border for the image (default: "
	      "0).</td></tr>\n"
	      "</table></ul>\n";
constant module_unique = 1;

#if use_contents_cache  
mapping(string:string) contents_cache = ([]);
#endif

#if use_gif_cache  
mapping(string:string) gif_cache = ([]);
#endif

/*
 * Functions
 */


void create()
{
  defvar("location", "/configtabs/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the buttons.");
}

string tag_config_tab(string t, mapping a, string contents)
{
  string dir = "u/";
  mapping img_attrs = ([]);
  if(a->help) return module_doc;
  if (a->selected) {
    dir = "s/";
  }
  if(a->bgcolor) {
    dir+=replace(a->bgcolor,"#","|");
    m_delete(a, "bgcolor");
  } else
    dir+="white";
  dir+="/";
  m_delete(a, "selected");

  img_attrs->src = QUERY(location) + dir +
    replace(http_encode_string(contents), "?", "%3f") + ".gif";
  if (a->alt) {
    img_attrs->alt = a->alt;
    m_delete(a, "alt");
  } else {
    img_attrs->alt = "_/" + html_encode_string(contents) + "\\_";
  }
  if (a->border) {
    img_attrs->border = a->border;
    m_delete(a, "border");
  } else {
    img_attrs->border="0";
  }
  return make_container("a", a, make_container("b", ([]),
					       make_tag("img", img_attrs)));
}

int my_hash(mixed o)
{
  switch(sprintf("%t",o))
  {
    case "string": return hash(o);
    case "int": return o;
    case "mapping":
      int h = 17 + sizeof(o);
      foreach(indices(o), mixed index)
         h += hash(index) * my_hash(o[index]);
      return h;

   case "array":
    return hash(sprintf("%O",o));
   default:
     return hash(encode_value(o));
  }
}

string tag_config_tablist(string t, mapping a, string contents)
{
#if use_contents_cache  
# if constant(Mhash.hash_md5)
  key = Mhash.hash_md5(contents+my_hash(a));
# else
  object md5 = Crypto.md5();
  md5->update(contents+my_hash(a));
  string key=md5->digest();
# endif
  if(contents_cache[key])
    return contents_cache[key];
#endif
  string res=replace(parse_html(contents, ([]), (["tab":tag_config_tab])),
		 ({ "\n", "\r" }), ({ "", "" }));
#if use_contents_cache  
  contents_cache[key]=res;
#endif  
  return res;
}

mapping query_container_callers()
{
  return ([ "config_tablist":tag_config_tablist ]);
}

#if constant(thread_create)
object interface_lock = Thread.Mutex();
#endif /* constant(thread_create) */

object load_interface()
{
#if constant(thread_create)
  // Only one thread at a time may call caudium->configuration_interface().
  //
  // load_interface() shouldn't be called recursively,
  // so don't protect against it.
  mixed key = interface_lock->lock();
#endif /* constant(thread_create) */
  return(caudium->configuration_interface());
}

mapping find_file(string f, object id)
{
  string s;
#if use_gif_cache
  if(s=gif_cache[f])
  {
//    werror("Configtablist: "+f+" found in cache.\n");
    return http_string_answer(s,"image/gif");
  }
#endif  

  array pagecolor; //=({ 122, 122, 122 }); //Colors.parse_color("lightblue");
  array(string) arr = f/"/";
  if (sizeof(arr) > 1) {
    object interface = load_interface();
    object(Image.image) button;

    if (arr[-1][sizeof(arr[-1])-4..] == ".gif") {
      arr[-1] = arr[-1][..sizeof(arr[-1])-5];
    }

    pagecolor=Colors.parse_color(replace(arr[1],"|","#",));
    
    switch (arr[0]) {
    case "s":	/* Selected */
      button = interface->draw_selected_button(arr[2..]*"/",
					       interface->button_font,
					       pagecolor);
      break;
    case "u":	/* Unselected */
      button = interface->draw_unselected_button(arr[2..]*"/",
						 interface->button_font,
						 pagecolor);
      break;
    default:
      return 0;
    }
    
    s=Image.GIF.encode(button,@pagecolor);
#if use_gif_cache
    if(!gif_cache[f])
      gif_cache[f]=s;
#endif  
    return http_string_answer(s,"image/gif");
  }
  return 0;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: location
//! The URL-prefix for the buttons.
//!  type: TYPE_LOCATION|VAR_MORE
//!  name: Mountpoint
//
