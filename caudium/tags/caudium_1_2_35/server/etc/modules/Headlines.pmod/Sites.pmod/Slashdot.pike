/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "slashdot";
constant site = "Slashdot.org";
constant url  = "http://slashdot.org/";
constant path  = "slashdot.rdf";

constant names = ({ "title" });
constant titles = ({" Application " });

constant sub = "Computing/General";
array headlines;

string entry2txt(mapping hl)
{
  return sprintf("Program: %s\n"
		 "URL:     %s\n",
		 hl->title||"None", HTTPFetcher()->encode(hl->url||""));
}

private static void parse_reply(string data)
{
  rdf_parse_reply(data);

  foreach(headlines, mapping hl) {
    array tmp = hl->url / "/";
    hl->time = ctime((int)tmp[-1])[4..23];
  }
}
