/*
 * Copyright © 1999 Martin Baehr
 * Copyright © 2001 Karl Pitrich
 * Copyright © 2004 The Caudium Group
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *  CHANGELOG:
 *     - Added authentification layer (David Gourdelier, 2004-03-02)
 *     - Rewrote most of the code and use Protocols.XMLRPC (David Gourdelier,  2004-02-20)
 *     - fixed array type handling (pit, 2001-03-30)
 *     - class framework (pit, 2001-03-30)
 */

inherit "module";
inherit "caudiumlib";
#include <module.h>

constant cvs_version = "$Id$";
constant module_type = MODULE_LOCATION|MODULE_PROVIDER;
constant module_name = "XML-RPC Module";
constant module_doc =
"<p>This module accepts XMLRPC requests "
"(see <a href='http://www.xmlrpc.org/'>http://www.xmlrpc.org/</a>) "
" and invokes the appropriate method.</p>"
"<p>For this module to work you need to create your own Caudium module "
"and define the following functions:</p>"
"<ul><li><b>string query_provides()</b>: This function must return the string \"XML-RPC\" to tell this module it is a XML-RPC module."
"<li><b>mapping(string:function) query_rpc_functions()</b>: Returns a mapping. It maps the function name available from XML-RPC (the index) to the real function in Caudium.</li>"
"<li><b>mapping(string:function) query_rpc_auth_functions()</b>: Same as above but contains functions which can only be called using system.authentificate, "
"that means you need a valid login and password to call them. This method is optional.</li>"
"<li><b>mapping(string:string) query_rpc_functions_help()</b>: This function is optional and returns a mapping that map the function name available from XML-RPC (the index) to the function help.</li></ul>"
"<p><i>Note</i>: To return your custom XML-RPC fault code, throw an exception containing an array where the first parameter is an "
"int for the fault code to returned and the second argument is an array whose first argument is the error description and the second "
"is the Pike <i>backtrace()</i> function.</p>"
"<p>You can look at the XML-RPC-Provider: Demo for example.</p>";

void create()
{
  defvar("mountpoint", "/xmlrpc/", "Mount point",
			TYPE_LOCATION,
			"This is where the module will be inserted "
			"in the namespace of your server.");
  defvar("report_faults", 1, "Report faults", TYPE_FLAG,
         "If set to yes, faults will be reported in the Caudium "
	 "subsystem");

  defvar("login", "", "Authentification:Login", TYPE_STRING, "The login to use for authentificating "
  	"clients");

  defvar("password", "", "Authentification:Password", TYPE_STRING, "The password to use for authentificating "
  	"clients");
}

string status()
{
  string out = "";
  array rpc_providers = get_xmlrpc_providers();
  if(rpc_providers && sizeof(rpc_providers))
  {
    out += "<p>This module uses the following Caudium XML-RPC provider modules:</p>";
    object rpcsystem = RPCSystem();
    foreach(rpc_providers, mixed provider)
    {
      out += "<table border=\"1\"><tr><th colspan=\"2\">" + sprintf("%O",provider) + "</th><tr>";
      out += "<tr><td>Method name</td><td>Help</td>";
      if(search(indices(provider), "query_rpc_functions") != -1)
      {
        mapping functions = provider->query_rpc_functions();
        if(functions && sizeof(functions))
          foreach(indices(functions), string fname)
            out += "<tr><td>" + fname + "</td><td>" + replace(rpcsystem->methodHelp(fname), "\n", "<br/>") + "</td></tr>";
      }
      if(search(indices(provider), "query_rpc_auth_functions") != -1)
      {
        mapping functions = provider->query_rpc_auth_functions();
        if(functions && sizeof(functions))
          foreach(indices(functions), string fname)
            out += "<tr><td>" + fname + "</td><td>" + replace(rpcsystem->methodHelp(fname), "\n", "<br/>") + " (Require authentification)</td></tr>";
      }
      out += "</table><br/>";
    }
  }
  else
    out += "No providers are available";
  return out;
}

// manage faults (exceptions)
private mapping fault(int fault_code, array backtrace)
{
  if(QUERY(report_faults))
    report_error(describe_backtrace(backtrace));
  string xmlResult = Protocols.XMLRPC.encode_response_fault(fault_code, (string)backtrace[0]);
  return Caudium.HTTP.string_answer(xmlResult, "text/xml"); 
}

// return all the XML-RPC providers
private array(object) get_xmlrpc_providers()
{
  return my_configuration()->get_providers("XML-RPC");
}

// return all functions which we can call using XML-RPC
// if we are not authentificated
private mapping(string:function) get_functions()
{
  mapping functions = ([ ]);
  array rpc_providers = get_xmlrpc_providers();
  if(rpc_providers && sizeof(rpc_providers))
  {
    foreach(rpc_providers, mixed provider) {
      if(search(indices(provider), "query_rpc_functions") != -1)
        functions += provider->query_rpc_functions();
    }
  }
  return functions;
}

// return all the functions we can access to if we 
// are successfully authentificated
private mapping(string:function) get_auth_functions()
{
  mapping functions = ([ ]);
  array rpc_providers = get_xmlrpc_providers();
  if(rpc_providers && sizeof(rpc_providers))
  {
    foreach(rpc_providers, mixed provider) {
      if(search(indices(provider), "query_rpc_auth_functions") != -1)
        functions += provider->query_rpc_auth_functions();
    }
  }
  return functions;
}

