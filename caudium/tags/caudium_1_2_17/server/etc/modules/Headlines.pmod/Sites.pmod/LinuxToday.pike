/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "linuxtoday";
constant site = "Linux Today";
constant url  = "http://linuxtoday.com/";
constant path = "lthead.txt";
constant names =  ({ "title", "time" });
constant titles = ({"Title",  "Date"});

constant sub = "Computing/Linux";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "&&")[1..], string s)
  {
    array lines = (s - "\r") / "\n" - ({""});
    if(sizeof(lines) == 3)
      headlines += ({ mkmapping(({ "title", "url", "time" }), lines) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time
		 );
}


