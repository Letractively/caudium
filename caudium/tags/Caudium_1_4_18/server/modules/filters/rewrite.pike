#include <module.h>
inherit "module";
inherit "caudiumlib";

constant thread_safe = 1;
constant module_type = MODULE_LAST;
constant module_name = "URL Rewriting";
constant module_doc  = "";
constant module_unique= 0;



/*****************************************************************************
 * Caudium API
 *****************************************************************************/

void create()
{
  defvar(
		"rule",
		"/index.php?%f",
		"Redirect rule",
		TYPE_STRING,
		"Allows %% %u %f %p %q %Q %h");

	defvar(
		"mode",
		"handle_request",
		"File retrieving method",
		TYPE_STRING_LIST,
		"<p>Method to be used for fetching the redirected file</p>"
		"<ul><li><strong>http redirect</strong>: this should be the more robust "
		"one. It uses a temporary (302) HTTP redirect, so that HTTP client won't "
		"forget your original URL.</li>"
		"<li><strong>try_get_file</strong>: this is a the more stealth one, but "
		"not fully tested yet.</li>"
		"<li><strong>handle_request</strong>: as stealth as try_get_file, but "
		"tries to mimic a real HTTP request. The request will be processed by all "
		"modules.</li>"
		"</ul>",
		({"http redirect","try_get_file","handle_request"}));
}


/*****************************************************************************
 * MODULE_LAST API
 *****************************************************************************/

mixed last_resort(object id)
{
	string to = compute_url(id);

	werror("%s -> %s\n", id->raw_url, to);
	
	// Don't loop
	if(to==id->raw_url)
		return 0;

  // HTTP redirect 
	if(QUERY(mode)=="http redirect")
	{
#if constant(Caudium.HTTP.redirect)
		// Caudium 1.4+
	  return Caudium.HTTP.redirect(to, id);
#else
		// Caudium 1.2
		return http_redirect(to, id);
#endif
	}

	// Try get file
	if(QUERY(mode)=="try_get_file")
	{
		string foo = "";
		string s = "";

		string f = Caudium.fix_relative(to, id);

		// Mimic <insert file=""> here
		object nid = id->clone_me();

		/*
		if(m->nocache) {
      id->pragma["no-cache"] = 1;
      NOCACHE();
    }
		*/

    if(sscanf(f, "%*s?%s", s) == 2) {
      mapping oldvars = id->variables;
      nid->variables = ([]);
      if(nid->scan_for_query)
  			f = nid->scan_for_query( f );
      nid->variables = oldvars | nid->variables;
      nid->misc->_temporary_query_string = s;
    }

	/*	
	  if(!mappingp(id->misc))
  	  nid->misc = ([]);

	  nid->misc->tags = 0;
	  nid->misc->containers = 0;
	  nid->misc->defines = ([]);
	  nid->misc->_tags = 0;
	  nid->misc->_containers = 0;
	  nid->misc->defaults = ([]);
*/

//		nid->variables += ([ "id->raw_url":"" ]);

		// fix_relative()?
		foo = nid->conf->try_get_file(f, nid);

		werror("redirect: try_get_file:\n%O\n", foo);

		if(!foo)
		{
			werror("Impossible to get file %s\n", f);
			return 0;
		}

		return Caudium.HTTP.string_answer(foo);	
	}

	/* handle_request */
	if(QUERY(mode)=="handle_request")
	{
		object nid = id->clone_me();

		multiset prestates = (< >);
		multiset internal = (< >);

		string f = Caudium.parse_prestates(to, prestates, internal);
		// TODO: what to do with internal?
		nid->prestate = prestates;

		string q = "";
  	if(sscanf(f, "%s?%s", f, q))
  	{
    	Caudium.parse_query_string(q, nid->variables, nid->empty_variables);
    	foreach(indices(nid->empty_variables), string varname)
      	nid->variables[varname] = "";
    	nid->query=q;
  	}

		nid->not_query=f;
		nid->raw_url=to;

		//TODO: we may lack:
		//  id->raw
		//  id->rest_query

		return id->conf->handle_request(nid);
	}
	

	werror("Unknown redirect method: %O\n", QUERY(mode));

	return 0;
}




/*****************************************************************************
 * Module-specific code
 *****************************************************************************/

string compute_url(object id)
{
//	string url = id->get_canonical_url();
//  url = url[..strlen(url)-2];
	// TODO: id->get_canonical_url(); doesn't work
	string url = id->host;

	string hurl = get_host_url(id);

	// TODO: this code is duplicated from redirect.pike
	// This could be put in a generic pmod
	string to = replace(
		QUERY(rule),
		({ "%%", "%u", "%h", "%f", "%p", "%q", "%Q" }),
		({ "%", url, hurl, ( ({""}) + (id->not_query / "/" - ({""})) )[-1], id->not_query[1..], id->query ? "?"+id->query : "", id->query || "" }));

	werror("rewrite.pike: compute_url: to: %s\n", to);

	return to;
}


// TODO: this code is duplicated from redirect.pike
// This could be put in a generic pmod
string get_host_url(object id)
{
  string url;
  if(id->misc->_host_url) return id->misc->_host_url;
  if(id->misc->host) {
    string p = ":80", prot = "http://";
    array h;
    if(id->ssl_accept_callback) {
      // This is an SSL port. Not a great check, but what is one to do?
      p = ":443";
      prot = "https://";
    }
    h = id->misc->host / p  - ({""});
    if(sizeof(h) == 1)
      // Remove redundant port number.
      url=prot+h[0];
    else
      url=prot+id->misc->host;
  } else {
    url = id->get_canonical_url();
    url = url[..strlen(url)-2];
  }
  return lower_case(id->misc->_host_url = url);
}
