/* $Id$
 *
 */


inherit "connection" : connection;


#ifdef SSL3_DEBUG
#define SSL3_DEBUG_MSG werror
#else /*! SSL3_DEBUG */
#define SSL3_DEBUG_MSG
#endif /* SSL3_DEBUG */
object(Stdio.File) socket;

object context;

int _fd;

static string read_buffer; /* Data that is received before there is any
		     * read_callback 
                     * Data is also buffered here if a blocking read from HLP
		     * doesnt want to read a full packet of data.*/
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
  if (socket)
  {
    mixed id;
    catch(id = socket->query_id());
    catch(socket->close());
    socket = 0;
    // Avoid recursive calls if the close callback closes the socket.
    if(close_callback)
      close_callback( id );
  }
}

/* Return 0 if the connection is still alive,
   * 1 if it was closed politely, and -1 if it died unexpectedly
   */
private int queue_write()
{
  int|string data = to_write();
#ifdef SSL3_DEBUG_TRANSPORT
  werror(sprintf("SSL.sslfile->queue_write: '%O'\n", data));
#endif
  if (stringp(data))
    write_buffer += data;
#ifdef SSL3_DEBUG_TRANSPORT
  werror(sprintf("SSL.sslfile->queue_write: buffer = '%O'\n", write_buffer));
#endif

  if(!blocking) {
    if (catch {
      socket->set_write_callback(ssl_write_callback);
    }) {
      return(0);
    }
  }
#ifdef SSL3_DEBUG_TRANSPORT
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

  if (sizeof (write_buffer) && !blocking)
    ssl_write_callback(socket->query_id());

  if(sizeof(write_buffer) && blocking) {
    write_blocking();
  }

  send_close();
  queue_write();
  read_callback = 0;
  write_callback = 0;
  close_callback = 0;

  if (sizeof (write_buffer) && !blocking) {
     ssl_write_callback(socket->query_id());
   }
  if(sizeof(write_buffer) && blocking) {
    write_blocking();
  }

  socket->close();
}


string|int read(string|int ...args) {

  #ifdef SSL3_DEBUG
  werror(sprintf("sslfile.read called!, with args: %O \n",args));
  #endif
  
  int nbytes;
  int notall;
  switch(sizeof(args)) {
  case 0:
    {
      string res="";
      string data=got_data(read_blocking_packet());
      
      while(stringp(data)) {
	res+=data;
	data=got_data(read_blocking_packet());
      } 
      die(1);
      return read_buffer+res;
    }
  case 1:
    {
      nbytes=args[0];
      notall=0;
      break;
    }
  case 2:
    {
      nbytes=args[0];
      notall=args[1];
      break;
    }

  default:

    throw( ({ "SSL.sslfile->read: Wrong number of arguments\n",
		backtrace() }) );
  }
  
  string res="";
  int leftToRead=nbytes;

  if(strlen(read_buffer)) {
    if(leftToRead<=strlen(read_buffer)) {
      res=read_buffer[..leftToRead-1];
      read_buffer=read_buffer[leftToRead..];
      return res;
    } else {
      res=read_buffer;
      leftToRead-=strlen(read_buffer);
      if(notall) {
	return res;
      }
    }
  }

  string|int data=got_data(read_blocking_packet());
  if(!stringp(data)) {
    return ""; //EOF or ssl-fatal error occured.
  }

  while(stringp(data)) {
    res+=data;
    leftToRead-=strlen(data);
    if(leftToRead<=0) break;
    if(notall) return res;
    data=got_data(read_blocking_packet());
  }

  if(leftToRead<0) {
    read_buffer=data[strlen(data)+leftToRead..];
    return res[0..args[0]-1];
  } else {
    read_buffer="";
  }

  if(!stringp(data)) {
    die(1);
  }

  return res;
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

  if (blocking)
    write_blocking();
  else {
    if (call_write)
      ssl_write_callback(socket->query_id());
  }
  return len;
}

 
void get_blocking_to_handshake_finsihed_state() {
  
  while(!handshake_finished) {
    write_blocking();
    string|int s=got_data(read_blocking_packet());
    if(s==1||s==-1) break;
  }
}

// Reads a single record layer packet.
private int|string read_blocking_packet() {
  
  string header=socket->read(5);
  if(!stringp(header)) {
    return -1;    
  }
  
  if(strlen(header)!=5) {
    return 1;
  }
  
  int compressedLen=header[3]*256+header[4];
  return header+socket->read(compressedLen);
}


// Writes out everything that is enqued for writing.
private void write_blocking() {

  int res = queue_write();

  while(strlen(write_buffer)) {
    
    int written = socket->write(write_buffer);
    if (written > 0) {
      write_buffer = write_buffer[written ..];
    } else {
      if (written < 0)
	die(-1);
    }
    res=queue_write();
  }
}



private void ssl_read_callback(mixed id, string s)
{
#ifdef SSL3_DEBUG
  werror(sprintf("SSL.sslfile->ssl_read_callback, connected=%d, handshake_finished=%d\n", connected, handshake_finished));
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
  if (!strlen(write_buffer) && socket)
    catch(socket->set_write_callback(0)); // Catch in case it's closed.
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
    set_write_callback(args[1]);
    set_close_callback(args[2]);
    if (!this_object()) {
      return;
    }
    break;
  default:
    throw( ({ "SSL.sslfile->set_nonblocking: Wrong number of arguments\n",
		backtrace() }) );
  }
  blocking = 0;
  socket->set_nonblocking(ssl_read_callback,ssl_write_callback,ssl_close_callback);
  if (strlen(read_buffer))
    ssl_read_callback(socket->query_id(), "");
}

void set_blocking()
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->set_blocking\n");
#endif
  if (sizeof (write_buffer) && !blocking)
    ssl_write_callback(socket->query_id());
  
  socket->set_blocking();
  blocking = 1;
  get_blocking_to_handshake_finsihed_state();
}

string query_address(int|void arg)
{
  return socket->query_address(arg);
}


void create(object f, object c, int|void is_client, int|void is_blocking)
{
#ifdef SSL3_DEBUG
  werror("SSL.sslfile->create\n");
#endif
  _fd=f->_fd;
  context = c;
  read_buffer = write_buffer = "";
  socket = f;
  blocking=is_blocking;
  if(blocking) {
    socket->set_blocking();
    connection::create(!is_client);
    get_blocking_to_handshake_finsihed_state();
  } else {
    socket->set_nonblocking(ssl_read_callback,
			  ssl_write_callback,
			  ssl_close_callback);
    connection::create(!is_client);
  }
}

void renegotiate()
{
  expect_change_cipher = certificate_state = 0;
  send_packet(hello_request());
  socket->set_write_callback(ssl_write_callback);
  handshake_finished = 0;
  connected = 0;
}
