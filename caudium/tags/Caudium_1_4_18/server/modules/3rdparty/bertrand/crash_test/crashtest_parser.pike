#include <module.h>

inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";

constant module_type = MODULE_PARSER;
constant module_name = "Crash Test: RXML parser";

constant module_doc =
	"<p>Crash your Caudium server putting an unencoded entity "
	"(&amp;crashtest_parser.encoded_email:none;) in an HTML attribute that "
 	"will be RXML-parsed, like:</p>"
  "<p>&lt;a href='mailto:&amp;crashtest_parser.encoded_email:none;'&gt;foo&lt;/a&gt;</p>"
	"<p>Your server will crash, and the page won't be displayed. If enabled, the "
	"watchdog should restart your server immediately.</p>"
	"<p><strong>Warning</strong>: this module is intended for educational "
  "purpose only, eg for monitoring systems testing.</p>";

constant module_unique = 1;
constant thread_safe = 1;



/*******************************************************************************
  Caudium API
*******************************************************************************/

array(object) query_scopes()
{
  return ({ CrashTestScope() });
}



/******************************************************************************
  Module-specific code
******************************************************************************/

class CrashTestScope
{
	inherit "scope";
	string name = "crashtest_parser";

	string ret = "";

	string get(string entity, object id)
	{
    switch(entity)
    {
      case "encoded_email":
				// Real encoded email can be obtained this way:
				// > Public.Standards.XML.encode_numeric_entity("foo@domain.tld");
        // (1) Result: "&#102;&#111;&#111;&#64;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#116;&#108;&#100;"
				werror("Crash Test: RXML parser: CrashTestScope()->get(encoded_email)\n");
				// if encoding is ":none", Pike's Parser.HTML() may crash:
				// This one will:
				//ret = "f&#111;&#111;&#64;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#116;&#108;&#100;";
				// But this one won't
				//ret="&#102;&#111;&#111;&#64;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#116;&#108;d";

				// Will crash:
				//ret = "&nbsp;";
				// Won't:
				ret = "&nbsp;";
				break;

			default:
		}

    // Always return a string, data or empty.
    if(stringp(ret))
      return ret;
    else
      return "";
	}

}
