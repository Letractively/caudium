/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import "..";

#include "../base.pike"

constant site = "MattsHouse.com";
constant url  = "http://www.mattshouse.com/";
constant path = "ultramode.txt";
constant full_names =
({ "title", "url", "time", "author", "siteurl", "comments",
   "section", "image" });
constant names = ({ "title", "time", "author" });
constant titles = ({ "Title", "Date", "Author" });

constant sub = "Computing/General";
array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach(data / "%%", string s)
  {
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 8)
      headlines += ({ mkmapping(full_names, lines) });
  }
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
		 hl->time, hl->author||"",
		 );
}


