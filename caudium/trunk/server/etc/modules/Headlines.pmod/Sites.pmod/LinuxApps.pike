/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <include/base.h>

constant name = "linuxapps";
constant site = "Linux Applications";
constant url  = "http://www.linuxapps.com/";
constant path = "backend/detailed.txt";
constant full_names =  ({ "title", "version",
		     "desc", "home", "download", "time", "url" });
constant names =  ({ "title", "version", "time" });
constant titles =  ({ "Title", "Version", "Date" });

constant sub = "Computing/Applications";
array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%\n")[1..], string s)
  {
    array lines = s / "\n";
    if(sizeof(lines) == 9) 
      headlines += ({ mkmapping(full_names, lines[..6]) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Program:     %s %s\n"
		 "AppIndex:    %s\n"
		 "Date:        %s\n"
		 "Homepage:    %s\n"
		 "Download:    %s\n"
		 "Description: %-=65s\n"
		 "\n",
		 hl->title||"None", hl->version||"",
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time, hl->home, hl->download, hl->desc
		 );
}

