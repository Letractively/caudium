
string cvs_version = "$Id$";

#include <module.h>

inherit "module";
inherit "caudiumlib";
inherit "socket";

constant module_type = MODULE_PROXY | MODULE_LOCATION;
constant module_name = "Simple HTTP-Proxy";
constant module_doc = "This is a complete rewrite of the proxy module. "
                      "It currently does NOT cache, does not allow for "
                      "external filters, and does not allow for proxy "
                      "redirection.<br />\n"
                      "it can be used either as an HTTP proxy, or with "
                      "the redirect module to transparently 'mount' "
                      "other websites in your tree";
constant module_unique = 0;

array status_requests = ({ });

#define VPROXY_DEBUG

#define WANT_HEADERS /* needs to be defined to get returned error code */

#if __VERSION__ < 7.2
#ifdef VPROXY_DEBUG
void VDEBUG (string x, mixed ... args)
{
   report_error ("VPROXY: " + x + "\n", @args);
}
#else
void VDEBUG (mixed ... args)
{
}
#endif
#else
#ifdef VPROXY_DEBUG
#define VDEBUG(X, args...) report_error ("VPROXY: " + X + "\n", ## args)
#else
#define VDEBUG(X, args...)
#endif 
#endif

void create ()
{
   set_module_creator ("eric lindvall <eric@5stops.com>");

   defvar ("mountpoint", "http:/", "Location", TYPE_LOCATION | VAR_MORE,
           "the mountpoint of your proxy on your virtual filesystem.<br><br>"
           "don't forget to set the \"<b>Proxy security</b>\" settings "
           "under <b>Builtin Variables</b>.");

}

string info ()
{
   return (module_doc);
}

string comment ()
{
   return (QUERY (mountpoint));
}

string query_location ()
{
   return (QUERY (mountpoint));
}

string status ()
{
   string res = "";

   VDEBUG ("status_requests = %O\n", status_requests);

   foreach (status_requests, object req)
   {
      if (objectp (req))
      {
         res += req->status () + "<br />\n";
      }
   }

   if (res == "")
      res = "<br />no current connections<br />\n";

   return ("<font size=\"1\">" + res + "</font>");
}

mapping find_file (string file, object id)
{
   object r = request (id, this_object ());
   VDEBUG ("find_file on %s", id->raw_url);

   return (http_pipe_in_progress ());
}

class request
{
   object id;
   object parent;
   object con;
   string host;
   int port;
   string host_header;

   string file;
   string userpass;
   object rpipe;
   int original_length;
   string buffer = "";

#ifdef WANT_HEADERS
   int found_server_headers = 0;
   string server_headers = "";
   int returned_error_code = 0;
#endif

   int bytesent = 0;
   int start_time = time ();

   void create (object _id, object _par)
   {
      id = _id;
      parent = _par;

      parent->status_requests += ({ this_object () });
      VDEBUG ("create::status_requests = %O\n", parent->status_requests);

      id->do_not_disconnect = 1;

      parse_url ();

      connect_to_server ();
   }

   void parse_url ()
   {
      string query = id->raw_url[sizeof (QUERY (mountpoint)) ..];

      while (query[0] == '/')
         query = query[1..];

      string not_file;

      if (sscanf (query, "%[^/]/%s", not_file, file) != 2)
      {
         not_file = query;
         file = "";
      }

      not_file = http_decode_string (not_file);

      if (sscanf (not_file, "%[^:]:%d", host, port) != 2)
      {
         host = not_file;
         port = 80;
      }

      sscanf (host, "%s@%s", userpass, host);

      if (port != 80)
         host_header = sprintf ("%s:%d", host, port);
      else
         host_header = host;
   }

   void connect_to_server ()
   {
      async_connect (host, port, connected_to_server);
   }

   void connected_to_server (object _con)
   {
      VDEBUG ("connected_to_server ()");

      con = _con;

      if (!id)
      {
         if (con)
         {
            con->set_blocking ();
            con->close ();
            destruct (con);
         }

         return;
      }

      if (!objectp (con))
      {
         VDEBUG ("no con for %s:%d", host, port);
         return_error (503, sprintf ("DNS resolution of %s failed", host));
         return;
      }

      if (!con->query_address ())
      {
         VDEBUG ("connection refused for %s:%d", host, port);
         return_error (503, sprintf ("The connection to %s failed", host_header));
         return;
      }

      con->set_id (0);
      con->set_nonblocking (0, send_request, completed);
      return;
   }

