#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type   = MODULE_PARSER;
constant module_name   = "superform version 2";
constant thread_safe   = 1;
constant module_unique = 1;

constant cvs_version="$Id$";

void create() 
{

 defvar("regexps",
        "::int:: ^[0-9]+$\n"
        "::float:: ^[0-9]+[.,][0-9]+$\n"
        "::email:: ^[a-zA-Z0-9]+[-+a-zA-Z0-9._]*@[-a-zA-Z0-9.]+\\.[a-zA-Z][a-zA-Z]+$\n"
        "::domain:: [-a-zA-Z0-9.]+\\.[a-zA-Z][a-zA-Z]+$\n"
        "::money:: ^[0-9]+[.,][0-9][0-9]$\n"
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
  return( ([ "sform":container_sform ]));
}

string container_sform(string tag_name, mapping args, string contents,
                       object id, object f,
                       mapping defines, object fd) 
{

  id->misc->sform=([]);
  if(args->sqlsource && id->misc->sqlquery && id->misc->sqlquery[args->sqlsource] && sizeof(id->misc->sqlquery[args->sqlsource]))
  { 
    deep_set(id->misc->sqlquery[args->sqlsource][0],
             id, "misc", "sform", "input");
  }

  contents=parse_html(contents, ([ "input" : itag_input ]),
                      (["success":icontainer_success, 
                        "textarea":icontainer_textarea,
                        "select":icontainer_select
                      ]),id);

  //werror("sform: %O\n%O\n", id->raw, id->variables);
  string formcontent=sprintf("errors: %d<br />\nwarnings: %d<br />\n",
                       id->misc->sform->errors, 
                       id->misc->sform->warnings);
  formcontent+=make_tag("input",
                        ([ "type":"hidden", "name":"_sform",
                           "value":"_true" ])
                       );
  formcontent+=contents;
  if(!id->misc->sform->errors)
    formcontent+=id->misc->sform->success;
  return 
    make_container("form", ([ "method":args->method||"post" ]),
                   formcontent);
}

string|array(string) icontainer_textarea(string tag_name, mapping args, 
				         string contents, object id, object f, 
                                         mapping defines, object fd)
{
  if(contents != "")
    args->value=contents;
  return itag_input(tag_name, args, id, f, defines, fd);
}


string|array(string) itag_input(string tag_name, mapping args,
                                object id, object f, mapping defines, 
                                object fd)
{

  // don't touch these
  if((< "submit", "hidden" >)[args->type])
    return 0;

  if(args->value)
  {
    args->formvalue=args->value;
    m_delete(args, "value");
  }
  // keep any hardcoded value as backup

  string output="";
  if(id->variables[args->name])
    args->value=id->variables[args->name];
  else if(!id->variables->_sform &&
          id->misc->sform->input && 
          id->misc->sform->input[args->name])
    args->value=id->misc->sform->input[args->name];
  //else
  //  args->value=args->formvalue;
  // use the hardcoded value only if we are not getting values
  // from elsewhere (not yet tested)

  deep_set(args->value, id, "misc", "sform", "output", args->name);

  if(tag_name=="textarea")
  {
    if(!args->type)
      args->type="text";
    if(inputtypes["textarea_"+args->type] 
       && (output=inputtypes["textarea_"+args->type](args->type, args, id)))
    {}
    else 
      output=make_container(tag_name, args, html_encode_string(args->value));
  }
  else if(args->type && inputtypes[args->type])
    output=inputtypes[args->type](args->type, args, id) 
              || make_tag(tag_name, args);
  else
    output=make_tag(tag_name, args);
  //werror("%O:%O:%s\n", id->misc->sform->input[args->name], args->value, args->value||"");
  return ({ output });
}

mapping inputtypes=([ "bool":type_bool, 
                      "text":type_text,
                      "password":type_password,
                      "checkbox":type_checkbox,
                      "textarea_text":type_textarea,
                     ]);

string type_textarea(string type, mapping args, object id)
{

  string result="";

  if(args->value && sizeof(args->value) < ((int)args->minlength||0)) 
  {
    result+=args->error||message("Value to short");
    id->misc->sform->errors++;
  }
  if(args->value && sizeof(args->value) > (int)args->maxlength && (int)args->maxlength)
  {
    result+=args->error||message("Value to long, truncated to ", args->maxlength);
    id->misc->sform->warnings++;
    args->value=args->value[..(int)args->maxlength-1];
  }
  return make_container("textarea", args, html_encode_string(args->value))+result;
}


string type_password(string type, mapping args, object id)
{
  string result="";

  if(args->value && args->value != "" && 
     sizeof(args->value) < ((int)args->minlength||0))
  { 
    result+=args->error||message("Password to short");
    id->misc->sform->errors++;
  }
  if(args->value && sizeof(args->value) > (int)args->maxlength && args->maxlength)
  { 
    result+=args->error||message("Password to long, browser ignores maxlength, truncated to ", args->maxlength);
    id->misc->sform->warnings++;
    args->value=args->value[..(int)args->maxlength-1];
  }

  if(id->variables->_sform && args->check && args->value!=id->variables[args->check])
  {
    result+=args->error||message("passwords don't match");
    id->misc->sform->errors++;
  }
    
  return make_tag("input", (["name":args->name||"", 
                             "value":"", 
                             "type":"password" ]))+result;
}

string type_text(string type, mapping args, object id)
{
  if(!args->match)
    return 0;

  string match;
  string result=make_tag("input", (["name":args->name||"",
                                   "value":args->value||""]));

  if(args->value && sizeof(args->value) < ((int)args->minlength||0)) 
  {
    result+=args->error||message("Value to short");
    id->misc->sform->errors++;
  }
  if(args->value && sizeof(args->value) > (int)args->maxlength && (int)args->maxlength)
  {
    result+=args->error||message("Value to long, browser ignores maxlength, truncated to ", args->maxlength);
    id->misc->sform->warnings++;
    args->value=args->value[..(int)args->maxlength-1];
  }
  
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
    id->misc->sform->warnings++;
//    werror("BRE: %O\n%O\n", id->variables, args);
  }
  else if(match)
    return 0;
  else
  {
    result+=args->error||message("Invalid input");
    id->misc->sform->errors++;
  }

  return result;
}

