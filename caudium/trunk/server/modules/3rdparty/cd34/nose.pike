// This module was written to allow people running Caudium to overcome 
// certain problems with dynamically generated sites when confronted
// with a search engine.
//
// Typically Search Engines deal with content that is placed closer to
// the top of the HTML, and consequently, with tables, headers, dynamically
// generated content, banners, headers, etc., your content is usually 
// further in the html file, and consequently the fluff ahead is indexed
// before your content.
//
// With these tags, you can put a quick link map in the <se> tag, 
// and can wrap your banners and other information near the top of the 
// page in the <nose> tag so that your page content is more visible.
//
// Another potential use is to hide your meta tags from prying eyes.  Once
// you obtain your good positioning, you can hide the tags that got you
// near the top.  Some Search Engines consider this to be cloaking and
// might ban you for this if you are deemed to be 'spamming' the search
// engine or misleading the engine to get traffic that is not topical
// for your site.
//
// Use with caution.
//
// http://daviesinc.com/modules/

#include <module.h>
inherit "module";
inherit "caudiumlib";

// Module Parser, allows definition of tags, etc.
constant module_type = MODULE_PARSER;
constant module_name = "Search Engine and No Search Engine Containers";
// Note the first \n is where the CIF decides where to wrap for 
// Less Documentation/More Documentation

constant module_doc  = #"Defines two containers that allow you to block or show page content specifically for search engines.\n
<p>Usage:<p>
&lt;se><br>
Content within the &lt;se> container is shown only when the useragent matches<br>
the regexp specified in the Configuration Interface<br>
&lt;/se><br>
<p>
&lt;nose><br>
Content within the &lt;nose> container is shown only when the useragent matches<br>
the regexp specified in the Configuration Interface<br>
&lt;/nose><br>
";
constant module_unique = 1;
constant thread_safe=1;

// define an object for the Regexp so that it doesn't need to be parsed
// every time
object searchengine=0;

void create() {
  defvar("searchengineregexp", 
         "^(Googlebot|Scooter|FAST-WebCrawler|Openfind|Inktomi|Slurp|Infoseek|NationalDirectory|Gigabot|Teradax|metacarta|ah-ha)",
         "Search Engine Regexp", TYPE_STRING,
         "A Pike Regexp that specifies the User Agents that match typical"
         "Search engines<p>" 
         "For Example:<br>"
         "^(Googlebot|Scooter|FAST-WebCrawler|Openfind|Inktomi|Slurp|Infoseek|NationalDirectory|Gigabot|\\(Teradax|metacarta|ah-ha)");
}

void start(int num, object conf) {
  catch {
    if (strlen(query("searchengineregexp")))
      searchengine = Regexp(query("searchengineregexp"));
  };
}

string container_se(string tag, mapping m, string contents, object id)
{
  catch {
    if ( (tag == "se") && (searchengine->match(lower_case((string)id->useragent))) ||
         (tag == "nose") && !(searchengine->match(lower_case((string)id->useragent))) )
      return(contents);

// Note: Evidently you must have a non-zero return or Caudium ignores 
// the callback
    return("");
  };
  
// If for some reason we fail, we always return the contents of the container
  return(contents);
}

mapping query_container_callers()
{
  return ([ "nose":container_se,"se":container_se,
         ]);
}