   void return_error (int errno, string error_message)
   {
      id->misc->error_code = errno;
      id->misc->error_message = error_message;

      mapping error = id->conf->http_error->process_error (id);

      id->conf->log (([ "error":errno ]), id);

      id->end (sprintf ("%s %d %s\r\n"
                        "Content-type: %s\r\n"
                        "Content-Length: %d\r\n\r\n%s", 
                        id->prot, error->error, id->errors[errno],
                        error->type, error->len, error->data));
      return;
   }

   void send_request ()
   {
      VDEBUG ("send_request ()");

      con->set_write_callback (0);

      string head = replace (id->raw , "\r\n", "\n");

      int s;
      if ((s = search (head, "\n\n")) >= 0)
         head = head[..s];

      array headers = head / "\n" - ({ "" });

      headers = headers[1..];

      headers = filter (headers, filter_host);

      headers += ({ sprintf ("Host: %s", host_header) });

      head = headers * "\r\n";

      string request = sprintf ("%s /%s %s\r\n"
                                "%s\r\n\r\n%s", id->method, file, id->prot, head, id->data || "");

      con->write (request);

#ifdef WANT_HEADERS
      con->set_nonblocking (got_data, 0, completed);
#else
      nbio (con, id->my_fd, completed);
#endif

#ifdef EXTRA_DEBUG
      VDEBUG ("request: %s--\n", request);

      VDEBUG ("finished with send_request ()");
#endif
   }

#ifdef WANT_HEADERS
   void parse_server_headers ()
   {
      if (found_server_headers != 1)
         return;

      sscanf (server_headers, "%*s %d %*s\n", returned_error_code);
   }
#endif

   int filter_host (string elem)
   {
      if (lower_case (elem)[0..4] == "host:")
         return (0);
      return (1);
   }

#ifdef WANT_HEADERS
   void got_data (mixed dummy, string s)
   {
      if (strlen (s))
      {
         if (found_server_headers == 0)
         {
            int i;

            server_headers += s;

            if ((i = search (server_headers, "\r\n\r\n")) != -1)
            {
               found_server_headers = 1;
               server_headers = server_headers[..i - 1];
            } 
            else if ((i = search (server_headers, "\n\n")) != -1)
            {
               found_server_headers = 1;
               server_headers = server_headers[..i - 1];
            }

            if (found_server_headers == 1)
               parse_server_headers ();

            bytesent += strlen (s);
            buffer += s;
            id->my_fd->write (s);

            if (found_server_headers == 1)
            {
                VDEBUG ("server headers:\n%s\n--\n", server_headers);
                nbio (con, id->my_fd, completed);
            }
         }
         else
         {
            nbio (con, id->my_fd, completed);
         }
      }
   }
#endif

   void nbio (object from, object to, function(:void)|void callback)
   {
      rpipe = caudium->pipe ();
      rpipe->input (from);
      rpipe->set_done_callback (callback);
      rpipe->output (to);
   }

   void completed ()
   {
      VDEBUG ("completed ()");

      if (con)
      {
         con->set_blocking ();
         con->close ();
         destruct (con);
      }

      if (objectp (rpipe) && functionp (rpipe->bytes_sent))
         bytesent += rpipe->bytes_sent ();

      if (id)
      {
         if (returned_error_code == 0)
            returned_error_code = 200;

         id->conf->log (([ "error":returned_error_code,
                           "len":bytesent ]), id);

         id->end ();
      }

      float timesince = time(start_time);
      if (timesince <= 0.0)
         timesince = 1.0;

      float bps = bytesent / timesince;

      VDEBUG ("sent %s in %.2f seconds - %s/s", sizetostring (bytesent), timesince, sizetostring ((int)bps));

      VDEBUG ("done with connection");

      parent->status_requests -= ({ this_object () });
      VDEBUG ("completed::status_requests = %O\n", parent->status_requests);

      destroy ();
   }

   string status ()
   {
      string ret = "";

      int bytes = bytesent;

      if (objectp (rpipe) && functionp (rpipe->bytes_sent))
         bytes  += rpipe->bytes_sent ();

      int timesince = time (1) - start_time;
      if (timesince < 1)
         timesince = 1;

      int bps = bytes / timesince;

      ret = sprintf ("%s -&gt; %s sent %s at %s/s", host_header, id->remoteaddr, sizetostring (bytes), sizetostring (bps));

      return (ret);
   }

   void destroy ()
   {
      parent->status_requests -= ({ this_object () });
      VDEBUG ("destroy::status_requests = %O\n", parent->status_requests);
      VDEBUG ("destroy (%s)", host_header);
   }

   string _sprintf ()
   {
     return (sprintf ("simple_proxy::request (http://%s/%s)", host_header||"N/A", file||""));
   }
};
