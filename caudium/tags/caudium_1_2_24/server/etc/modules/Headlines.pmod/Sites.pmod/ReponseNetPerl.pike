/*
 * Reponsenet.Com Perl Articles
 */

import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "reponsenetperl";
constant site = "Reponse Net Perl";
constant url  = "http://perl.reponsenet.com/";
constant path  = "rss.xml?site=perl";

constant names = ({ "title", "time", "description" });
constant titles = ({" Application ", " Date ", " Description " });

constant sub = "Computing/Languages";
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
