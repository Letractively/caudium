
#define MAJOR_VERSION 0
#define MINOR_VERSION 1

object out;
string err;
multiset done;

void create() {
  out = Stdio.FILE();
  done = (< >);
}

int connect( string host, void|int port ) {
  if ( out->connect( host, (port?port:444) ) ) {
    string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
    if ( ret[ 0..2 ] == "220" ) {
      done += (< "connect" >);
      return 1;
    }
    err = ret;
    out->close();
  }
  return 0;
}

string error() {
  return replace( err, "\r", "" );
}

function pager = cmd_pager;
int cmd_pager( string id ) {
  if (! done->connect ) {
    err = "Must connect before sending pager id";
    return -1;
  }
  out->printf( "PAGE %s\n", id );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] == "250" ) {
    done += (< "pager" >);
    return 1;
  }
  else {
    err = ret;
    out->close();
    return 0;
  }
}

function message = cmd_message;
int cmd_message( string message ) {
  if ( ! done->pager ) {
    err = "Must send pager id before message";
    return -1;
  }
  out->printf( "MESS %s\n", message );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] == "250" ) {
    done += (< "data" >);
    return 1;
  }
  else {
    err = ret;
    out->close();
    return 0;
  }
}

function data = cmd_data;
int cmd_data( string message ) {
  if ( ! done->pager ) {
    err = "Must send pager id before message";
    return -1;
  }
  out->printf( "DATA\n" );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] != "354" ) {
    err = ret;
    out->close();
    return 0;
  }
  if ( ! message[ sizeof( message ) -1 ] == '\n' )
    message += "\r\n";
  out->printf( "\r\n%s.\r\n", message );
  ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] != "250" ) {
    err = ret;
    out->close();
    return 0;
  }
  done += (< "data" >);
  return 1;
}

function send = cmd_send;
int cmd_send() {
  if ( ! done->data ) {
    err = "Must send use cmd_data() or cmd_message() before send.";
    return -1;
  }
  if ( ! done->callerid ) {
    int pikemaj, pikemin, pikebuild;
    sscanf( "Pike %d.%d release %d", version(), pikemaj, pikemin, pikebuild );
    cmd_callerid( sprintf( "Pike v%d.%dr%d/SNPP v%d.%d", pikemaj, pikemin, pikebuild, MAJOR_VERSION, MINOR_VERSION ) );
  }
  out->printf( "SEND\n" );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] != "250" ) {
    err = ret;
    out->close();
    return 0;
  }
  return 1;
}

function reset = cmd_reset;
int cmd_reset() {
  done = (< >);
  out->printf( "RESE\n" );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] != "250" ) {
    err = ret;
    out->close();
    return 0;
  }
  return 1;
}

function callerid = cmd_callerid;
int cmd_callerid( string email ) {
  out->printf( "CALL %s\n", email );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] != "250" ) {
    err = ret;
    out->close();
    return 0;
  }
  done += (< "callerid" >);
  return 1;
}

function quit = cmd_quit;
int cmd_quit() {
  out->printf( "QUIT\n" );
  string ret = out->gets();
#ifdef SNTP_DEBUG
  werror( ret[ 0..2 ] + ": " + ret + "\n" );
#endif
  if ( ret[ 0..2 ] != "221" ) {
    err = ret;
    out->close();
    return 0;
  }
  out->close();
  return 1;
}

