/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
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
 */
/*
 * $Id$
 */

//! This module will handle all HTTP related things.

//!  Return the specified date (as returned by time()) formated in the 
//!  commong log file format, which is "DD/MM/YYYY:HH:MM:SS [+/-]TZTZ".
//! @param t
//!  The time in seconds since 00:00:00 UTC, January 1, 1970. If this
//!  argument is void, then the function will return the current date
//!  in common log format.
//! @returns
//!  The date in the common log file format
//! @example
//!  Pike v7.4 release 10 running Hilfe v3.5 (Incremental Pike Frontend)
//!  > Caudium.HTTP.cern_date();
//!  (1) Result: "16/Feb/2003:23:38:48 +0100"
//! @note
//!  Non RIS code, handled by _Caudium C module.
//! @seealso
//!   @[Caudium.cern_http_date]
string cern_date(int|void t) {
   return Caudium.cern_http_date(t);
}

//!  Return the specified date (as returned by time()) formated in the
//!  HTTP-protocol standart date format, which is "Day, DD MMM YYYY HH:MM:SS GMT"
//!  Used in, for example, the "Last-Modified" header.
//! @param t
//!  The time in seconds since the 00:00:00 UTC, January 1, 1970. If this
//!  argument is void, then the function will return the current date in
//!  HTTP-protocol date format.
//! @returns
//!  The date in the common log file format
//! @example
//!  Pike v7.4 release 10 running Hilfe v3.5 (Incremental Pike Frontend)
//!  > Caudium.HTTP.date();
//!  (1) Result: "Sun, 16 Feb 2003 22:41:25 GMT"
//! @note
//!  Non RIS code, handled by _Caudium C module
//! @seealso
//!  @[Caudium.http_date]
string date(void|int t) {
  return Caudium.http_date(t);
}

//! Encodes a query to a string. This protects odd characters
//! like '&' and '#' and control characters, and pack the result
//! together in a HTTP query string.
//!
//! Example:
//! @pre{
//! > Caudium.HTTP.encode_query( (["user":"foo","passwd":"encrypted"]) );
//! (1) Result: "user=foo&passwd=encrypted"
//! > Caudium.HTTP.encode_query( (["foo":"&&amp;","'=\"":"\0\0\0"]) );
//! (2) Result: "foo=%26%26amp%3B&%27%3D%22=%00%00%00"
//! @}
//!
//! @param variables
//!   mapping of string variables to encode to
//!
//! @returns
//!   query string encoded according to RFC 2396
//!  
string encode_query(mapping(string:int|string) variables)
{
  return Array.map((array)variables,
           lambda(array(string|int|array(string)) v)
           {
             if (intp(v[1]))
               return Caudium.http_encode(v[0]);
             if (arrayp(v[1]))
               return map(v[1], lambda (string val) {
                          return 
                            Caudium.http_encode(v[0])+"="+
                            Caudium.http_encode(val);
                        })*"&";
             return Caudium.http_encode(v[0])+"="+Caudium.http_encode(v[1]);
           })*"&"; 
}

//! 
//! Converts the file result sent in the @[file] argument to a HTTP
//! response header (what you would get for a HEAD request on the
//! resource.
//!
//! @param file
//!   The file mapping (this is what @[http_string_answer()] etc. generate).
//!
//! @param id
//!   The request object.
//!
//! @returns
//!   The HTTP header string.
//!
string http_res_to_string( mapping file, object id )
{
  mapping heads=
    ([
      "Content-type":file["type"],
      "Server":id->version(), 
      "Date":Caudium.HTTP.date(id->time)
      ]);
    
  if(file->encoding)
    heads["Content-Encoding"] = file->encoding;
    
  if(!file->error) file->error = 200;
    
  if(!zero_type(file->expires)) 
    heads->Expires = file->expires ? Caudium.HTTP.date(file->expires) : "0";

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=id->misc->stat))
	file->stat = (array(int))file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];
      
      heads["Last-Modified"] = Caudium.HTTP.date(fstat[3]);
    }
    if(stringp(file->data)) 
      file->len += strlen(file->data);
  }

  if(mappingp(file->extra_heads)) 
    heads |= file->extra_heads;

  if(mappingp(id->misc->moreheads))
    heads |= id->misc->moreheads;
    
  array myheads=({id->prot+" "+(file->rettext||errors[file->error])});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach(heads[h], string tmp)
	myheads += ({ `+(h,": ", tmp)});
    else
      myheads +=  ({ `+(h, ": ", heads[h])});
  

  if(file->len > -1)
    myheads += ({"Content-length: " + file->len });
  string head_string = (myheads+({"",""}))*"\r\n";

  if(id->conf) {
    id->conf->hsent+=strlen(head_string||"");
    if(id->method != "HEAD")
      id->conf->sent+=(file->len>0 ? file->len : 1000);
  }
  if(id->method != "HEAD")
    head_string+=(file->data||"")+(file->file?file->file->read(0x7ffffff):"");
  return head_string;
}

