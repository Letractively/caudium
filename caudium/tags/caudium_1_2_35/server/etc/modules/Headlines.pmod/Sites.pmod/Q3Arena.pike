/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "q3arena";
constant site = "Q3 Arena";
constant url  = "http://q3arena.com/";
constant path = "backend.php3";
constant full_names =  ({ "title", "url",
		     "date", "author", "email" });
constant names =  ({ "title", "date", "author" });
constant titles =  ({ "Title", "Date", "Author" });

constant sub = "Entertainment/Computer Games";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach((data / "%%\n")[1..], string s)
  {
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 5) {
      array date = array_sscanf(lines[2], "%*s %d-%d-%d  %d:%d");
      lines[2] = sprintf("%d-%0d-%0d %0d:%0d", @(reverse(date[..2])),
			 @date[3..]);
      headlines += ({ mkmapping(full_names, lines[..6]) });
    }
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:  %s\n"
		 "Date:   %s\n"
		 "URL:    %s\n"
		 "Poster: %s (%s)\n"
		 "\n",
		 hl->title||"None", hl->date||"",
		 HTTPFetcher()->encode(hl->url||""),
		 hl->author, hl->email
		 );
}
