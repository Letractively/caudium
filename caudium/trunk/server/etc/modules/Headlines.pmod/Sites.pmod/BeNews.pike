/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import "..";

#include "../base.pike"

constant site = "BeNews";
constant url  = "http://benews.com/";
constant path = "story/headlines/10";
constant names =  ({ "title", "date" });
constant all_names =  ({ "title", "date", "url" });
constant titles =  ({ "Title", "Date" });
constant sub = "Computing/BeOS";


array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  string title, url;
  int tim;
  sscanf(data, "%*s\n%s", data);
  while(sscanf(data, "%s\n%d\n%s\n%s", title, tim, url, data) > 2) {
    array lines = ({ title, ctime(tim)[4..23], url });
    headlines += ({ mkmapping(all_names, lines) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:  %s\n"
		 "URL:    %s\n"
		 "Date:   %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->date);
}

