/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by Xavier Beaudouin <kiwi@caudium.net>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "lolix";
constant site = "Lolix";
constant url  = "http://back.lolix.org/";
constant path = "fr/main.php3";
constant names =  ({ "title", "url", "date" });
constant titles =  ({ "title", "url", "date"});
constant full_names = ({ "title", "url", "date" });
constant sub = "Jobs / OpenSource";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%"), string s)
  {
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 3) {
      if(strlen(lines[1]) > 80)
	lines[1] = lines[1][..76]+" /...";
      headlines += ({ mkmapping(full_names, lines) });
    }
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:     %s\n"
		 "URL:       %s\n"
		 "Date:      %s\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->date
		 );
}
