/* PIKE */

/*
 * http://www.dv.co.yu/mpgscript/mpeghdr.htm
 */

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";
constant thread_safe = 0; // not sure about this? anyone?
constant module_type = MODULE_LOCATION|MODULE_PARSER|MODULE_EXPERIMENTAL;
constant module_name = "Fishcast";
#if constant(thread_create)
constant module_doc = "This is an streaming MP3 server for Caudium.";
#else
constant module_doc = "Your pike doesn't seem to have support for threads. That screws this idea!";
#endif
constant module_unique = 1;

mapping streams = ([ ]);

void create() {
    defvar( "mountpoint", "/_streams/", "Mountpoint", TYPE_STRING, "The mountpoint in the virtual filesystem" );
    defvar( "mp3files", "/var/spool/mp3/", "MP3 Search Path", TYPE_STRING, "The path in the real filesystem to the MP3 directory" );
    defvar( "listing", 0, "Listing", TYPE_FLAG, "Enable stream listing", ({ "yes", "no" }) );
    defvar( "maxclients", 20, "Maximum Clients", TYPE_INT, "Maximum connected clients" );
}

void start( int cnt, object conf ) {
    // might do something here later.
    if ( sizeof( streams ) > 0 ) {
	write( "Calling stop()...\n" );
	stop();
    }
    streams = ([ ]);
}

void stop() {
    write( "Forced module stop, terminating threads: " );
    int id;
    foreach( indices( streams ), id ) {
        streams[ id ]->terminate();
    }
    streams = ([ ]);
    write( "done.\n" );
}

string status() {
    // I will deffinately do something here!
    string ret =
	"<table border=1>\n";
    mixed sid;
    foreach( indices( streams ), sid ) {
	ret +=
	    "<tr><td colspan=2><b>Stream Name: " + (string)streams[ sid ]->get_name() + " (" + (string)streams[ sid ]->currently_playing() + ")</b></td><td><b>Read: " + (string)(int)(streams[ sid ]->sent_bytes() / 1024 ) +  "kbytes</b></td></tr>\n";
	mixed client;
        array clients = streams[ sid ]->list_clients();
	foreach( indices( clients ), client ) {
	    ret +=
		"<tr><td>Client: " + (string)clients[ client ][ "remoteaddr" ] + "</td>"
		"<td>Connected: " + (string)ctime( clients[ client ][ "start" ] ) + "</td>"
		"<td>Sent: " + (string)(int)(clients[ client ][ "bytes" ] / 1024 ) + "kbytes</td></tr>\n";
	}

    }
    ret += "</table>\n";
    return ret;
}

string query_location() {
    return QUERY(mountpoint);
}

mixed find_file( string path, object id ) {
    // Magic happens here!
    if ( path == "" ) {
	return -1;
    } else if ( path == "/" ) {
	return -1;
    } else {
	int sid = (int)replace( path, "/", "" );
	write( "Request for ID: " + (string)sid + "\n" );
	if( streams[ sid ] ) {
            write( "Stream exists.\n" );
//	    id->my_fd->do_not_disconnect = 1;
            id->my_fd->set_blocking();
	    write( "Sending headers: " );
	    id->my_fd->write( "ICY 200 OK\nContent-type: audio/mpeg\n\n" );
            write( "done.\n" );
	    write( "Registering client to stream: " );
	    streams[ sid ]->register_client( id->my_fd, id->remoteaddr );
            write( "done.\nReturning.\n" );
	    return http_pipe_in_progress();
	} else {
            write( "Stream doesnt exist.\n" );
	    return 0;
	}
    }
}

mixed find_dir( string path, object id ) {
    if ( query( "listing" ) ) {
	array retval = ({ });
	array tmp = indices( streams );
        int id;
	foreach( tmp, id ) {
	    retval += ({ (string)id });
	}
	return retval;
    } else {
	return 0;
    }
}

void|string real_file( string path, object id ) {
    return 0;
}

void|array stat_file( string path, object id ) {
    return 0;
}

mapping query_container_callers() {
    return ([ "stream":_tag_stream ]);
}

string _tag_stream( string tag, mapping args, string contents, object id ) {
    int bitrate = args->bitrate?(int)args->bitrate:0;
    if ( bitrate == 0 ) {
	return "ERROR: I need a bitrate until someone want's to help me and show me how to <a href='http://www.dv.co.yu/mpgscript/mpeghdr.htm'>parse the bitrate out of the mp3</a>\n";
    }
    int shuffle = (args->shuffle?1:0);
    int loop = (args->loop?1:0);
    // basic parser, needs to be more intelligent
    array files = contents / "\n";
    files -= ({ "" });
    mixed stream_id;
    mixed _stream_id;
    foreach( indices( streams ), _stream_id ) {
	// does the stream already exist?
	if ( streams[ _stream_id ]->list_files() - files == ({ }) ) {
	    stream_id = _stream_id;
	}
    }
    if ( ! stream_id ) {
	// create a new stream!
	write( "Creating new stream: " );
	object s = stream( files, query( "mp3files" ), loop, shuffle, bitrate, query( "maxclients" ), args->name );
        write( "done. (id = " + (string)s->get_ID() + ")\n" );
	write( "Creating thread: " );
	thread_create( s->start );
	stream_id = s->get_ID();
        write( "done.\n" );
	streams += ([ stream_id : s ]);
	write( "Streams:\n" + sprintf( "%O", streams ) + "\n" );
   }
    return "<a href='" + fix_relative( "/" + query( "mountpoint" ) + "/" + sprintf( "%d", (int)stream_id ), id ) + "'>" + (args->link?args->link:"Listen") + "</a>";
}

