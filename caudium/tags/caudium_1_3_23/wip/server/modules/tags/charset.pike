#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type   = MODULE_FIRST;
constant module_name   = "Forminput Charset";
constant thread_safe   = 1;
constant module_unique = 1;

constant cvs_version="$Id$";

void create() 
{
}

string charset_test="äöüßÄÖÜß";

mixed first_try(object id)
{
  if(id->variables && id->variables->__charset)
  {
    if(id->variables->__charset!=charset_test)
    {
      if(charset_test==utf8_to_string(id->variables->__charset))
      {
        werror("detected utf8\n");
        foreach(indices(id->variables), string key)
          id->variables[key]=utf8_to_string(id->variables[key]);
      }
      else
        werror("charset detection failed: %s - %s\n", charset_test, id->variables->__charset);
    }
    else
      werror("default charset\n");
    m_delete(id->variables, "__charset");
  }

  return 0;
}
