/* I'm -*-Pike-*-, dude 
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
 */


/*
 * http_error.h
 * ------------
 * This is the class deffinition for the new http error handler.
 * There is no inline doc's - yet. I will add them shortly.
 * It seems to be working correctly and even doesnt crash the server!
 * Template files are in etc/error_templates/ and the new tag <error> is
 * now defined - but only within the scope of http_error_handler.
 */

/*
 **! file: etc/include/http_error.h
 **!  This file implemented a new and improved error handler that let's
 **!  the administrator implement themed error messages on a per-server
 **!  basis.
 */


/*
 **! class: http_error_handler
 **!  This is the new HTTP error handler, which tried to make all the error
 **!  messages look constant and nice in a per-server basis.
 **!  A possible fixme is the need to clear the template file out of the
 **!  on a change. I will look at this in the near future.
 **! name: http_error_handler - new and pretty HTTP error handler.
 */
class http_error_handler {

  inherit "caudiumlib";


#ifdef DEBUG
  int debug = 1;
#else
  int debug = 0;
#endif

  string default_data = #string "ERROR.html";

  private mapping default_template =
  //	caudium->IFiles->get( "error://template" ) +
    ([ "name" : "default_caudium_error_template",
       "type" : "text/html" ]);

  private mapping template = default_template;

  private mapping extra_help =
    ([
      401 : "You have tried to access a page that is protected by a username & password protection scheme such as htaccess or similar.<br>If you feel that you have recieved this page in error then contact the site administrator for more information.",
      402 : "You have tried to access a page that is protected by a pay-per-view style protection scheme.<br>If you feel that you have recieved this page in error then please contact the site administrator.",
      403 : "You have tried to access a page that is protected by a username & password protection scheme such as htaccess or similar.<br>If you feel that you have recieved this page in error then contact the site administrator for more information.",
      404 : "You have tried to access an object that Caudium cannot locate on the virtual filesystem(s).<br>If you feel that this is an error, please contact the site administrator, or the author of the referring page.",
      405 : "You have requested that Caudium handle a method that it doesn't currently support.<br>I would suggest that you contact your system administrator, or the administrator of this site and figure out what your doing wrong.",
      408 : "It took to long for the request to finish processing, this is probably because a CGI, or other server side script is taking too long to process.<br>If you feel that this is in error, please contact the site administrator.",
      410 : "This document is <i>SO</i> gone.",
      500 : "Something has gone horribly wrong inside the web server (Caudium).<br>This is probably caused by an error in a CGI or other server side script, but can also mean that something is broke.<br>If you feel that you have recieved this page in error then please contact the site administrator.",
    ]);

  private mixed my_get_file (string _file, object id) {
    if(!id->conf) return 0;
    object clone_id = id->clone_me (); /* open_file() modifies id */
    clone_id->misc->error_request = 1;
    array f = id->conf->open_file ( _file, "Rr", clone_id);

    if (f[0])
    {
      string data = f[0]->read ();
      f[0]->close ();
      destruct (f[0]);

      return (data);
    }

    return (0);
  }

  private string get_template_data (string _name, object id)
  {
    string data;
    if (_name == "default_caudium_error_template")
      return (default_data);

    if (!id)
      return (default_data);
    string key;
    if(id->conf) {
      key = "error:" + id->conf->name;
    } else {
      key = "error:Global_Variables";
    }
    if (!id->pragma["no-cache"])
    {
      data = cache_lookup (key, _name);

      if (data)
	return (data);
    }

    data = my_get_file (_name, id);

    if (!data)
      data = default_data;

    cache_set (key, _name, data);

    return (data);
  }

  public mapping process_error (object id)
  {
    mapping data;

    array err = catch {
      if (!id->misc->error_code)
      {
	if (id->method != "GET" && id->method != "HEAD" && id->method != "POST")
	{
	  id->misc->error_code = 501;
	  id->misc->error_message = "Method (" + html_encode_string (id->method) + ") not recognised.";
	}
	else
	{
	  id->misc->error_code = 404;
	  if (!id->misc->error_message)
	    id->misc->error_message = "Unable to locate the file: " + id->not_query + ".<br>\n" +
	      "The page you are looking for may have moved or been removed.";
	}
      }
      if (!id->misc->error_message)
	id->misc->error_message = id->errors[id->misc->error_code];
   
      data = handle_error (id->misc->error_code, id->errors[id->misc->error_code], id->misc->error_message, id);
    };

    if (err)
    {
      report_error ("Internal server error:\n" + describe_backtrace(err) + "\n");

      data =  http_low_answer( 500, "<h1>Error: The server failed to fulfill your query due to an " +
			       "internal error in the error routine.</h1>" );
    }

    return (data);
  }

