/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

/* $Id$
 *
 * SSL3 (https) protocol
 */

inherit "protocols/http" : http;
inherit "caudiumlib";

mapping to_send;

#include <stdio.h>
#include <caudium.h>
#include <module.h>

// #define SSL3_DEBUG

#if constant(gethrtime)
# define HRTIME() gethrtime()
# define HRSEC(X) ((int)((X)*1000000))
# define SECHR(X) ((X)/(float)1000000)
#else
# define HRTIME() (predef::time())
# define HRSEC(X) (X)
# define SECHR(X) ((float)(X))
#endif

#ifdef PROFILE
#define REQUEST_DEBUG
int req_time = HRTIME();
#endif

//#define REQUEST_DEBUG

#ifdef REQUEST_DEBUG
#define REQUEST_WERR(X)	roxen_perror((X)+"\n")
#else
#define REQUEST_WERR(X)
#endif

#ifdef FD_DEBUG
#define MARK_FD(X) catch{REQUEST_WERR(X); mark_fd(my_fd->query_fd(), (X)+" "+remoteaddr);}
#else
#define MARK_FD(X) REQUEST_WERR(X)
#endif

mapping parse_args(string options)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:parse_args(\"%s\")\n", options));
#endif /* SSL3_DEBUG */
  mapping res = ([]);
  string line;
  
  foreach(options / "\n", line)
    {
      string key, value;
      if (sscanf(line, "%s%*[ \t]%s", key, value) == 3)
	res[String.trim_whites(key)] = String.trim_all_whites(value);
    }
  return res;
}

class roxen_ssl_context {
  inherit SSL.context;
  int port; /* port number */
}

private object new_context(object c)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:new_context(X)\n"));
#endif /* SSL3_DEBUG */
  mapping contexts = caudium->query_var("ssl3_contexts");
  object ctx = roxen_ssl_context();
  
  if (!contexts)
  {
    contexts = ([ c : ctx ]);
    caudium->set_var("ssl3_contexts", contexts);
  }
  else
    contexts[c] = ctx;
  return ctx;
}

private object get_context(object c)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:get_context()\n"));
#endif /* SSL3_DEBUG */
  mapping contexts = caudium->query_var("ssl3_contexts");

  return contexts && contexts[c];
}

