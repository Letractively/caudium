/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import Headlines;

#include <headlines/base.h>

constant name = "themes";
constant site = "Themes.Org";
constant url  = "http://themes.org/";
constant path = "textnews.cgi";
constant names =  ({ "title", "site", "date", "author" });
constant titles = ({  " Title ", " Site ", " Date ", " Author " });
constant disabled = 1;
constant sub = "Computing/General";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%")[1..], string s)
  {
    array lines = (s - "\r") / "\n" - ({""});
    if(sizeof(lines) == 6)
      lines = lines[1..];
    if(sizeof(lines) == 5)
      headlines += ({ mkmapping(({ "site", "title", "url", "date", "author" }),
				lines) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:  %s\n"
		 "Site:   %s\n"
		 "URL:    %s\n"
		 "Date:   %s\n"
		 "Author: %s\n\n",
		 hl->title||"None", hl->site,
		 HTTPFetcher()->encode(hl->url||""),
		 hl->date, hl->author||"");
}