class stream {

    array files;
    mapping clients = ([ ]);
    int loop, shuffle, ident, running, pause, term, bytes, bitrate, wait, maxclients;
    string name, base, playing;

    void create( array _files, string _base, int _loop, int _shuffle, int _bitrate, int _maxclients, void|string _name ) {
	files = _files;
	loop = _loop;
	shuffle = _shuffle;
	base = _base; // QUERY( "mp3files" )
	name = _name?_name:"Untitled Stream";
	bitrate = _bitrate;
        maxclients = _maxclients;
	ident = time() * random( time() );
    }

    int get_ID() {
	return ident;
    }

    void start() {
	// I am the actual reader thread
	running = 1;
        bytes = 0;
	int _loop = 1;
	string filename;
	int block = (int)( bitrate * 12.8 );
        int thyme = time();
	while( _loop == 1 ) {
	    _loop = loop;
	    foreach( (shuffle?Array.shuffle(files):files), filename ) {
		object f;
		if ( catch( f = Stdio.File( base + filename, "r" ) ) ) {
		    write( "Can't locate file: " + base + filename + "\n" );
		}
		playing = filename;
		write( "Stream: " + name + ", playing: " + playing + "\n" );
		string buff;
		int eof;
                float elapsed;
		while( eof == 0 ) {
		    elapsed = (float)time( thyme );
		    buff = f->read( block );
		    if ( buff == "" ) {
                        eof = 1;
                        break;
		    }
                    bytes += block;
		    // If there are no clients listening then you might as well
		    // wait until there are some.
		    // Does half a second between checks seem reasonable?
		    while( sizeof( clients ) == 0 ) {
			sleep( 0.5 );
		    }
		    if ( term == 1 ) {
                        write( "Terminating thread.\n" );
			return;
		    }
		    send( buff );
		    // this really needs to be changed so that if it takes
		    // longer than 1/10th of a second to send data to the clients
		    // then we are too busy, and should reduce samples to 9/second
		    // and increase the sample size. Or else maybe disconenct a client :)
		    sleep( ( 0.1 - ( (float)time( thyme) - elapsed ) ) );
		}
                f->close();
	    }
	}
	running = 0;
    }

    void send( string buffer ) {
	// This probably wont scale very well
	// if you have a better idea let me know.
	if ( sizeof( clients ) > 0 ) {
	    if ( wait != 0 ) {
		unregister_client( wait, 1 );
                wait = 0;
	    }
	    mixed id;
	    foreach( indices( clients ), id ) {
		if ( clients[ id ][ "fd" ]->write( buffer ) == -1 ) {
		    write( "write() returned -1!!\n" );
		    unregister_client( id );
		}
		clients[ id ][ "bytes" ] += sizeof( buffer );
	    }
	}
    }

    void register_client( object fd, string remoteaddr ) {
	write( "Client " + remoteaddr + " connecting: " );
	if ( ( sizeof( clients ) == maxclients ) && ( maxclients != 0 ) ) {
	    write( "rejecting.\n" );
	    fd->write(
		      "HTTP/1.1 502 Server Too Busy\n"
		      "Content-Type: text/html\n\n"
		      "<head>\n"
		      "<title>Server Too Busy</title>\n"
		      "<body>\n"
		      "I'm sorry, the maximum number of clients for this stream has been exceeded\n"
                      "</body>\n"
		     );
	    fd->close();
	} else {
	    if ( fd->query_id() == 0 ) {
		fd->set_id( time() * random( time() ) );
	    }
	    clients += ([ fd->query_id() : ([ "fd" : fd, "start" : time(), "bytes" : 0, "remoteaddr" : remoteaddr ]) ]);
	    fd->set_close_callback( unregister_client, fd->query_id() );
	    if ( running == 0 ) {
		thread_create( start );
	    }
            write( "done.\n" );
	}
    }

    void unregister_client( mixed client_id, void|int really ) {
	if ( really == 1 ) {
	    write( "Client disconnected from stream\n" );
	    // clients[ client_id ][ "fd" ]->close();
	    m_delete( clients, client_id );
	} else {
            wait = client_id;
	}
    }

    array list_files() {
	return files;
    }

    void terminate() {
	mixed id;
	foreach( indices( clients ), id ) {
            write( "Disconnecting client.\n" );
	    clients[ id ][ "fd" ]->close();
            unregister_client( id );
	}
        term = 1;
    }

    string get_name() {
	return name;
    }

    mapping list_clients() {
	return clients;
    }

    int sent_bytes() {
	return bytes;
    }

    string currently_playing() {
	return playing;
    }

}
