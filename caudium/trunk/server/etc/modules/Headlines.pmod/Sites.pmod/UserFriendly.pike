/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import "..";

#include "../base.pike"

constant site = "User Friendly";
constant url  = "http://www.userfriendly.org/";
constant path  = "/static/index.html";

constant names = ({ "title", "date" });
constant titles = ({ "Headline", "Date" });

constant sub = "Entertainment";

array headlines;

static private string last_daily;
static private object pixmap;
static private object current_daily_pixmap, old_gdk;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  string image;
  string title, date;
  while(sscanf(data, "%*s<p><font size=-1>Posted:%s</font><br>\n<b>%s</b><br>%s", date, title, data) == 4)
  {
    title = Array.map(title / " ",
		      lambda(string s) {
			return String.capitalize(lower_case(s));
		      }) * " ";
    headlines += ({ ([ "title": title, "date": date ]) });
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Headline: %s\n"
 		 "Date:     %s\n\n",
		 hl->title||"None",  hl->date);
}


