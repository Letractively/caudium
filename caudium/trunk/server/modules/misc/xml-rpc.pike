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
 *     - Rewrote most of the code and use Protocols.XMLRPC (David Gourdelier,  2004-03-20)
 *     -fixed array type handling (pit, 2001-03-30)
 *     -class framework (pit, 2001-03-30)
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
"<li><b>mapping(string:string) query_rpc_functions_help()</b>: This function is optional and returns a mapping that map the function name available from XML-RPC (the index) to the function help.</li></ul>"
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
      mapping functions = provider->query_rpc_functions();
      foreach(indices(functions), string fname)
      {
        out += "<tr><td>" + fname + "</td><td>" + rpcsystem->methodHelp(fname) + "</td></tr>";
      }
      out += "</table><br/>";
    }
  }
  else
    out += "No providers are available";
  return out;
}

// manage fault and exceptions
private mapping fault(int fault_code, array backtrace)
{
  if(QUERY(report_faults))
    report_error(describe_backtrace(backtrace));
  string xmlResult = Protocols.XMLRPC.encode_response_fault(fault_code, backtrace[0]);
  return Caudium.HTTP.string_answer(xmlResult, "text/xml"); 
}

// return all the XML-RPC providers
private array(object) get_xmlrpc_providers()
{
  return my_configuration()->get_providers("XML-RPC");
}

// return all functions which we can call using XML-RPC
private mapping(string:function) get_functions()
{
  mapping functions = ([ ]);
  array rpc_providers = get_xmlrpc_providers();
  if(rpc_providers && sizeof(rpc_providers))
  {
    foreach(rpc_providers, mixed provider) {
      functions += provider->query_rpc_functions();
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
  return functions;
}

mapping|Stdio.File|void find_file( string path, object id )
{
  function    call;
  string xmlResult;
  mixed callResult;
  string     fcall;
  mixed       args;
  object      Call;
  mixed        err;

  // if request is not xml, return a normal error string
  if(id->request_headers["content-type"] != "text/xml")
    return Caudium.HTTP.string_answer("<html><body>Your request must be a text/xml type request, this is a XML-RPC server.</html></body>", "text/html");
  array internal_error = catch {
    Call  = Protocols.XMLRPC.decode_call(id->data);
    fcall = Call->method_name;
    args  = Call->params;

    array external_error;
    mapping functions = get_functions();
    if(sizeof(functions))
      for(int i = 0; i < sizeof(functions); i++) {
	    call = functions[fcall];
	    if (functionp(call)) {
	      external_error = catch {
		 callResult = call(@args);
	      };
	      if (external_error)
		return fault(2, external_error);
	      xmlResult = Protocols.XMLRPC.encode_response(({ callResult }));
	      return Caudium.HTTP.string_answer(xmlResult, "text/xml");
	    }
       }
  };
  if (internal_error)
    return fault(1, internal_error);
  // default case, unknow method
  internal_error = catch(throw(({ "Unknown method: '" + fcall + "'\n", backtrace() })));
  return fault(3, internal_error);
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
   http://xmlrpc.usefulinc.com/doc/reserved.html */
string query_provides()
{
  return "XML-RPC";
}

mapping query_rpc_functions()
{
  object syst = RPCSystem();
  return ([ "system.listMethods": syst->listMethods,
	    "system.methodHelp": syst->methodHelp
	 ]);
}

mapping query_rpc_functions_help()
{
  return ([ "system.methodHelp": "Returns help text if defined for the method passed, otherwise returns an empty string",
            "system.listMethods": "This method lists all the methods that the XML-RPC server knows how to dispatch"
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

};
