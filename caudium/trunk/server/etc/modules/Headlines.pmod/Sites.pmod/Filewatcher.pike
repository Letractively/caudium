/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import "..";

#include "../base.pike"

constant site = "GCU Squad";
constant url  = "http://filewatcher.org/";
constant path = "backend/1.0/";
constant names =  ({ "title", "link", "time","author","empty1","empty2","empty3","type","empty" });
constant titles =  ({ "title", "link", "time","author","empty1","empty2","empty3","type","empty" });
constant full_names =  ({ "title", "link", "time","author","empty1","empty2","empty3","type","empty" });
constant sub = "Applications/Filewatcher";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%"), string s)
  {
    //if (search(s,".html") != -1)
    //  s = url + s;
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 9) {
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