//!   Return a response mapping with the error and data specified. The
//!   error is in fact the status response, so @tt{200@} is @i{HTTP Document
//!   follows@}, and @tt{500@} @i{Internal Server error@}, etc. The content
//!   type will always be @tt{text/html@}
//!
//! @param errno
//!   The HTTP error code to use in the reply.
//!
//! @param data
//!   The data to return.
//!
//! @param dohtml
//!   If != 0 then use a valid HTML document as an answer.
//!
//! @returns
//!   The HTTP response mapping.
mapping http_low_answer( int errno, string data, void|int dohtml )
{
  if(!data) data="";
#ifdef HTTP_DEBUG
  report_debug("HTTP: Return code %d (%s)\n",errno, data);
#endif
  string ddata = data;
  
  if (dohtml)
      ddata = make_htmldoc_string(data, sprintf("Error %d", errno));
  
  return 
    ([ 
      "error" : errno,
      "data"  : ddata,
      "len"   : strlen( ddata ),
      "type"  : "text/html",
      ]);
}

//!   Returns a response mapping that tells Caudium that this request
//!   is in progress and that sending of data, closing the connection
//!   and such will be handled by the module. If this is used and you 
//!   fail to close connections correctly, FD leaking will be the result. 
//! @returns
//!   The HTTP response mapping.
mapping http_pipe_in_progress()
{
#ifdef HTTP_DEBUG
  report_debug("HTTP: Pipe in progress\n");
#endif  
  return ([ "file":-1, "pipe":1, ]);
}

//!   Convenience function to use in Caudium modules and Pike scripts. When you
//!   just want to return a string of data, with an optional type, this is the
//!   easiest way to do it if you don't want to worry about the internal
//!   Caudium structures. This function creates a response mapping containing
//!   the RXML parsed data you send to it.
//!
//! @param rxml
//!   The text to RXML parse and return.
//!
//! @param id
//!   The request id object.
//!
//! @param file
//!   An optional file descriptor to return // FIXME //
//!
//! @param type
//!   Optional file type, like text/html or application/octet-stream
//!
//! @returns
//!   The http response mapping with the parsed data.
mapping http_rxml_answer( string rxml, object id, 
                          void|object(Stdio.File) file, string|void type )
{
  rxml = parse_rxml(rxml, id, file);
  return (["data":rxml,
	   "type":(type||"text/html"),
	   "stat":id->misc->defines[" _stat"],
	   "error":id->misc->defines[" _error"],
	   "rettext":id->misc->defines[" _rettext"],
	   "extra_heads":id->misc->defines[" _extra_heads"],
	   ]);
}

//!   Return an error mapping with the current error theme with the specified
//!   error code, name, and message.
//!
//! @param id
//!   The request id object.
//!
//! @param error_code
//!   An optional error code to respond with.
//!
//! @param error_name
//!   Optional error name.
//!
//! @param error_name
//!   Optional error message.
//!
//! @returns
//!   The HTTP response mapping.
mapping http_error_answer(object id, void|int error_code, void|string error_name, void|string error_message)
{
   mixed tmperr;

   if (!error_code)
      error_code = 404;

   if (!error_name)
      error_name = "Not found.";

   if (!error_message)
      error_message = "Not found.";

   id->misc->error_code = error_code;
   id->misc->error_name = error_name;
   id->misc->error_message = error_message;

   tmperr = id->conf->handle_error_request(id);

   if(mappingp(tmperr))
     return (mapping)tmperr;
   else
     return http_low_answer(error_code,error_message);
}
 
