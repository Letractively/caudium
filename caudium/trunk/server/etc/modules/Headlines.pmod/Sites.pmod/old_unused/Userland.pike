/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import "..";

#include "../base.pike"

constant site = "Userland";
constant url  = "http://news.userland.com/";
constant path = "mostRecentScriptingNews.xml";
constant names = ({ "title" });
constant titles = ({ "Title" });
constant sub = "Computing/General";

array headlines;

static private string parse_it(string tag, mapping args, string|int contents,
			       mapping hl)
{
  mixed tmp;
  switch(tag)
  {
  case "item":
    hl = ([]);
    Caudium.parse_html(contents, ([ ]), ([ "text": parse_it, "url": parse_it,
				   "linetext": parse_it  ]),
	       hl);
    headlines += ({ hl });
    break;

  case "text":
    hl->desc = (replace(contents, "\n", " ") / " " - ({""}))*" ";


    break;
    
  case "linetext":
    tag = "title";
    
  default:
    hl[tag] = String.trim_whites( contents );
    break;
  }
  return "";
}

private static void parse_reply(string data)
{
  Caudium.parse_html(data, ([]), (["item" : parse_it ]) );
}

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}


string entry2txt(mapping hl)
{
  return sprintf("Title: %s\n"
		 "URL:   %s\n"
		 "%s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 indent(hl->desc, 7)
		 );
}


