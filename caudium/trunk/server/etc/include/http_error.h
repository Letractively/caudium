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

    private mapping default_template =
	//	caudium->IFiles->get( "error://template" ) +
	([ "name" : "default_caudium_error_template",
	   "data" : #string "ERROR.html",
	   "type" : "text/html" ]);

    private mapping template = default_template;


    private mapping extra_help =
	([
	  401 : "You have tried to access a page that is protected by a username & password protection scheme such as htaccess or similar.<br>If you feel that you have recieved this page in error then contact the site administrator for more information.",
	  402 : "You have tried to access a page that is protected by a pay-per-view style protection scheme.<br>If you feel that you have recieved this page in error then please contact the site administrator.",
	  402 : "You have tried to access a page that is protected by a pay-per-view style protection scheme.<br>If you feel that you have recieved this page in error then please contact the site administrator.",
	  403 : "You have tried to access a page that is protected by a username & password protection scheme such as htaccess or similar.<br>If you feel that you have recieved this page in error then contact the site administrator for more information.",
	  404 : "You have tried to access an object that Caudium cannot locate on the virtual filesystem(s).<br>If you feel that this is an error, please contact the site administrator, or the author of the referring page.",
	  405 : "You have requested that Caudium handle a method that it doesn't currently support.<br>I would suggest that you contact your system administrator, or the administrator of this site and figure out what your doing wrong.",
	  408 : "It took to long for the request to finish processing, this is probably because a CGI, or other server side script is taking too long to process.<br>If you feel that this is in error, please contact the site administrator.",
	  410 : "This document is <i>SO</i> gone.",
	  500 : "Something has gone horribly wrong inside the web server (Caudium).<br>This is probably caused by an error in a CGI or other server side script, but can also mean that something is broke.<br>If you feel that you have recieved this page in error then please contact the site administrator.",
	 ]);

    public void set_template( string _template_name, object id ) {
	if ( _template_name == "" ) {
	    // If the template name isnt set in the config interface then
            // make reset it to the default.
	    if ( template->name != "default_caudium_error_template" ) {
		template = default_template;
	    }
	} else {
	    if ( template->name != _template_name ) {
		// If it's been changed then change the error template, else
                // do nothing.
                string data = id->conf->try_get_file( _template_name, id, 0, 1 );
		if ( data == 0 ) {
		    template = default_template;
		} else {
		    template = ([
				 "data" : id->conf->try_get_file( _template_name, id, 0, 1 ),
				 "type" : id->conf->type_from_filename( _template_name ),
				 "name" : _template_name
				]);
		}
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
		    "</h1><br>" +
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

    public mapping handle_error( int error_code, string error_name, mixed error_message, object id ) {
        mapping local_template;
	if ( id == 0 ) {
	    // We don't have a request id object - this is *REALLY* bad!
	    // Someone forgot to buy David a beer, coz this can only happen
            // in the *core*core* server.
	    local_template = default_template;
	} else {
            string ErrorTheme = id->conf->query( "ErrorTheme" );
	    if ( ErrorTheme != template->name ) {
		set_template( ErrorTheme, id );
	    }
	    local_template = template;
	}
	error_code = error_code?error_code:500;
	error_name = error_name?error_name:"Unknown error";
	error_message = error_message?error_message:"An unknown error has occurred - this should never have happenned.";
	error_name = ((int)error_name[0..2] == error_code)?error_name[3..]:error_name;
	string error_page = parse_html( local_template->data, ([ "error" : _tag_error ]), ([ ]), ([ "code" : error_code, "name" : error_name, "message" : error_message ]) );
	error_page = (id?parse_rxml(error_page,id):error_page);
	//return http_low_answer( error_code, (id?parse_rxml(error_page,id):error_page) );
	return
	    ([
	      "error" : error_code,
	      "data" : error_page,
	      "len" : strlen( error_page ),
	      "type" : local_template->type
	     ]);
    }

}

