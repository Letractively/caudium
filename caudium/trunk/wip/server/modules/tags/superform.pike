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
        "::int::\t^[0-9]+$\n"
        "::float::\t^[0-9]+[.][0-9]+$\n"
        "::email::\t^[a-zA-Z0-9]+[-+a-zA-Z0-9._]*@[-a-zA-Z0-9.]+\\.[a-zA-Z][a-zA-Z]+$\n"
        "::domain::\t[-a-zA-Z0-9.]+\\.[a-zA-Z][a-zA-Z]+$\n"
        "::money::\t^[0-9]+[.][0-9][0-9]$\n"
        "::login::\t[-a-zA-Z0-9._]+$\n",
        "Predefined Regular expressions", TYPE_TEXT_FIELD,
        "In the match strings each of the fixed strings on the left will "
        "be replaced with the regular expression on the right before "
        "carrying out any pattern matching.  A single tab should be used as "
        "a separator.  N.B. Pike regexps are slightly different to those in "
        "some other languages (e.g. perl)");
}

string replace_predefined(string match) 
{
  array regexps=QUERY(regexps)/"\n";
  foreach(regexps,string p) {
    if (sizeof(p/"\t")!=2) continue;
    match=replace(match, (p/"\t")[0], (p/"\t")[1]);
  }
  return match;
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
    if (Regexp(pattern)->match(id->variables[args->name]))
          match = id->variables[args->name];
  };
  if (catcherror) 
    result+=message("Bad regular expression ", pattern);
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

