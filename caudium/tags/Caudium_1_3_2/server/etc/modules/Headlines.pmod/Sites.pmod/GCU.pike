/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "gcu";
constant site = "GCU Squad";
constant url  = "http://gcu-squad.org/";
constant path = "gcunews.txt";
constant names =  ({ "date", "author", "title","url" });
constant titles =  ({ "date", "author", "title", " url "});
constant full_names = ({ "date", "author", "title", "url" });
constant sub = "Friends / GCU";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%%"), string s)
  {
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 4) {
      if(strlen(lines[1]) > 52)
	lines[1] = lines[1][..48]+" /...";
      headlines += ({ mkmapping(full_names, lines) });
    }
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:     %s\n"
		 "URL:       %s\n"
		 "Posted by: %s\n"
		 "Date:      %s\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->author,hl->date
		 );
}
