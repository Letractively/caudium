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

    constant cvs_version = "$Id$"

    inherit "caudiumlib";

    // Cache for the template file.
    private string my_template;
    string template_name;

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

    /*
     **! method: void set_template( string _template_name )
     **!  set_template() open's the specified template file and loads it into
     **!  cache. If it is unable to load the specified template file then it
     **!  attempts to load the default file if that doesn't work. If it is
     **!  still unable to load the file then it uses a hard-coded (and not
     **!  very pretty default page.
     **! arg: string _template_name
     **!  This is the path to the template file in the *real* filesystem.
     **!  This is probably a fixme in that it's possible it should be stored
     **!  in the virtual filesystem.
     **! returns:
     **!  void.
     **! name: set_template - load template file into cache.
     */
    public void set_template( string _template_name ) {
	template_name = _template_name;
	object f;
	if ( catch( f = Stdio.File( "etc/error_templates/" + template_name, "r" ) ) ) {
	    if ( catch( f = Stdio.File( "etc/error_templates/default.html", "r" ) ) ) {
		my_template =
		    "<h1><error code>: <error name></h1><br>" +
		    "<error message><br>" +
		    "<b>Caudium was unable to locate the error template file.</b><br>";
	    } else {
		my_template = f->read();
		f->close();
	    }
	} else {
	    my_template = f->read();
	    f->close();
	}
    }


     private string _tag_error( string tag, mapping args, mapping the_error ) {
         int error_code = the_error->code;
	 string error_name = the_error->name;
	 string error_message = the_error->message;
	 if ( args->code ) {
	     return sprintf( "%d", error_code );
	 } else if ( args->name ) {
	     return html_encode_string( error_name );
	 } else if ( args->description ) {
	    if ( extra_help[ error_code ] ) {
		return
		    "<h1>" +
		    html_encode_string( error_name ) +
		    "</h1>" +
		    extra_help[ error_code ] +
		    "<br>";
	    } else {
		return
		    "<h1>" +
		    html_encode_string( error_name ) +
		    "</h1><br>" +
		    "There is currently no documentation on this error.<br>";
	    }
	 } else if ( args->message ) {
	    return error_message;
	 } else if ( args->stamp ) {
	     return
		 "Generated by " +
                 html_encode_string( caudium->version() ) +
		 " at " +
                 ctime( time() );
	 } else {
	     return "";
	}
     }

    /*
     **! method: handle_error( int error_code, string error_name, mixed error_message, object id )
     **!  This is where the magic happens. This method takes the error supplied
     **!  and runs parse_html over the template file in order to be able to
     **!  replace the response mapping with the error page.
     **!  A possible fixme is that the theme is checked every time there is
     **!  an error, and will change the theme if id->conf->query( "ErrorTheme" )
     **!  has been changed. This can probably be done better.
     **! arg: int error_code
     **!  This is the actual HTTP error code, ie. 404, 500, etc.
     **! arg: string error_name
     **!  This is the short name of the error, ie "Internal Server Error",
     **!  or "File not found".
     **! arg: mixed error_message
     **!  This is the error actually thrown by whatevers broken. This means
     **!  that it can be a string with a 404 message, or an array with a
     **!  backtrace from a broken pike-script for example. I need to be able
     **!  to interpret what to do with it.
     **! arg: object id
     **!  The request information object.
     */
    public mapping handle_error( int error_code, string error_name, mixed error_message, object id ) {
	if ( id->conf->query( "ErrorTheme" ) != template_name ) {
	    set_template( id->conf->query( "ErrorTheme" ) );
	}
	error_code = error_code?error_code:500;
	error_name = error_name?error_name:"Unknown error";
	error_message = error_message?error_message:"An unknown error has occurred - this should never have happenned.";
	// This is a crufty hack to protect from the stupid way http.pike:errors([ ]) is built.
	if ( error_name[ 0..2 ] == sprintf( "%d", error_code ) ) {
	    error_name = error_name[ 3..sizeof( error_name ) ];
	}
	string error_page = parse_rxml( parse_html( my_template, ([ "error" : _tag_error ]), ([ ]), ([ "code" : error_code, "name" : error_name, "message" : error_message ), id );
	return http_low_answer( error_code, error_page );
    }

}