array|void real_port(array port, object cfg)
{
#ifdef SSL3_DEBUG
  werror("SSL3: real_port()\n");
  werror(sprintf("port = %O\n", port));
#endif

  string cert, key;
  object ctx = new_context(cfg);

  ctx->certificates=({});
  ctx->port = port[0];

  // enable use of the session cache
  ctx->use_cache = 1;

  mapping options = parse_args(port[3]);

#ifdef SSL3_DEBUG
  werror(sprintf("options = %O\n", options));
#endif

  if (!options["cert-file"])
  {
    ({ report_error, throw }) ("ssl3: No 'cert-file' argument!\n");
  }

  object privs = Privs ("Reading cert file(s)");
  object msg, part;
  // we can read a chain of certificates, separated by commas
  // with the server cert last in the list.
  foreach((options["cert-file"]/",")-({}), string c)
  {
    c=String.trim_whites(c);
    if(c!="")
    {
      string f = read_file(c);
      if (!f)
        ({ report_error, throw }) ("ssl3: Reading cert-file " + c + " failed!\n");
  
      msg = Tools.PEM.pem_msg()->init(f);

      part = msg->parts["CERTIFICATE"]
        ||msg->parts["X509 CERTIFICATE"];
  
      if (!part || !(cert = part->decoded_body()))
        ({ report_error, throw }) ("ssl3: No certificate found.\n");
      ctx->certificates += ({ cert });
    }
  }

  if(options["client-cert-authorities"]) 
  {
	array cca = ({});

    foreach((options["client-cert-authorities"]/",")-({}), string c)
    {
      c=String.trim_whites(c);
      if(c!="")
      {
        string f = read_file(c);
        if (!f)
          ({ report_error, throw }) ("ssl3: Reading client-cert-authority " + c + " failed!\n");
  
        msg = Tools.PEM.pem_msg()->init(f);
 
        part = msg->parts["CERTIFICATE"]
          ||msg->parts["X509 CERTIFICATE"];
  
        if (!part || !(cert = part->decoded_body()))
          ({ report_error, throw }) ("ssl3: No certificate found.\n");
        cca += ({ cert });
      }
    }

    ctx->set_authorities(cca);
    ctx->verify_certificates = 1;
  }

  if(options["client-cert-issuers"]) 
  {
	array cca = ({});

    foreach((options["client-cert-issuers"]/",")-({}), string c)
    {
      c=String.trim_whites(c);
      if(c!="")
      {
        string f = read_file(c);
        if (!f)
          ({ report_error, throw }) ("ssl3: Reading client-cert-issuer " + c + " failed!\n");
  
        msg = Tools.PEM.pem_msg()->init(f);
 
        part = msg->parts["CERTIFICATE"]
          ||msg->parts["X509 CERTIFICATE"];
  
        if (!part || !(cert = part->decoded_body()))
          ({ report_error, throw }) ("ssl3: No certificate found.\n");
        cca += ({ cert });
      }
    }

    ctx->set_trusted_issuers(({cca}));
    ctx->require_trust = 1;
  }

  string f2 = options["key-file"] && read_file(options["key-file"]);
  destruct (privs);

  if (options["key-file"]) {
    if (!f2)
      ({ report_error, throw }) ("ssl3: Reading key-file failed!\n");
    msg = Tools.PEM.pem_msg()->init(f2);
  }

  part = msg->parts["RSA PRIVATE KEY"];
  
  if (!part || !(key = part->decoded_body()))
    ({ report_error, throw }) ("ssl3: Private key not found.\n");

  object rsa = Standards.PKCS.RSA.parse_private_key(key);
  if (!rsa)
    ({ report_error, throw }) ("ssl3: Private key not valid.\n");

#if constant(Standards.PKCS.Certificate.check_cert_rsa)
  if (!Standards.PKCS.Certificate.check_cert_rsa (cert, rsa))
    ({ report_error, throw }) ("ssl3: Certificate and private key do not match.\n");
#endif

  function r = Caudium.Crypto_Randomness.reasonably_random()->read;

#ifdef SSL3_DEBUG
  werror(sprintf("RSA key size: %d bits\n", rsa->rsa_size()));
#endif

  if (rsa->rsa_size() > 512)
  {
    /* Too large for export */
    ctx->short_rsa = Crypto.RSA()->generate_key(512, r);

    // ctx->long_rsa = Crypto.RSA()->generate_key(rsa->rsa_size(), r);
  }

  if(options["client-cert-request"])
  {
     if(options["client-cert-request"] == "request")
		ctx->auth_level = SSL.Constants.AUTHLEVEL_ask;
     else if(options["client-cert-request"] == "require")
		ctx->auth_level = SSL.Constants.AUTHLEVEL_require;
  }

  // we need the certificates to be in the opposite order (my cert first) for ssl to work.
  ctx->certificates=reverse(ctx->certificates);
  ctx->rsa = rsa;
  ctx->random = r;
}

#define CHUNK 16384

string to_send_buffer;
int done;

static void write_more();

void got_data_to_send(mixed fooid, string data)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:got_data_to_send(X, \"%s\")\n", data));
#endif /* SSL3_DEBUG */
  if (!to_send_buffer) {
    to_send_buffer = data;
    my_fd->set_nonblocking(0, write_more, end);
    return;
  }
  to_send_buffer += data;
}

void no_data_to_send(mixed fooid)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:no_data_to_send(X)\n"));
#endif /* SSL3_DEBUG */
  if (to_send->file) {
    to_send->file->set_blocking();
    to_send->file->close();
  }
  to_send->file = 0;
  if (!to_send_buffer) {
    // We need to wake up the sender,
    // so that it can close the connection.
    my_fd->set_nonblocking(0, write_more, end);
  }
}

string get_data()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:get_data()\n"));
#endif /* SSL3_DEBUG */
  string s;
  if ((s = to_send->head))
  {
    to_send->head = 0;
    return s;
  }

  if ((s = to_send->data))
  {
    to_send->data = 0;
    return s;
  }

  s = to_send_buffer;
  to_send_buffer = 0;

  if (to_send->file) {
    /* There's a file, but no data yet
     * disable ourselves until there is.
     */
    my_fd->set_nonblocking(0, 0, end);
    return s || "";
  }

  return s;
}

static void die()
{
  my_fd->set_blocking();
  my_fd->close();
  if (done++) destroy();
}

string cache;
static void write_more()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:write_more()\n"));
#endif /* SSL3_DEBUG */
  string s;
  if (!(s = (cache || get_data())) || s == "") {
//    perror("SSL3:: Done.\n");
    die();
    return;
  }

  if (sizeof(s)) {
    int pos = my_fd->write(s);

    // perror("Wrote "+pos+" bytes ("+s+")\n");
  
    if(pos <= 0) // Ouch.
    {
#ifdef DEBUG
      perror("SSL3:: Broken pipe.\n");
#endif
      die();
      return;
    }  
    if(pos < strlen(s))
      cache = s[pos..];
    else
      cache = 0;
  } else {
    cache = 0;
  }
}

