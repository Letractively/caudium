/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Based on the word from Matthew Brookes <matt@broadcom.ie> and
 * Bill Welliver <hww3@riverweb.com>.
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
 * To Do:
 *   <gtext> support could use some cleaning up
 *     (but then so could the whole thing!) 
 *   Browser reload overide .pathname cache
 *     (or maybe "nocache" option a la <insert> would be easier?
 *   <gtext> args can't be quoted
 *   .pathmagic files for <gtext> status bar text (maybe :^)
 *   Suggestions anyone?
 *
 * History:
 *   0.1.4 1998/05/05 First release. Does the basics	            (matt)
 *   0.1.5 1998/06/02 Added arg "skip" for f.vandijk	            (matt)
 *   0.1.6 1998/06/08 Added arg "rootname" for f.vandijk            (matt)
 *   0.2   1998/06/10 Capitalization and Alternate text w/ caching  (hww3)
 *   0.3   1998/06/11 Version 0.1.6 (matt) & 0.2 (hww3) merged      (matt)
 *   0.3.1 1998/06/11 Spaces moved from separator to config default (matt)
 *   0.3.2 1998/06/11 Bug fix for skip                              (chris)
 *   0.4.0 1998/06/12 Quick & dirty <gtext> support                 (matt)
 *   0.4.1 1998/06/15 Small bug in gtext support fixed              (matt)
 *   0.4.2 1998/06/16 Prestate support for Thomas Koester           (matt)
 *   0.4.3 1998/06/18 Module start time added to status info        (matt)
 *   0.4.4 1998/06/18 Removed newline after separator               (matt)
 *
 */
//
//! module: Path tag
//!  Config interface style URL location thing.<br />
//!  Adds a new tag &lt;path&gt; which displays path part of the current URL,
//!  split into clickable links. Put it at the top of all your pages to aid
//!  navigation. (Using &lt;insert&gt; or tagbuilder module makes this
//!  easy!)<br />
//!  Syntax: &lt;path [separator="string"] [rootname="string"] [skip=n]
//!  [capitalize] [gtext[="gtext options"]] [magic]&gt;</I><P>",

//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version  = "$Id$";
constant module_type  = MODULE_PARSER;
constant module_name  = "Path tag";
constant module_doc   = "Config interface style URL location thing!<P>"
                        "Adds a new tag &lt;path&gt; which displays the path "
                        "part of the current URL, split into clickable links. "
                        "Put it at the top of all your pages to aid "
			"navigation. (Using &lt;insert&gt; or the tagbuilder "
			"module makes this easy!)"
	                "<P>Syntax: <I>&lt;path [separator=\"string\"] "
	                "[rootname=\"string\"] [skip=n] [capitalize] "
                        "[gtext[=\"gtext options\"]] [magic]&gt;</I><P>";
constant module_unique= 1;
constant thread_safe=1;

string tagname;
int usecount;
mapping cache=([]);
string starttime = ctime(time());

void create()
{
  defvar( "tagname", "path", "Tag name", TYPE_STRING, 
	  "Name of the tag\n"
	);

  defvar( "timeout", "3600", "Cache Timeout", TYPE_STRING, 
	  "Number of seconds for .pathname cache timeout.\n"
           "<P>The file .pathname in a directory can contain a string \n"
           "to be used in place of the directory name.\n"
           "<BR><I>(You will have to wait [timeout] seconds for\n"
           "changes to take effect.)</I>\n"
	);

  defvar( "separator", " -> ", "Default separator", TYPE_STRING, 
          "Can be overridden by separator=\"string\" argument.<P>\n"
           "Example:<br>\n"
	   "<pre>&lt;html&gt;\n"
	   "[&lt;path separator=\"][\"&gt;]\n"
	   "&lt;/html&gt;</pre>\n"
	   "Might give:<P>\n"
           "[<u><font color=\"blue\">home</u></font>] "
           "[<u><font color=\"blue\">dir1</u></font>] "
           "[<u><font color=\"blue\">dir2</u></font>]\n"
      );

  defvar( "rootname", "home", "Default root name", TYPE_STRING, 
	  "Default name of root level link, instead of \"/\"<BR>\n"
           "Can be overridden by rootname=\"string\" argument.\n"
      );

  defvar( "gtargs", "scale=0.6", "Default &lt;gtext&gt; options", TYPE_STRING, 
	  "Default options if gtext is used.\n"
           "Can be overridden by gtext=\"gtext options\""
	);

}

string status()
{
   return "Called " + usecount + " times since " + starttime;
}

//
//! tag: path
//!  Add a config interface like URL location thing. Note that the name
//!  can be changed using the configuration interface
//! arg: separator
//!  The separator between two directories e.g. "->" per default.
//! arg: rootname
//!  Name of the / directory e.g. "home" per default.
//! arg: skip
//!  Number of directory to skip from the current directory.
//! arg: capitalize
//!  If exist then the directories are capitalized
//! arg: gtext
//!  "Gtextify" the texts... Also used to add some gtext options
//!  to the gtext calls.
//! arg: magic
//!  If gtext is set, this add the "magic" option to gtext.
string tag_path( string tag, mapping args, object id, object file, mapping defines )
{
   string part;
   string out="";
   string path="";
   string gtargs="";
   string separator;
   int skip;
   string rootname;

   // read separator from tag or config   
   if(!(separator = args->separator))
      separator = query("separator");

   // read top level to include from tag or default to all
   if(!(skip = (int) args->skip))
      skip = 0;

   // read rootname from tag or config
   if(!(rootname = args->rootname))
      rootname = query("rootname");

   if(!(gtargs = args->gtext))
      gtargs =  query("gtargs");

   // split path/file part of URL into an array "parts"
   array (string) parts = id->not_query / "/";
   array (string) tmp;
   mixed t;
   string a = (sizeof(id->prestate)?"apre":"a");

   for(int i=0; i < sizeof(parts)-1; i++)
   {
      part = parts[i];  
      path += part + "/"; // rebuild the path part of the URL

      if(cache[path] && cache[path]->timeout > time())
          part=cache[path]->text; // Use the cached text for pathpart.
      else	// Either we don't have it or the cache timed out.
      {
         cache[path]=([]);
	 cache[path]->timeout=time() + (int)query("timeout");  
	 t=id->conf->real_file(path+".pathname", id);
//       perror(t+"\n");

	 if(t)
         {
	    cache[path]->text=Stdio.read_file(t)-"\n";
//		perror(cache[path]->text+"\n");
	    part=cache[path]->text;
	 }
	  else
  	    cache[path]->text=part; 
      }

      if(part == "") part = rootname;

      // Build the result
      if(i >= skip)
      {
         out += (args->gtext&&args->magic?"":("<" + a + " href=\"" +
                                              path + "\">")) +
         (args->gtext?("<gtext " + gtargs + 
         (args->magic?(" magic href=\"" + path + "\""):"") +
         ">"):"") +
	 (args->capitalize?capitalize(part):part) +
         (args->gtext?"</gtext>":"") +
         (args->gtext&&args->magic?"":"</" + a + ">");

         if(i < sizeof(parts) - 2)
            out += separator;
      }
   }
  
   usecount++ ;
   return out ;
}


void start(int cnt, object conf) // read the definitions from the config interface
{
 // we need gtext :)
 module_dependencies(conf, ({ "graphic_text" }));
 tagname = query("tagname");
}


mapping query_tag_callers()
{
   return ([ tagname : tag_path ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: tagname
//! Name of the tag
//!
//!  type: TYPE_STRING
//!  name: Tag name
//
//! defvar: timeout
//! Number of seconds for .pathname cache timeout.
//!<P>The file .pathname in a directory can contain a string 
//!to be used in place of the directory name.
//!<BR><I>(You will have to wait [timeout] seconds for
//!changes to take effect.)</I>
//!
//!  type: TYPE_STRING
//!  name: Cache Timeout
//
//! defvar: separator
//! Can be overridden by separator="string" argument.<P>
//!Example:<br />
//!<pre>&lt;html&gt;
//![&lt;path separator="]["&gt;]
//!&lt;/html&gt;</pre>
//!Might give:<P>
//![<u><font color="blue">home</u></font>] [<u><font color="blue">dir1</u></font>] [<u><font color="blue">dir2</u></font>]
//!
//!  type: TYPE_STRING
//!  name: Default separator
//
//! defvar: rootname
//! Default name of root level link, instead of "/"<BR>
//!Can be overridden by rootname="string" argument.
//!
//!  type: TYPE_STRING
//!  name: Default root name
//
//! defvar: gtargs
//! Default options if gtext is used.
//!Can be overridden by gtext="gtext options"
//!  type: TYPE_STRING
//!  name: Default &lt;gtext&gt; options
//
