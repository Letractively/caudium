/* Parsing of standard RDF XML files.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

static private string ignore_it(string tag, mapping args, string|int contents,
			       mapping hl)
{
    return "";
}

static private string parse_channel(string tag, mapping args, string|int contents,
			       mapping hl)
{
    report_notice("parse_channel(%O)\n", tag);
    
    switch (tag) {
	case "channel":
	    parse_html(contents, ([]), ([ "link" : parse_channel, "description" : parse_channel,
	                                  "pubDate" : parse_channel, "item" : ignore_it  ]), hl);
	    break;
	    
	default:
	    hl["ch_" + tag] = trim(contents);
	    break;
    }
    
    return "";
}

static private string parse_it(string tag, mapping args, string|int contents,
			       mapping hl, mapping|void chhl)
{
  report_notice("parse_it(%O)\n", tag);
  mixed tmp;
  switch(tag)
  {    
  case "item":
    hl = ([]);
    parse_html(contents, ([ ]), ([ "title": parse_it, "link": parse_it, "description" : parse_it  ]),
	       hl, chhl);
    if (chhl)
	hl += chhl;
    headlines += ({ hl });
    break;

  case "link":
   tag = "url";
  default:
    hl[tag] = trim(contents);
    break;
  }
  return "";
}

private static void rdf_parse_reply(string data)
{
  mapping chhl = ([]);
  
  parse_html(data + " ", ([]), (["channel" : parse_channel ]), chhl );
  parse_html(data + " ", ([]), (["item" : parse_it ]), 0, chhl );
}

  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