string get_data_file()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:get_data_file()\n"));
#endif /* SSL3_DEBUG */
  string s;
  if ((s = to_send->head))
  {
    to_send->head = 0;
    return s;
  }

  if ((s = to_send->data))
  {
    to_send->data = 0;
    return s;
  }

  if(to_send->file) {
    // Read some more data
    s = to_send->file->read(CHUNK,1);
  }

  if (!s || !sizeof(s)) {
    if (to_send->file) {
      to_send->file->close();
      to_send->file = 0;
    }
  }

  return s;
}

static void write_more_file()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:write_more_file()\n"));
#endif /* SSL3_DEBUG */
  string s;

  if(!(s = (cache || get_data_file()))) {
//    perror("SSL3:: Done.\n");
    die();
    return;
  }    

  if (s && sizeof(s)) {
    int pos = my_fd->write(s);

    // perror("Wrote "+pos+" bytes ("+s+")\n");
  
    if(pos <= 0) // Ouch.
    {
#ifdef DEBUG
      perror("SSL3:: Broken pipe.\n");
#endif
      die();
      return;
    }  
    if(pos < strlen(s))
      cache = s[pos..];
    else
      cache = 0;
  } else {
    // we got to this point; no data left
    cache = 0;
    die();    
  }
}

void do_send_result_async(string head_string)
{
  file->head = head_string;
  to_send = copy_value(file);

  if (objectp(to_send->file)) {
    array st = to_send->file->stat && to_send->file->stat();
    if (st && (st[1] >= 0)) {
      // Ordinary file -- can't use non-blocking I/O
      my_fd->set_nonblocking(0, write_more_file, do_log);
    } else {
      my_fd->set_nonblocking(0, write_more, do_log);
      to_send->file->set_nonblocking(got_data_to_send, 0, no_data_to_send);
    }
  } else
    my_fd->set_nonblocking(0, write_more, do_log);
  if (done++) destroy();
}

void do_log()
{
  MARK_FD("HTTP logging"); // fd can be closed here

  if(conf)
  {
    if(file->len > 0) conf->sent+=file->len;
    file->len += misc->_log_cheat_addition;
    conf->log(file, this_object());
  }

  end(0,1);
  return;
}

static int parse_got()
{
  int r = ::parse_got();
  if(r == -1)
  {
    array certs;
    if(my_fd && my_fd->get_peer_certificates)
      certs = my_fd->get_peer_certificates();
    if(certs)
      foreach(certs;int cn;string der)
      {
        werror("cert %d subject: %s\n", cn, Standards.PKCS.Certificate.get_dn_string(
          Standards.PKCS.Certificate.get_certificate_subject(der)));
      }
  }

  // let's slide our client certificate info in...
//  if()
//  {
//  }

  return r;
}


// TODO: when we have an http->ssl3 redirect, we end up with spurious errors in the log file
// from sslfile (indexing the null value query_backend, etc). 
class fallback_redirect_request {
  string in = "";
  string out;
  string default_prefix;
  int port;
  object f;

  void die()
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request::die()\n"));
#endif /* SSL3_DEBUG */
#if 0
    /* Close the file, DAMMIT */
    object dummy = Stdio.File();
    if (dummy->open("/dev/null", "rw"))
      dummy->dup2(f);
#endif    
    f->close();
    destruct(f);
    destruct(this_object());
  }
  
  void write_callback(object id)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request::write_callback()\n"));
