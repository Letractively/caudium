/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import Headlines;

#include <headlines/base.h>

constant name = "pikecommunity";
constant site = "Pike Community";
constant url  = "http://pike-community.org/";
constant path = "ultra.pike";

array names = ({"title", "name", "time" });
array titles = ({ "Title", "Author", "Date" });

constant sub = "Other/Idonex";

array headlines;
static private string parse_it(string tag, mapping args, string|int contents,
			       mapping hl)
{
  mixed tmp;
  switch(tag)
  {
  case "headline":
    hl = ([]);
    parse_html(contents, ([ ]), ([ "title": parse_it, "url": parse_it,
				   "name": parse_it, "added": parse_it,
				   "body": parse_it ]),   hl);
    headlines += ({ hl });
    break;

  case "added":
    tag = "time";
    contents = sprintf("%s-%s-%s, %s:%s:%s", contents[..3],
		       contents[4..5], contents[6..7],
		       contents[8..9], contents[10..11],
		       contents[12..13]);
  default:
    hl[tag] = contents;
    break;
  }
  return "";
}
  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  parse_html(data, ([]), (["headline" : parse_it ]) );
  headlines = reverse(headlines);
}


string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "Author:   %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time, hl->name||""
		 );
}
