/* $Id$
 *
 */

// inherit Stdio.File : socket;
inherit "connection" : connection;

object(Stdio.File) socket;

object context;
  
string read_buffer; /* Data that is received before there is any
		     * read_callback */
string write_buffer; /* Data to be written */
function(mixed,string:void) read_callback;
function(mixed:void) write_callback;
function(mixed:void) close_callback;
function(mixed:void) accept_callback;

int connected; /* 1 if the connect callback has been called */
int blocking;  /* 1 if in blocking mode.
		* So far, there's no true blocking i/o, read and write
		* requests are just queued up. */
int is_closed;

private void ssl_write_callback(mixed id);

void die(int status)
{
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->die: is_closed = %d\n", is_closed));
#endif
  if (status < 0)
  {
    /* Other end closed without sending a close_notify alert */
    context->purge_session(this_object());
#ifdef SSL3_DEBUG
    werror("SSL.sslfile: Killed\n");
#endif
  }
  is_closed = 1;
  if (socket) {
    catch( socket->close() );
    if(close_callback)
      close_callback(socket->query_id());
  }
}

/* Return 0 if the connection is still alive,
   * 1 if it was closed politely, and -1 if it died unexpectedly
   */
private int queue_write()
{
  int|string data = to_write();
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->queue_write: '%O'\n", data));
#endif
  if (stringp(data))
    write_buffer += data;
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->queue_write: buffer = '%O'\n", write_buffer));
#endif

  if (catch {
    socket->set_write_callback(ssl_write_callback);
  }) {
    return(0);
  }
  
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->queue_write: end\n");
#endif
  return stringp(data) ? 0 : data;
}

void close()
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->close\n");
#endif

  if (is_closed) return;
  is_closed = 1;

  if (sizeof (write_buffer))
    ssl_write_callback(socket->query_id());

  send_close();
  queue_write();
  read_callback = 0;
  write_callback = 0;
  close_callback = 0;
}

int write(string|array(string) s)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->write\n");
#endif

  if (is_closed) return -1;

  if (arrayp(s)) {
    s = s*"";
  }

  int call_write = !sizeof (write_buffer);
  int len = strlen(s);
  object packet;
  int res;
  while(strlen(s))
  {
    packet = Packet();
    packet->content_type = PACKET_application_data;
    packet->fragment = s[..PACKET_MAX_SIZE-1];
    send_packet(packet);
    s = s[PACKET_MAX_SIZE..];
  }

#ifndef __NT__  
  if (call_write)
    ssl_write_callback(socket->query_id());
#endif

#if 0
  if (queue_write() == -1)
  {
    die(-1);
    return -1;
  }
#endif
  return len;
}

private void ssl_read_callback(mixed id, string s)
{
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->ssl_read_callback\n"));
#endif
  string|int data = got_data(s);
  if (stringp(data))
  {
#ifdef SSL3_DEBUG
    werror(sprintf("SSL.sslfile->ssl_read_callback: application_data: '%O'\n", data));
#endif
    if (!connected && handshake_finished)
    {
      connected = 1;
      if (accept_callback)
	accept_callback(this_object());
    }

    read_buffer += data;
    if (!blocking && read_callback && strlen(read_buffer))
    {
      string received = read_buffer;
      read_buffer = "";
      read_callback(id, received);
    }
  } else {
    if (data > 0)
    {
      if (close_callback)

	close_callback(socket->query_id());
    }
    else
      if (data < 0)
      {
	/* Fatal error, remove from session cache */
	if (this_object()) {
	  die(-1);
	}
	return;
      }
  }
  if (this_object()) {
    int res = queue_write();
    if (res)
      die(res);
  }
}
  
private void ssl_write_callback(mixed id)
{
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->ssl_write_callback: handshake_finished = %d\n"
		 "blocking = %d, write_callback = %O\n",
		 handshake_finished, blocking, write_callback));
#endif

  if (strlen(write_buffer))
  {
    int written = socket->write(write_buffer);
    if (written > 0)
    {
      write_buffer = write_buffer[written ..];
    } else {
      if (written < 0)
#ifdef __NT__
	// You don't want to know.. (Bug observed in Pike 0.6.132.)
	if (socket->errno() != 1)
#endif
	  die(-1);
    }
  }
  int res = queue_write();
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslport->ssl_write_callback: res = '%O'\n", res));
#endif
  
  if ( !res && !strlen(write_buffer)
       && connected && !blocking && write_callback)
  {
#ifdef SSL3_DEBUG
    werror("SSL.sslport->ssl_write_callback: Calling write_callback\n");
#endif
    write_callback(id);
    if (!this_object()) {
      // We've been destructed.
      return;
    }
    res = queue_write();
  }
  if (!strlen(write_buffer) && !query_write_callback())
    socket->set_write_callback(0);
  if (res)
    die(res);
}

private void ssl_close_callback(mixed id)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslport: ssl_close_callback\n");
#endif
  if (close_callback)
    close_callback(socket->query_id());
  if (this_object()) {
    die(closing ? 1 : -1);
  }
}

void set_accept_callback(function(mixed:void) a)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslport: set_accept_callback\n");
#endif
  accept_callback = a;
}

function query_accept_callback() { return accept_callback; }

void set_read_callback(function(mixed,string:void) r)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslport: set_read_callback\n");
#endif
  read_callback = r;
}

function query_read_callback() { return read_callback; }

void set_write_callback(function(mixed:void) w)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->set_write_callback\n");
#endif
  write_callback = w;
  if (w)
    socket->set_write_callback(ssl_write_callback);
}

function query_write_callback() { return write_callback; }

void set_close_callback(function(mixed:void) c)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslport: set_close_callback\n");
#endif
  close_callback = c;
}

function query_close_callback() { return close_callback; }

void set_nonblocking(function ...args)
{
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->set_nonblocking(%O)\n", args));
#endif

  if (is_closed) return;

  switch (sizeof(args))
  {
  case 0:
    break;
  case 3:
    set_read_callback(args[0]);
    set_close_callback(args[2]);
    set_write_callback(args[1]);
    if (!this_object()) {
      return;
    }
    break;
  default:
    throw( ({ "SSL.sslfile->set_nonblocking: Wrong number of arguments\n",
		backtrace() }) );
  }
  blocking = 0;
  if (strlen(read_buffer))
    ssl_read_callback(socket->query_id(), "");
}

void set_blocking()
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->set_blocking\n");
#endif
#if 0
  if (!connected)
    throw( ({ "SSL.sslfile->set_blocking: Not supported\n",
		backtrace() }) );
#endif
  blocking = 1;
}

string query_address(int|void arg)
{
  return socket->query_address(arg);
}

#if 0
object accept()
{
  /* Dummy method, for compatibility with Stdio.Port */
  return this_object();
}
#endif

void create(object f, object c)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->create\n");
#endif
  context = c;
  read_buffer = write_buffer = "";
  socket = f;
  socket->set_nonblocking(ssl_read_callback, 0, ssl_close_callback);
  connection::create(1);
}
