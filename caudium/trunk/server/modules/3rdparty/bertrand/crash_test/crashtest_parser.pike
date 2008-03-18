#include <module.h>

inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id";

constant module_type = MODULE_PARSER;
constant module_name = "Crash Test: RXML parser";

constant module_doc = "Try to get your caudium crashed with the following: <br>"
  "&lt;a href='mailto:&amp;crash_test.encoded_email:none;'&gt;foo&lt;/a&gt;";

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
	string name = "crash_test";

	string ret = "";

	string get(string entity, object id)
	{
    switch(entity)
    {
      case "encoded_email":
				// > Public.Standards.XML.encode_numeric_entity("foo@domain.tld");
        // (1) Result: "&#102;&#111;&#111;&#64;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#116;&#108;&#100;"
				ret = "&#102;&#111;&#111;&#64;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#116;&#108;&#100;";
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
