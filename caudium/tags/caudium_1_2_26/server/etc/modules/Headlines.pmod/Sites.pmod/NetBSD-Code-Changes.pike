/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "netbsdcodechanges";
constant site = "FreeBSD Code Changes";
constant url  = "http://www.netbsd.org/";
constant path  = "Changes/rss-netbsd-internals.xml";

constant names = ({ "title", "time" });
constant titles = ({" Application ", " Date " });

constant sub = "Computing/OperatingSystems";
array headlines;

string entry2txt(mapping hl)
{
  return sprintf("Program: %s\n"
		 "URL:     %s\n"
		 "Date:    %s\n\n",
		 hl->title||"None", HTTPFetcher()->encode(hl->url||""),
		 hl->time);
}

private static void parse_reply(string data)
{
  rdf_parse_reply(data);

  foreach(headlines, mapping hl) {
    array tmp = hl->url / "/";
    hl->time = ctime((int)tmp[-1])[4..23];
  }
}
