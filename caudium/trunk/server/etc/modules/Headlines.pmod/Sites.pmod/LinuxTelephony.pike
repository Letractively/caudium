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

constant name = "linuxtelephony";
constant site = "Linux Telephony";
constant url  = "http://www.linuxtelephony.org/";
constant path = "backend/linuxtelnews.txt";
constant names =  ({ "title", "date", });
constant titles =  ({ "Title",  "Date" });

constant sub = "Computing/Linux";

array headlines;

private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

private static void parse_reply(string data)
{
  array entries = Array.map(data / "&&" - ({""}),
			    lambda(string s) {
			      return s / "\n" - ({""});
			    });
  array mnames = entries[0];
  foreach(entries[1..], array e) {
    headlines += ({ mkmapping(mnames, e ) });
    catch {
      headlines[-1]->date = headlines[-1]->date[..18];
    };
  }
}

string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "Date:     %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||hl->link||""),
		 hl->date
		 );
}