//!   Return a response mapping with the text and the specified content type.
//!   If the content type argument is left out, text/html will be used.
//!
//! @param text
//!   The data string.
//!
//! @param type
//!   The optional content type to override the default text/html.
//!
//! @returns
//!   The HTTP response mapping.
mapping http_string_answer(string text, string|void type)
{
#ifdef HTTP_DEBUG
  report_debug("HTTP: String answer (%s)\n",(type||"text/html");
#endif  
  return ([ "data":text, "type":(type||"text/html") ]);
}

private mapping(string:string) doctypes = ([
    "transitional" : "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n\"http://www.w3.org/TR/html4/loose.dtd\">",
    "strict" : "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"\n\"http://www.w3.org/TR/html4/strict.dtd\">",
    "frameset" : "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\"\n\"http://www.w3.org/TR/html4/frameset.dtd\">"
]);

private string docstart = "%s\n<html><head><title>%s</title>%s%s</head><body>%s</body></html>";

//!   Make a nice HTML doc
//! @param contents
//!   Contents of document
//! @param title
//!   The title of document
//! @param meta
//!   Optional mapping with meta names to add into document
//! @param style
//!   Optional style of document. (to be documented)
//! @param dtype
//!   Optional dtype (to be documented)
//! @returns
//!   A well nice HTML docuement
//! @note
//!   Non RIS Code
string make_htmldoc_string(string contents, string title,void|mapping meta,
                           void|mapping|string style, string|void dtype)
{
    string doctype, smetas = "", sstyle = "";
    
    if (dtype && doctypes[dtype])
        doctype = doctypes[dtype];
    else
        doctype = doctypes->transitional;

    //
    // construct the meta tags
    //
    if (meta && sizeof(meta)) {
        foreach(indices(meta), string idx) {
            array(string) attrs = ({});
            mapping m = meta[idx];

            if (m->name && m->http_equiv)
                m_delete(m, "name");
            
            foreach(indices(m), string i)
                attrs += ({ i + "=\"" + m[i] + "\""});

            smetas += sprintf("<meta %s>", attrs * " ");
        }
    }

    //
    // Construct the style definition
    //
    if (style && sizeof(style)) {
      if (mappingp(style)) {
        array(string) styles = ({});
	
        foreach(indices(style), string idx)
          styles += ({ idx + "{" + style[idx] + "}\n" });

        sstyle = sprintf("<style type=\"text/css\">%s</style>",
                         styles * " ");
      } else if (stringp(style)) {
        sstyle = sprintf("<link rel=\"stylesheet\" href=\"%s\" type=\"text/css\">",
                         style);
      } else
        sstyle = "";
    }

    return sprintf(docstart, doctype, (title ? title : ""), smetas, sstyle, contents);
}

//!   Return a response mapping with the 'contents' wrapped up to form a
//!   valid HTML document. The document is always of the 'text/html' type
//!   and you can modify its look (using CSS) and add any meta tags you
//!   find necessary. It is also specify one of the predefined document
//!   types. The generated document is always identified as one following
//!   the HTML 4.01 standard.
//!
//! @param contents
//!   The document body.
//!
//! @param title
//!   The document tile.
//!
//! @param meta
//!   A mapping of meta entries. Each index in the mapping is also a
//!   mapping and describes a single &lt;meta&gt; tag. The indices in the
//!   inner mapping are the attribute names and their value constitutes the
//!   attribute value. If both 'name' and 'http_equiv' indices exist in the
//!   inner mapping, 'http_equiv' is used (to generate the http-equiv) meta
//!   attribute. It is your responsibility to specify attributes that are
//!   valid for the meta tag.
//!
//! @param style
//!   Modifies the document style. Contents of this mapping is coverted to
//!   the style container put in the document head section. Every index in
//!   the mapping is considered to be the classifier and its value the
//!   style assigned to the given classifier. The style is put between
//!   curly braces. If this parameter is a string, then instead of
//!   generating the inline style, this function will create a link to the
//!   URI specified in this parameter.
//!
//! @param dtype
//!   Specifies the name of the document type definition. The following
//!   names are known: 'transitional' (the default), 'strict', 'frameset'.
//!
//! @returns
//!   The HTTP response mapping.
mapping http_htmldoc_answer(string contents, string title,void|mapping meta,
                            void|mapping|string style, string|void dtype)
{
    return http_string_answer(make_htmldoc_string(contents, title, meta, style, dtype));
}

//!   Return a response mapping with the specified file descriptior using the
//!   specified content type and length.
//! @param fd
//!   The file descriptor object. This can be a an ordinary file, a socket etc.
//! @param type
//!   The optional content type to override the default text/html.
//! @param len
//!   The number of bytes of data to read from the object. The default is to
//!   read until EOF
//! @returns
//!   The HTTP response mapping.
mapping http_file_answer(object fd, string|void type, void|int len)
{
  return ([ "file":fd, "type":(type||"text/html"), "len":len ]);
}

// FIXME: do we have to keep that ? - Xavier
constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

//!   URL decode the specified string and return it. This means replacing
//!   the following characters from the %XX format: null (char 0), space, tab,
//!   carriage return, newline, and % ' " # &amp; ? = / : +
//! @param s
//!   The string to decode.
//! @returns
//!   The URL decoded string.
string http_decode_url (string f)
{
  return
    replace (f,
	     ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22", "%23",
	       "%26", "%3f", "%3d", "%2f", "%3a", "%2b", "%3c", "%3e", "%40",
               "%0A", "%0D", "%3F", "%3D", "%2F", "%3A", "%2B", "%3C", "%3E"
	     }),
	     ({"\000", " ", "\t", "\n", "\r", "%", "'", "\"", "#",
	       "&", "?", "=", "/", ":", "+", "<", ">", "@",
               "\n",  "\r",  "?",   "=",   "/",   ":",   "+",   "<",   ">"
             }));
}