// return the help strings for each functions that provide one
private mapping(string:string) get_functions_help()
{
  mapping functions = ([ ]);
  array rpc_providers = get_xmlrpc_providers();
  if(rpc_providers && sizeof(rpc_providers))
  {
    foreach(rpc_providers, mixed provider) {
      // this method is optionnal
      if(search(indices(provider), "query_rpc_functions_help") != -1)
        functions += provider->query_rpc_functions_help();
    }
  }
  // add a warning telling this function can only be accessed using system.authentificate
  mapping auth_functions = get_auth_functions();
  if(sizeof(auth_functions) && sizeof(functions))
  {
    mapping normal_functions = get_functions();
    foreach(indices(auth_functions), string auth_function)
    {
      if(search(normal_functions, auth_function) == -1)
        foreach(indices(functions), string function_name)
          if(auth_function == function_name)
  	    functions[function_name] += "\nNote: This function can only be called "
  	      "using the system.authentificate method";
    }
  }
  return functions;
}

// really call the functions in the provider module with args arguments
//  functions is the mapping containing the available functions,
//  fcall is the function name to call and args the arguments to give
//  to this function
private mixed callfunction(mapping functions, string fcall, mixed ...args)
{
  mixed callResult;
  for(int i = 0; i < sizeof(functions); i++) 
  {
    function call = functions[fcall];
    if (functionp(call)) {
      array external_error = catch {
	callResult = call(@args);
      };
      if(external_error)
      {
        if (arrayp(external_error) && sizeof(external_error) == 2 && intp(external_error[0]))
          throw(external_error);
        else
  	  throw(({ 2, external_error }));
      }
      return callResult;
    }
  }
  throw(({ 3, ({ "Unknown method: '" + fcall + "'\n", backtrace() }) }));
}

mapping|Stdio.File|void find_file( string path, object id )
{
  string xmlResult;
  string     fcall;
  mixed       args;
  object      Call;
  int         error_code;
  mixed       error_contents;

  // if request is not xml, return a normal error string
  if(id->request_headers["content-type"] != "text/xml")
    return Caudium.HTTP.string_answer("<html><body>Your request must be a text/xml type request, this is a XML-RPC server.</html></body>", "text/html");
  mixed error = catch {
    Call  = Protocols.XMLRPC.decode_call(id->data);
    fcall = Call->method_name;
    args  = Call->params;

    mapping functions = get_functions();
    if(sizeof(functions))
    {
      mixed callresult = callfunction(functions, fcall, @args); 
      xmlResult = Protocols.XMLRPC.encode_response(({ callresult }));
      return Caudium.HTTP.string_answer(xmlResult, "text/xml");
    }
  };
  if (error)
  {
    if(arrayp(error) && sizeof(error) == 2 && intp(error[0]))
    {
      // in this case this is an error we catched explicitly with our own error code
      error_code = error[0];
      error_contents = error[1];
    }
    else
    {
      error_code = 1;
      error_contents = error;
    }
  }
  return fault(error_code, error_contents);
}

string query_location()
{
  return QUERY(mountpoint);
}

array(int) stat_file( string path, object id )
{
  return ({ 0775, // mode
	    ({ 17, -2 })[random(2)], // size/special
	    963331858, // atime
	    963331858, // mtime
	    963331858, // ctime
	    0, // uid
	    0 /* gid */ });
} 

string|void real_file( string path, object id );

array(string)|void find_dir( string path, object id )
{
  return ({ });
}

/* PROVIDER PART, used to provide the system.* functions as described in *
   http://xmlrpc.usefulinc.com/doc/reserved.html
   system.authentificate is not part of it but it seems logical to me to put it
   there
   / vida
   */
string query_provides()
{
  return "XML-RPC";
}

mapping query_rpc_functions()
{
  object syst = RPCSystem();
  return ([ "system.listMethods": syst->listMethods,
	    "system.methodHelp": syst->methodHelp,
	    "system.authentificate": syst->authentificate
	 ]);
}

mapping query_rpc_functions_help()
{
  return ([ "system.methodHelp": "Returns help text if defined for the method passed, otherwise returns an empty string",
            "system.listMethods": "This method lists all the methods that the XML-RPC server knows how to dispatch",
	    "system.authentificate": "This method allow you to call methods that can only be accessed this way."
	        " For this to work you must give it a string login, string password, string function2call and "
		"an array of arguments. You'll be authentificated using login and password and if it is "
		"successfull, function2call will be called with the array of arguments"
	  ]);
}

// the class that handle system.* XMLRPC methods
class RPCSystem {

  array listMethods()
  {
    return sort(indices(get_functions()));
  }

  string methodHelp(string method)
  {
    mapping functions_help = get_functions_help();
    if(functions_help[method])
      return functions_help[method];
    return "No help available for this function";
  }

  string authentificate(string login, string password, string function2call, mixed ...args)
  {
    if(!login || !password || !function2call)
      throw(({ 4, ({ "You must call this function with a login, password and function2call strings", backtrace() }) }));
    if(login == QUERY(login) && password == QUERY(password))
      return callfunction(get_auth_functions(), function2call, @args);
    else
      throw(({ 5, ({ "Sorry dude, authentification failed", backtrace() }) }));
  }
};
