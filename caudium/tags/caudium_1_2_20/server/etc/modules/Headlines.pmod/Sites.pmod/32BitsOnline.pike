/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "32bitsonline";
constant site = "32BitsOnline.com";
constant url  = "http://www.32bitsonline.com/";
constant path = "backend/latest_feature.txt";
constant sub = "Computing/General";

array names = ({ "title", "date", });
array titles = ({ "Headline", "Date" });

array headlines;
  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  string url, title, date, desc;
  while(sscanf(data, "%s\n%s\n%s\n%s\n%s", title, date, url, desc, data) == 5)
    headlines += ({ ([ "url": url, "title": title,
		       "date":date, "desc":desc])  });
}

string entry2txt(mapping hl)
{
  return sprintf("Title: %s\n"
		 "Date:  %s\n"
		 "URL:   %s\n"
		 "%s\n\n",
		 hl->title||"None", hl->date, hl->url,
		 indent(hl->desc, 7),
		 HTTPFetcher()->encode(hl->url||""));
}
