/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import "..";

#include "../base.pike"

constant site = "BeOS Central";
constant url  = "http://www.beoscentral.com/";
//constant path = "powerbosc.txt";
constant path = "editorials.php";
constant full_names =  ({ "title", "url", "time", "email", "author" });
constant names =  ({ "title", "time", "author" });
constant titles =  ({ "Title", "Date", "Author" });

constant sub = "Computing/BeOS";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  foreach(data / "%%", string s)
  {
    array lines = s / "\n" - ({""});
    if(sizeof(lines) == 3) {
      string date, author, email;
      if(sscanf(lines[2], "%s, contributed by <a href=\"%s\">%s</a>",
		date, email, author) != 3) 
	if(sscanf(lines[2], "Posted %s by %s @%s",
		  date, author, email) == 3) {
	  date += email;
	  email = 0;
	}
      catch(sscanf(email, "mailto:%s", email));
      if(date)
	lines[2] = date;
      lines += ({email ||"", author||"Unknown" });
      headlines += ({ mkmapping(full_names, lines) });
    }
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "Author:   %s%s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 hl->time, hl->author||"Unknown",
		 hl->email ? " ("+hl->email+")":"",
		 );
}
