/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>

constant name = "slashdot";
constant site = "Slashdot.org";
constant url = "http://slashdot.org/";
constant path = "slashdot.xml";

constant names = ({ "title", "author", "topic", "time", "comments" });
constant titles = ({" Title ", " Author ", " Topic ", " Date ", " #C " });

constant sub = "Computing/General";

array headlines;

static private string parse_it(string tag, mapping args,
			       string|int contents, mapping hl)
{
  switch(tag)
  {
  case "story":
    hl = ([]);
    parse_html(contents, ([ ]), ([ "title": parse_it, "url": parse_it,
				   "time": parse_it,	"author": parse_it,
				   "department": parse_it, "topic": parse_it,
				   "comments": parse_it, "section": parse_it,
				   "image": parse_it,  ]), hl);
    headlines += ({ hl });
    break;

  case "comments":
    hl[tag] = (int)contents;
    break;
  default:
    hl[tag] = trim(contents);
    break;
  }
  return "";
}
  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  parse_html(data, ([]), (["story" : parse_it ]) );
}

string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "Author:   %s\n"
		 "Dept:     %s\n"
		 "Topic:    %s\n"
		 "Section:  %s\n"
		 "Comments: %d\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time, hl->author||"",
		 hl->department||"N/A", hl->topic ||"N/A",
		 hl->section ||"N/A", hl->comments
		 );
}
