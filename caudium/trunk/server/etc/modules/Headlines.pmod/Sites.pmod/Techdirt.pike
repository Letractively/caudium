/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import Headlines;

#include <headlines/base.h>

constant name = "techdirt";
constant site = "Techdirt";
constant url  = "http://techdirt.com/";
constant path = "ultramode.txt";
constant full_names =
({ "title", "url", "time", "author", "siteurl", "department",
   "image"});
constant names = ({ "title", "author", "time" });
constant titles = ({ "Title", "Author", "Date" });

constant sub = "Computing/General";
array headlines;

private static void parse_reply(string data)
{
  foreach((data / "\n%%\n")[1..], string s)
  {
    array lines = s / "\n";
    if(sizeof(lines) == sizeof(full_names)) {
      headlines += ({ mkmapping(full_names, lines) });
    }
  }
}


string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "Author:   %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time, hl->author||"",
		 );
}