//!   Make a configuration cookie. This is is not a function meant to
//!   be used by the average user.
//! @param from
//!   The cookie value to encode and put in the cookie.
//! @returns
//!   The cookie value.
string http_caudium_config_cookie(string from)
{
  return "CaudiumConfig="+Caudium.http_encode_cookie(from)
    +"; expires=" + Caudium.HTTP.date (3600*24*365*2 + time (1)) + "; path=/";
}

//!   Make a unique user id cookie. This is an internal function which is used
//!   to set a cookie for all visitors
//! @returns
//!   The cookie value.
string http_caudium_id_cookie()
{
  return sprintf("CaudiumUserID=0x%x; expires=" +
		 Caudium.HTTP.date (3600*24*365*2 + time (1)) + "; path=/",
		 caudium->increase_id());
}

//!   Prepend the URL with the prestate specified. The URL is a path
//!   beginning with /.
//! @param url
//!   The URL.
//! @param state
//!   The multiset with prestates.
//! @returns
//!   The new URL
static string add_pre_state( string url, multiset state )
{
  if(!url)
    error("URL needed for add_pre_state()\n");
  if(!state || !sizeof(state))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/(" + sort(indices(state)) * "," + ")" + url ;
}

//!   Return a response mapping which defines a redirect to the
//!   specified URL. If the URL begins with / and the ID object is present,
//!   a host name (and the prestates) will be prefixed to the URL. If the
//!   url doesn't begin with /, it won't be modified. This means that you
//!   either need a complete URL (ie http://www.somewhere.com/a/path) or an
//!   absolute url /a/path. Relative URLs won't work (ie path/index2.html).
//! @param url
//!   The URL to redirect to.
//! @param id
//!   The request id object.
//! @returns
//!   The HTTP response mapping for the redirect
mapping http_redirect( string url, object|void id )
{
  if(url[0] == '/')
  {
    if(id)
    {
      url = add_pre_state(url, id->prestate);
      if(id->request_headers->host) {
	string p = ":80", prot = "http://";
	array h;
	if(id->ssl_accept_callback) {
	  // This is an SSL port. Not a great check, but what is one to do?
	  p = ":443";
	  prot = "https://";
	}
	h = id->request_headers->host / p  - ({""});
	if(sizeof(h) == 1)
	  // Remove redundant port number.
	  url=prot+h[0]+url;
	else
	  url=prot+id->request_headers->host+url;
      } else
	url = id->conf->query("MyWorldLocation") + url[1..];
    }
  }
#ifdef HTTP_DEBUG
  report_debug("HTTP: Redirect -> %s\n",Caudium.http_encode_string(url));
#endif  
  return http_low_answer( 302, "") 
    + ([ "extra_heads":([ "Location":Caudium.http_encode_string( url ) ]) ]);
}

//!   Returns a response mapping that tells Caudium that this request
//!   is to be streamed as-is from the specified fd-object (until there is
//!   nothing more to read). This differs from http_pipe_in_progress in that
//!   this function makes Roxen read the data from the specified object and will
//!   close the connection when it's done. With http_pipe_in_progress you are
//!   responsible for writing the content to the client and closing the
//!   connection. Please note that a http_stream reply also inhibits the
//!   sending of normal HTTP headers.
//! @param from
//!   The object Roxen should read data from. This can be any object that
//!   implements the correct functions - read() is _probably_ enough.
//! @returns
//!   The HTTP response mapping.
mapping http_stream(object from)
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}

//!   Returns a http authentication response mapping which will make the
//!   browser request the user for authentication information. The optional
//!   message will be used as the body of the page. 
//! @param realm
//!   The realm of this authentication. This is show in various methods by the
//!   authenticating browser.
//! @param message
//!   An option message which defaults to a simple "Authentication failed.".
//! @param dohtml
//!   An option to make it HTML formated.
//! @returns
//!   The HTTP response mapping.
mapping http_auth_required(string realm, string|void message, void|int dohtml)
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";

  if (dohtml)
      message = make_htmldoc_string(message, "Caudium: Authentication failed");
  
#ifdef HTTP_DEBUG
  report_debug("HTTP: Auth required (%s)\n",realm);
#endif  
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

//!   Returns a http proxy authentication response mapping which will make the
//!   browser request the user for authentication information for use with
//!   a proxy. This is different than the normal auth in that it's meant for
//!   proxies only. The optional message will be used as the body of the page. 
//! @param realm
//!   The realm of this authentication. This is show in various methods by the
//!   authenticating browser.
//! @param message
//!   An option message which defaults to a simple "Authentication failed.".
//! @returns
//!   The HTTP response mapping.
mapping http_proxy_auth_required(string realm, void|string message)
{
#ifdef HTTP_DEBUG
  report_debug("HTTP: Proxy auth required (%s)\n",realm);
#endif  
  if(!message)
    message = "<h1>Proxy authentication failed.\n</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
