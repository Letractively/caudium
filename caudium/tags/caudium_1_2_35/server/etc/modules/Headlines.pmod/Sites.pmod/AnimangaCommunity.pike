/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "animangacommunity";
constant site = "Animanga Community";
constant url  = "http://community.animearchive.org/";
constant path = "ultra.html";
constant names =  ({ "title", "author", "added","comments" });
constant titles =  ({ "Title", "Posted by", "Added", " #C "});
constant full_names = ({ "url", "title", "author", "added","comments" });
constant sub = "Entertainment/Anime";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%")[1..], string s)
  {
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 5) {
      if(strlen(lines[1]) > 52)
	lines[1] = lines[1][..48]+" /...";
      headlines += ({ mkmapping(full_names, lines) });
    }
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:     %s\n"
		 "URL:       %s\n"
		 "Posted by: %s\n"
		 "Was posted %s and has %s comment(s)\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->author, hl->added, hl->comments
		 );
}
