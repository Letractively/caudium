
int non_blocking;
mapping callbacks;
string host;
int port;
string command;
string luser;
string ruser;
object stderr;
object srv;
function write;
function read;
function stderr_read;

void create( string _luser, void|string _ruser ) {
  luser = _luser;
  if ( _ruser )
    ruser = _ruser;
  else
    ruser = _luser;
}

int connect( string _host, int _port, void|string _command, void|mapping _callbacks ) {
  // Set up the global variables;
  if ( _callbacks && ( sizeof( _callbacks ) > 0 ) ) {
    callbacks = _callbacks;
    non_blocking = 1;
  }
  else
    callbacks = ([ ]);
  host = _host;
  port = _port?_port:514;
  command = _command;
  // Create the connection
  int out_port = random( 511 ) + 512;
  srv = Stdio.File();
  if ( ! srv->connect( host, port, 0, out_port ) ) 
    return 0;
  int stderr_port;
  if ( callbacks->stderr_read ) {
    stderr_port = random( 511 ) + 512;
    stderr = Stdio.Port( stderr_port, accept_stderr, (srv->query_address( 1 ) / " ")[ 0 ] );
  }
  if ( ! srv->write( "%d\0%s\0%s\0%s\0", stderr_port, luser, ruser, command ) ) 
    return 0;
  if ( srv->read( 1, 1 ) != "\0" )
    return 0;
  if ( non_blocking ) {
    srv->set_nonblocking(
      __read,
      __write,
      close );
  }
  write = srv->write;
  read = srv->read;
  return 1;
}

void __read( mixed id, string data ) {
  if ( callbacks->read )
    callbacks->read( data );
}

void __write() {
  if ( callbacks->write )
    callbacks->write();
}

void accept_stderr() {
  object _stderr = stderr->accept();
  stderr = _stderr;
  if ( callbacks->stderr_read ) {
    stderr->set_nonblocking( callbacks->stderr_read );
  }
  else
    stderr_read = stderr->read;
}

void close() {
  srv->close();
  if ( stderr )
    stderr->close();
  if ( callbacks->close )
    callbacks->close();
}
