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

constant name = "segfault";
constant site = "Segfault.org";
constant url  = "http://segfault.org/";
constant path = "stories.txt";
constant all_names =  ({ "title", "url", "time", "author", "email",  "section" });
constant names =  ({ "title", "time", "author",  "section" });
constant titles =  ({ "Title", "Date", "Author", "Section" });

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
      headlines += ({ mkmapping(all_names, lines) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "Author:   %s (%s)\n"
		 "Section:  %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time, hl->author||"",
		 hl->email||"N/A", hl->section ||"N/A"
		 );
}