string type_checkbox(string type, mapping args, object id)
{
  werror("checkbox %O, %O, %O, %O\n", args, id->variables[args->name], id->misc->sform->input[args->name], id->variables->_sform);
  if(args->value && args->value!="0")
  {
    args->checked="";
  }
  else
  {
    // the box may have been unchecked by the user, so we need to make sure
    // it is listed in id->variables in case that is used as an indicator which 
    // variables have changed.
    id->variables[args->name]=0;
    id->misc->sform->output[args->name]=0;
  }

  args->value=args->formvalue;
  m_delete(args, "formvalue");

  return make_tag("input", args); 
}

string icontainer_select( string tag_name, mapping args, string contents,
                           object id)
{

  if(id->variables[args->name])
    args->value=id->variables[args->name];
  else if(!id->variables->_sform &&
          id->misc->sform->input &&
          id->misc->sform->input[args->name])
    args->value=id->misc->sform->input[args->name];
  //else
  //  args->value=args->formvalue;
  // use the hardcoded value only if we are not getting values
  // from elsewhere (not yet tested)

  deep_set(args->value, id, "misc", "sform", "output", args->name);

  string multi_separator = args->multi_separator || "\000";
  multiset value=(multiset)(args->value/multi_separator);

  array (string) tmp;
  int c;
  
  tmp = contents / "<option";
  for (c=1; c < sizeof( tmp ); c++)
    if (sizeof( tmp[c] / "</option>" ) == 1)
      tmp[c] += "</option>";
  contents = tmp * "<option";
  mapping m = ([ "option" : itag_option ]);
  contents = parse_html( contents, ([ ]), m, value );
  return make_container( tag_name, args, contents );
}

private mixed itag_option( string tag_name, mapping args, string contents,
                                  multiset (string) value )
{
  if (args->value)
    if (value[ args->value ])
      if (args->selected)
        return 0;
      else
        args->selected = "selected";
    else
      return 0;
  else
    if (value[ remove_leading_trailing_ws( contents ) ])
      if (args->selected)
        return 0;
      else
        args->selected = "selected";
    else
      return 0;
  return ({make_container( tag_name, args, contents )});
}

private string remove_leading_trailing_ws( string str )
{
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str ); 
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str );
  return str;
}


string type_bool(string type, mapping args, object id)
{
  //FIXME avoid another round of rxml parsing by aplying the logic from
  //id->conf->parse_module->container_callers->default());

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
                                 object id) 
{
  deep_set(contents, id, "misc", "sform", "success");
  return "";
}

void deep_set(mixed val, mixed dest, mixed ... keys)
{
  //   solution suggested by grubba
  foreach(keys[..sizeof(keys)-2], mixed key)
    dest = dest[key] || (dest[key] = ([]));
  dest[keys[-1]] = val;
}

