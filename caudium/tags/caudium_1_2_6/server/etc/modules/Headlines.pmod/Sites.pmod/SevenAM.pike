/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "sevenam";
constant site = "7am News on the Net";
constant url  = "http://www.7am.com/";
constant path = "cgi-bin/server2.cgi";

constant names = ({ "section", "source", "title" });
constant titles = ({ " Section ", " Source ", " Title " });

constant sub = "News";

array headlines;
  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data - "\r") / "\n", string l)
  {
    array parts = l / "|";
    if(sizeof(parts) != 5)
      continue;
    headlines += ({ mkmapping( ({ "section", "source", "title", "url" }), parts[1..]) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:   %s\n"
		 "URL:     %s\n"
		 "Source:  %s\n"
		 "Section: %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->source||"",
		 hl->section ||"N/A"
		 );
}