#endif /* SSL3_DEBUG */
    int written = id->write(out);
    if (written <= 0)
      die();
    out = out[written..];
    if (!strlen(out))
      die();
  }

  void read_callback(object id, string s)
  {
#ifdef SSL3_DEBUG

    roxen_perror(sprintf("SSL3:fallback_redirect_request::read_callback(X, \"%s\")\n", s));
#endif /* SSL3_DEBUG */
    in += s;
    string name;
    string prefix;

    if (search(in, "\r\n\r\n") >= 0)
    {
//      werror(sprintf("request = '%s'\n", in));
      array(string) lines = in / "\r\n";
      array(string) req = replace(lines[0], "\t", " ") / " ";
      if (sizeof(req) < 2)
      {
	out = "HTTP/1.0 400 Bad Request\r\n\r\n";
      }
      else
      {
	if (sizeof(req) == 2)
	{
	  name = req[1];
	}
	else
	{
	  name = req[1..sizeof(req)-2] * " ";
	  foreach(Array.map(lines[1..], `/, ":"), array header)
	  {
	    if ( (sizeof(header) >= 2) &&
		 (lower_case(header[0]) == "host") )
	      prefix = "https://" + (header[1]/":")[0] - " ";
	  }
	}
	if (prefix) {
	  if (prefix[-1] == '/')
	    prefix = prefix[..strlen(prefix)-2];
	  prefix = prefix + ":" + port;
	} else {
	  /* default_prefix (aka MyWorldLocation) already contains the
	   * portnumber.
	   */
	  if (!(prefix = default_prefix)) {
	    /* This case is most unlikely to occur,
	     * but better safe than sorry...
	     */
	    prefix = "https://localhost:" + port;
	  } else if (prefix[..4] == "http:") {
	    /* Broken MyWorldLocation -- fix. */
	    prefix = "https:" + prefix[5..];
	  }
	}
	out = sprintf("HTTP/1.0 301 Redirect to secure server\r\n"
		      "Location: %s%s\r\n\r\n", prefix, name);
      }
      f->set_read_callback(0);
      f->set_write_callback(write_callback);
    }
  }
  
  void create(object socket, string s, string l, int p)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request(X, \"%s\", \"%s\", %d)\n", s, l||"CONFIG PORT", p));
#endif /* SSL3_DEBUG */
    f = socket;
    default_prefix = l;
    port = p;
    f->set_nonblocking(read_callback, 0, die);
    f->set_id(f);
    read_callback(f, s);
    write_callback(f);
  }
}

void http_fallback(object alert, object|int n, string data)
{
  object ctx;
  ctx = get_context(my_fd->config);
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:http_fallback(X, %O, \"%s\")\n", n, data));
#endif /* SSL3_DEBUG */
//  trace(1);
#if 0
  werror(sprintf("ssl3->http_fallback: alert(%d, %d)\n"
		 "seq_num = %s\n"
		 "data = '%s'", alert->level, alert->description,
		 (string) n, data));
#endif
  if ((!my_fd->current_write_state || !my_fd->current_write_state->seq_num)
    || search(lower_case(data), "http")!=-1)
  {

    /* Redirect to a https-url */
//    my_fd->set_close_callback(0);
//    my_fd->leave_me_alone = 1;
    fallback_redirect_request(my_fd->raw_file, data,
			      my_fd->config && 
			      my_fd->config->query("MyWorldLocation"),
			      ctx->port);
      my_fd = 0;
//    destruct(my_fd);
    destruct(this_object());
//    my_fd = 0; /* Forget ssl-object */
  }
}

void ssl_accept_callback(object id)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:ssl_accept_callback(X)\n"));
#endif /* SSL3_DEBUG */
  id->set_alert_callback(0); /* Forget about http_fallback */
  id->raw_file = 0;          /* Not needed any more */
}

class roxen_sslfile {
  inherit SSL.sslfile : ssl;

  object raw_file;
  object config;

  int destructme; // 0: alive, 1: parent wants destruct, 2: self wants destruct.
  int query_fd() { return -1; }
  void die(int status)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:roxen_sslfile::die(%d)\n", status));
#endif /* SSL3_DEBUG */
    close();
    if ((destructme |= 2) == 3) destruct();
  }

  void create(object f, object ctx, object id)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:roxen_sslfile(X, X, X)\n"));
#endif /* SSL3_DEBUG */
    raw_file = f;
    config = id;
    ssl::create(f, ctx);
  }

#ifdef SSL3_DEBUG
  void destroy()
  {
    roxen_perror(sprintf("SSL3:roxen_sslfile::destroy()\n"));
  }
#endif /* SSL3_DEBUG */
}

private object my_fd_for_destruct; // Used to keep my_fd around for destroy().

void destroy()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:destroy()\n"));
#endif /* SSL3_DEBUG */
  catch {
    // When the request disappear there's noone else interested in
    // my_fd, so it should destruct itself asap.
    if ((my_fd_for_destruct->destructme |= 1) == 3)
      destruct (my_fd_for_destruct);
  };
}

void create(void|object f, void|object c)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:create(X, X)\n"));
#endif /* SSL3_DEBUG */

  if(f)
  {
    object ctx;

    ctx = get_context(c);
    if (!ctx)
    {
      roxen_perror("ssl3.pike: No SSL context!\n");
      throw( ({ "ssl3.pike: No SSL context!\n", backtrace() }) );
    }
    remoteaddr = Caudium.get_address(f->query_address()||"");
    my_fd_for_destruct = my_fd = roxen_sslfile(f, ctx, c);
    if(my_fd->set_alert_callback)
      my_fd->set_alert_callback(http_fallback);
    my_fd->set_accept_callback(ssl_accept_callback);
    conf = c;
    my_fd->set_nonblocking(got_data,0,end);
  } else {
    // Main object. 
  }

  server_protocol="HTTPS";

}