  public void set_template( string _template_name, object id ) {
    if ( _template_name == "" ) {
      // If the template name isnt set in the config interface then
      // make reset it to the default.
      if ( template->name != "default_caudium_error_template" ) {
	template = default_template;
      }
    } else {
      // If it's been changed then change the error template, else
      // do nothing.
      string data = my_get_file (_template_name, id);
      if ( data == 0 ) {
	template = default_template;
      } else {
	template = ([
	  "type" : id->conf ? id->conf->type_from_filename (_template_name) : "text/html",
	  "name" : _template_name
	]);
      }
    }
  }

  private string _tag_error( string tag, mapping args, mapping the_error ) {
    if ( args->code ) {
      return sprintf( "%d", the_error->code );
    } else if ( args->name ) {
      return html_encode_string( the_error->name );
    } else if ( args->description ) {
      if ( extra_help[ the_error->code ] ) {
	return
	  "<h1>" +
	  html_encode_string( the_error->name ) +
	  "</h1>" +
	  extra_help[ the_error->code ] +
	  "<br>";
      } else {
	return
	  "<h1>" +
	  html_encode_string( the_error->name ) +
	  "</h1>" +
	  "There is currently no documentation on this error.<br>";
      }
    } else if ( args->message ) {
      return the_error->message;
    } else if ( args->stamp ) {
      return
	"Generated by " +
	html_encode_string( caudium->version() ) +
	" at " +
	html_encode_string( ctime( time() ) );
    } else if ( args->help ) {
      return
	"<b>Usage: &lt;error <i>arg</i>&gt;</b>\n" +
	"<blockquote>\n" +
	"Where <i>arg</i> is one of the following:<br>\n" +
	"<ul>\n" +
	"<li>code : <i>The error number, such as 404, or 500</i></li>\n" +
	"<li>name : <i>The name of the error, ie &quot;internal server error&quot; or &quot;file not found&quot;</i></li>\n" +
	"<li>description : <i>Extra information about this error</i></li>\n" +
	"<li>stamp : </i>The server version and the current time</i></li>\n" +
	"</ul>\n";
    } else {
      return "";
    }
  }

  public mapping handle_error( int error_code, string error_name, string error_message, object id ) {
    mapping local_template;

    if ( id == 0 ) {
      // We don't have a request id object - this is *REALLY* bad!
      // Someone forgot to buy David a beer, coz this can only happen
      // in the *core*core* server.
      local_template = default_template;
    } else {
      /* check if they want old-style 404 */
      if (id->conf && id->conf->query("Old404") && error_code == 404)
      {
	return http_low_answer (error_code,
				replace (parse_rxml (id->conf->query ("ZNoSuchFile"), id ),
					 ({ "$File", "$Me" }),
					 ({ html_encode_string (id->not_query), 
					    id->conf->query ("MyWorldLocation") })));
      }

      if(id->conf) {
	string ErrorTheme = id->conf->query ("ErrorTheme");
	if (ErrorTheme != template->name) {
	  set_template( ErrorTheme, id );
	}
      }
      local_template = template;
    }

    if (!error_code)
      error_code = 500;

    if (!error_name)
      error_name = "Unknown error";

    if (!error_message)
      error_message = "An unknown error has occurred - this should never have happenned.";

    if ((int)error_name[0..2] == error_code)
      error_name = error_name[3..];

    string error_page = parse_html (get_template_data (local_template->name, id), ([ "error" : _tag_error ]), ([ ]), ([ "code" : error_code, "name" : error_name, "message" : error_message ]));

    if (id)
      error_page = parse_rxml (error_page,id);

    if (error_code > 499 || debug) {
      if (id)
      {
         string url = id->conf->query ("MyWorldLocation");
         if (id->raw_url[0] == '/')
            url += id->raw_url[1..];
         else
            url += id->raw_url;

         report_error (sprintf ("Serving Error %d, %s to client for %s.\n", error_code, error_name, url));
      }
      else
	report_error (sprintf ("Serving error %d, %s to client for a 'core' error:\n%s\n", describe_backtrace (backtrace ())));
    }

    return
      ([
	"error" : error_code,
	"data" : error_page,
	"len" : strlen( error_page ),
	"type" : local_template->type
      ]);
  }
}

