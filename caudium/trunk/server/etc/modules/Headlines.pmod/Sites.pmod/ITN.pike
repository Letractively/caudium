/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import Headlines;

#include <headlines/base.h>

constant name = "itn";
constant site = "ITN";
constant url  = "http://www.itn.co.uk/";
constant path = "news_ticker/ticker_text.txt";

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
  while(sscanf(data, "%s\n%s\n%s", title, url, data) == 3)
    headlines += ({ ([ "url": url, "title": title])  });
}

string entry2txt(mapping hl)
{
  return sprintf("Title: %s\n"
		 "URL:   %s\n\n",
		 hl->title||"None", HTTPFetcher()->encode(hl->url||""));
}
