/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
//import "..";
import Headlines;

//#include "../base.pike"
#include <headlines/base.h>

constant name = "centraleurope";
constant site = "Central Europe";
constant url  = "http://www.centraleurope.com/";
constant path = "ticker.dat";

array names = ({ "title", });
array titles = ({ "Headline" });
constant sub = "News";

array headlines;
  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  string url, title;
  while(sscanf(data, "%s | %s\n%s", title, url, data) == 3)
    headlines += ({ ([ "url": url, "title": title])  });
}

string entry2txt(mapping hl)
{
  return sprintf("Title: %s\n"
		 "URL:   %s\n\n",
		 hl->title||"None", HTTPFetcher()->encode(hl->url||""));
}
