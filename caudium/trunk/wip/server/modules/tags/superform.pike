#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type   = MODULE_PARSER;
constant module_name   = "superform version 2";
constant thread_safe   = 1;
constant module_unique = 1;

void create() 
{

 defvar("regexps",
        "::int:: ^[0-9]+$\n"
        "::float:: ^[0-9]+\\.[0-9]+$\n"
        "::email:: ^[a-zA-Z0-9]+[-+a-zA-Z0-9._]*@[-a-zA-Z0-9.]+\\.[a-zA-Z][a-zA-Z]+$\n"
        "::domain:: [-a-zA-Z0-9.]+\\.[a-zA-Z][a-zA-Z]+$\n"
        "::money:: ^[0-9]+\\.[0-9][0-9]$\n"
        "::login:: [-a-zA-Z0-9._]+$\n",
        "Predefined Regular expressions", TYPE_TEXT_FIELD,
        "If the match string is one of the fixed strings on the left it will "
        "be replaced with the regular expression on the right before "
        "carrying out any pattern matching. "
        "N.B. Pike regexps are slightly different to those in "
        "some other languages (e.g. perl)");
}

mapping regexps_storage=([]);

void start()
{
  string result=check_variable("regexps", QUERY(regexps));
  if(result)
    report_error(result);
}

string check_variable( string s, mixed value )
{ 
  // Check if `value' is O.K. to store in the variable `s'.  If so,
  // return 0, otherwise return a string, describing the error.

  if(s!="regexps")
    return 0;

  string result="";
  array regexps=value/"\n";
  foreach(regexps,string p) 
  {
    string name, value;
    object reg;
    [name, value]= array_sscanf(p, "%s%*[\t ]%s");

    mixed catcherror = catch
    {
      reg=Regexp(value);
    };
    if (catcherror)
    {
      result+=sprintf("%s %s %s<br>\n", name, value, catcherror[0]);
    }
    else
      deep_set(value, regexps_storage, name);
  }
  if(result!="")
  {
    return(message("Bad regular expression")+"<br>\n"+result);
  }
  return 0;
}

string replace_predefined(string match) 
{
  return regexps_storage[match]||match;
}


mapping query_container_callers()
{
  return( ([ "sform":container_sform]));
}

string container_sform(string tag_name, mapping args, string contents,
                       object id, object f,
                       mapping defines, object fd) 
{

  if(args->sqlsource && id->misc->sqlquery && id->misc->sqlquery[args->sqlsource] && sizeof(id->misc->sqlquery[args->sqlsource]))
  { 
    deep_set(id->misc->sqlquery[args->sqlsource][0],
             id, "misc", "sform_values");
  }

  contents=parse_html(contents, ([ "input" : itag_input ]),
                      (["success":icontainer_success]),id);

  return sprintf("<form method=\"%s\">\n%s\n</form>\n", 
                 args->method||"post", contents);
}

string|array(string) itag_input(string tag_name, mapping args,
                                object id, object f, mapping defines, 
                                object fd)
{

  if(!args->value && id && id->variables[args->name])
    args->value=id->variables[args->name];
  else if(id && id->misc->sform_values && !args->value && 
          id->misc->sform_values[args->name])
    args->value=id->misc->sform_values[args->name];

  if(args->type && intputtypes[args->type])
    return ({ intputtypes[args->type](args->type, args, id) 
              || make_tag(tag_name, args) });
  else
    return ({ make_tag(tag_name, args) });
}

mapping intputtypes=([ "bool":type_bool, 
                       "text":type_text,
                     ]);

string type_text(string type, mapping args, object id)
{
  if(!args->match)
    return 0;
  string match;
  string result=make_tag("input", (["name":args->name||"",
                                   "value":args->value||""]));

  string pattern=String.trim_whites(replace_predefined(args->match));

  mixed catcherror = catch 
  {
    match = 0;
    if (Regexp(pattern)->match(args->value||""))
          match = args->value;
  };
  if (catcherror) 
  {
    result+=message("Bad regular expression ", pattern+" "+catcherror[0]);
//    werror("BRE: %O\n%O\n", id->variables, args);
  }
  else if(match)
    return 0;
  else
    result+=message("Invalid input");

  return result;
}


string type_bool(string type, mapping args, object id)
{
  return(make_container("default", (["name":args->name||"", 
                                   "value":args->value||""]), 
           make_container("select", (["name":args->name||""]), 
             make_tag("option", ([ "value":"t" ]))+message("True")+"\n"+
             make_tag("option", ([ "value":"f" ]))+message("False")+"\n")));
}

// dummy function to allow pluggin in internationalization later
string message(string messagekey, string ... args)
{
  // message key will be used to find the right translation.
  // args are untranslated strings to be embedded into the message
  // for now, we just return what we get
  return messagekey+" "+(args*" ");
}

string icontainer_success(string tag_name, mapping args, string contents,
                                 object id, object f, mapping defines,
                                 object fd)
{
  deep_set(contents, id, "misc", "superform", "success");
  return "";
}

void deep_set(mixed val, mixed dest, mixed ... keys)
{
  //   solution suggested by grubba
  foreach(keys[..sizeof(keys)-2], mixed key)
    dest = dest[key] || (dest[key] = ([]));
  dest[keys[-1]] = val;
}

