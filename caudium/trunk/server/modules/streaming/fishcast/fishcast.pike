/* PIKE */

/*
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

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";
constant version = "1.0rc4";
constant thread_safe = 0; // maybe more like "constant will_kill_your_box_if_sneezed_at = 1;"
constant module_type = MODULE_LOCATION|MODULE_PARSER|MODULE_EXPERIMENTAL;
constant module_name = "Fishcast";
#if constant(thread_create)
constant module_doc =
    "<b>This is an streaming MP3 server for Caudium.</b><br>"
    "<i>Version: " + version + "</i><br><br>\n"
    "It supports Ice/Shoutcast streams and Audiocast streams.<br>\n"
    "It may have a 1.0 version number but that doesn't mean it's not "
    "going to crash your box, kill your goldfish, drink all your beer "
    "and sleep with your wife.<br>\n"
    "In short, your mileage may vary.\n";
#else
constant module_doc = "<font color=red><b>Your pike doesn't seem to have support for threads. That screws any chance of you running fishcast on this server!</font></b>";
#endif
constant module_unique = 1;

mapping streams = ([ ]);
mapping vars;

void create() {
    defvar( "location", "/fishcast/", "Mountpoint", TYPE_LOCATION, "The mountpoint in the virtual filesystem for this module" );
    defvar( "search_mp3", "/var/spool/mp3/", "Search Paths: MP3 Files", TYPE_STRING, "The path in the real filesystem to the MP3 directory" );
    defvar( "search_promo", "/var/spool/promo/", "Search Paths: Promo's", TYPE_STRING, "The path int the real filesystem to promo's if they are enabled", 0, promos_enable );
    defvar( "listing_streams", 0, "Listing: Stream Directory", TYPE_FLAG, "Enable listing of available streams", ({ "Yes", "No" }) );
    defvar( "listing_incoming", 0, "Listing: Incoming Directory", TYPE_FLAG, "Enable listing of available incoming streams", ({ "Yes", "No" }), incoming_enable );
    defvar( "listing_playlists", 0, "Listing: Playlist Directory", TYPE_FLAG, "Enable listing of available playlists", ({ "Yes", "No" }) );
    defvar( "maxclients", 20, "Clients: Maximum Clients", TYPE_INT, "Maximum connected clients (per stream). Zero is infinite (*very dangerous*)" );
    defvar( "sessiontimeout", 0, "Clients: Maximum Session Length", TYPE_INT, "Target client session length (in seconds). This option disconnects a client from a stream at the end of a track, once they have been on longer than this. If you have very long tracks it's not worth setting this at all." );
    defvar( "pauseplayback", 1, "Clients: Pause Playback", TYPE_FLAG, "Pause the &quot;playback&quot; of streams when there are no clients listening to them", ({ "Yes", "No" }) );
    defvar( "titlestreaming", 0, "Clients: Title Streaming", TYPE_FLAG, "Enable streaming of track titles to clients, this is known to cause issues with some MP3 players", ({ "Enabled", "Disabled" }) );
    defvar( "allowtrackskip", 1, "Clients: Enable Track Skipping", TYPE_FLAG, "Enable track skip from clients", ({ "Enabled", "Disabled" }) );
    defvar( "allowtrackrepeat", 0, "Clients: Enable Track Repeat", TYPE_FLAG, "Enable track repeat from clients", ({ "Enabled", "Disabled" }) );
    defvar( "promos_enable", 0, "Promo's: Enable Promo's", TYPE_FLAG, "Enable Promo Streaming", ({ "Yes", "No" }) );
    defvar( "promos_freq", 10, "Promo's: Frequency", TYPE_INT, "Insert Promo into stream every how many tracks?", 0, promos_enable );
    defvar( "promos_shuffle", 0, "Promo's: Shuffle", TYPE_FLAG, "If selected then the Promo's will be randomly ordered, otherwise they will be ordered alphabetically", ({ "Yes", "No" }), promos_enable );
    defvar( "incoming_enable", 0, "Incoming Streams: Enable Incoming Streams", TYPE_FLAG, "Allow incoming stream connections?", 0 );
    defvar( "incoming_password", "changeme", "Incoming Streams: Password", TYPE_STRING, "Password for incoming streams", 0, incoming_enable );
}

int promos_enable() {
    return !QUERY(promos_enable);
}

int incoming_enable() {
    return !QUERY(incoming_enable);
}

void start( int cnt, object conf ) {
    if ( sizeof( streams ) > 0 ) {
#ifdef DEBUG
	perror( "Calling stop()...\n" );
#endif
	catch( stop() );
    }
    streams = ([ ]);
}

void stop() {
#ifdef DEBUG
    perror( "Forced module stop, terminating threads: " );
#endif
    if ( sizeof( streams ) > 0 ) {
	foreach( indices( streams ), int id ) {
	    catch( streams[ id ]->terminate() );
            sleep( 0.15 );
	    catch( destruct( streams[ id ] ) );
            m_delete( streams, id );
	}
    }
#ifdef DEBUG
    perror( "done.\n" );
#endif
}

string status() {
    if ( sizeof( streams ) == 0 ) {
	return "<b>No current streams</b>";
    }
    string ret =
	"<table border=1>\n";
    mixed sid;
    foreach( indices( streams ), sid ) {
	ret +=
	    "<tr><td colspan=2><b>Stream Name: " + (string)streams[ sid ]->meta->name + " (" + (string)streams[ sid ]->meta->current_track->title + ")</b></td><td><b>Read: " + (string)(int)(streams[ sid ]->meta->bytes / 1024 ) +  "kbytes (" + sprintf( "%:2f", (float)streams[ sid ]->meta->percent_played() ) + "%)</b></td></tr>\n";
	array clients = streams[ sid ]->list_clients();
	foreach( clients , object client ) {
	    ret +=
		"<tr><td>Client: " + (string)client->remoteaddr() + "</td>"
		"<td>Connected: " + (string)ctime( client->start_time() ) + "</td>"
		"<td>Sent: " + (string)( (int)client->bytes_written() / 1024 ) + "kbytes</td></tr>\n";
	}
    }
    ret += "</table>\n";
    return ret;
}

string query_location() {
    return QUERY(location);
}

mixed find_file( string path, object id ) {
    switch ( path ) {
    case "/":
	return -1;
	break;
    case "":
	return -1;
	break;
    case "streams/":
	return -1;
	break;
    case "playlists/":
	return -1;
	break;
    case "incoming/":
	return -1;
	break;
    default:
	array parts = (path / "/") - ({ "" });
	switch ( parts[ 0 ] ) {
	case "streams":
	    int sid = (int)parts[ 1 ];
	    if ( streams[ sid ] ) {
		if ( sizeof( parts ) == 3 ) {
		    switch( parts[ 2 ] ) {
		    case "skip":
			streams[ sid ]->skip_track();
                        return http_string_answer( "Track Skipped" );
			break;
		    case "repeat":
			streams[ sid ]->repeat_track( 1 );
                        return http_string_answer( "Track Repeat Queued" );
			break;
		    }
                    return http_string_answer( "Invalid Option" );
		}
		id->my_fd->set_blocking();
		streams[ sid ]->register_client( id );
		return http_pipe_in_progress();
	    } else {
		return 0;
	    }
	    break;
	case "playlists":
	    array pls = ( parts[ 1 ] / "." ) - ({ "" });
	    int sid = (int)pls[ 0 ];
	    if ( streams[ sid ] ) {
		switch ( pls[ 1 ] ) {
		case "pls":
		    return http_string_answer(
					      "[playlist]\n"
					      "NumberOfEntries=1\n"
					      "File1=http://" + replace( id->host + "/" + QUERY(location) + "/streams/" + (string)sid, "//", "/" ) + "\n",
					      "audio/mpegurl"
					     );
		    break;
		case "m3u":
		    return http_string_answer(
					      "http://" + replace( id->host + "/" + QUERY(location) + "/streams/" + (string)sid, "//", "/" ) + "\n",
					      "audio/mpegurl"
					     );
		    break;
		}
	    } else {
		return 0;
	    }
	    break;
	}
	break;
    }
}

mixed find_dir( string path, object id ) {
    array parts = (path / "/") - ({ "" });
    if ( sizeof( parts ) == 0 ) {
	return ({ "streams", "playlists", "incoming" });
    }
    switch ( parts[ 0 ] ) {
    case "streams":
	if ( QUERY(listing_streams) ) {
	    array retval = ({ });
	    array tmp = indices( streams );
	    int sid;
	    foreach( tmp, sid ) {
		retval += ({ (string)sid });
	    }
	    return retval;
	} else {
	    return 0;
	}
	break;
    case "playlists":
	if ( QUERY(listing_playlists) ) {
	    array retval = ({ });
	    array tmp = indices( streams );
	    int sid;
	    foreach( tmp, sid ) {
		retval += ({ (string)sid + ".pls", (string)sid + ".m3u" });
	    }
	    return retval;
	} else {
	    return 0;
	}
	break;
    case "incoming":
	return 0;
	break;
    default:
	return 0;
        break;
    }
}

void|string real_file( string path, object id ) {
    return 0;
}

void|array stat_file( string path, object id ) {
    int time = time();
    int size;
    array parts = ( path / "/" ) - ({ "" });

    switch( sizeof( parts ) ) {
    case 1:
	switch( parts[ 0 ] ) {
	case "streams":
	    size = -2;
	    break;
	case "playlists":
	    size = -2;
	    break;
	case "incoming":
	    size = -2;
	    break;
	}
	break;
    case 2:
	int sid = (int)parts[ 1 ];
	if ( ! streams[ sid ] ) return;
	break;
    }
    return ({ 16877, size, time, time, time, 0, 0 });
}

mapping query_container_callers() {
    return ([
	     "stream":_tags_stream,
	     "skip" : _tags_skip,
	     "repeat" : _tags_repeat,
	     "pls" : _tags_pls,
	     "status" : status
	    ]);
}


string _tags_skip( string tag, mapping args, string contents, object id ) {
    if ( args->stream_id ) {
	int sid = (int)args->stream_id;
	if ( streams[ sid ] ) {
	    return
		"<a href='" +
		fix_relative( sprintf( "/" + QUERY(location) + "/streams/%d/skip", vars->sid), id ) +
                "'>" + contents + "</a>";
	} else {
            return "<b>stream_id doesn't match an active stream</b>";
	}
    }
    return "<b>No stream_id provided</b>";
}

string _tags_repeat( string tag, mapping args, string contents, object id ) {
    if ( args->stream_id ) {
	int sid = (int)args->stream_id;
	if ( streams[ sid ] ) {
	    return
		"<a href='" +
		fix_relative( sprintf( "/" + QUERY(location) + "/streams/%d/repeat", vars->sid), id ) +
                "'>" + contents + "</a>";
	} else {
            return "<b>stream_id doesn't match an active stream</b>";
	}
    }
    return "<b>No stream_id provided</b>";
}

string _tags_pls( string tag, mapping args, string contents, object id ) {
    if ( args->stream_id ) {
	int sid = (int)args->stream_id;
	if ( streams[ sid ] ) {
	    string ext = ( args->m3u?"m3u":"pls" );
	    string link = sprintf(
				  "<a href='%s'>%s</a>",
				  fix_relative( sprintf( "/" + QUERY(location) + "/playlists/%d.%s", vars->sid, ext ), id ),
				  (contents?contents:"Listen to " + streams[ vars->sid ]->meta->name)
				 );
	    return link;
	} else {
            return "<b>stream_id doesn't match an active stream</b>";
	}
    }
    return "<b>No stream_id provided</b>";
}

string _tags_stream( string tag, mapping args, string contents, object id ) {
    vars = ([ ]);
    if ( args->help ) {
	return #string "stream_help.html";
    }
    object meta = metadata();
    parse_html( contents, ([ ]), ([ "playlist" : __tags_playlist ]) );
    if ( sizeof( vars->playlist ) > 0 ) {
	foreach( indices( streams ), int _sid ) {
	    if ( streams[ _sid ]->meta->playlist - vars->playlist == ({ }) ) {
		vars += ([ "sid" : _sid ]);
                id->variables->stream_id = (string)_sid;
	    }
	}
	if ( ! vars->sid ) {
	    meta->name = (args->name||"Unknown Stream");
	    meta->genre = args->genre;
	    meta->url = args->url;
	    meta->bitrate = (int)args->bitrate;
	    meta->description = args->description;
	    meta->titlestreaming = QUERY(titlestreaming);
	    meta->live_source = 0;
	    meta->shuffle = vars->shuffle;
	    meta->loop = vars->loop;
	    meta->max_clients = QUERY(maxclients);
	    meta->max_session = QUERY(sessiontimeout);
	    meta->pause = QUERY(pauseplayback);
	    meta->search = QUERY(search_mp3);
	    meta->track_skip = QUERY(allowtrackskip);
            meta->track_repeat = QUERY(allowtrackrepeat);
	    if ( QUERY(promos_enable) ) {
		meta->promos_enable = 1;
		meta->promos_freq = QUERY(promos_freq);
		meta->promos_shuffle = QUERY(promos_shuffle);
		meta->promos_search = QUERY(search_promo);
	    }
            meta->playlist = vars->playlist;
	    object s = new_stream( meta );
	    vars->sid = s->get_ID();
	    streams += ([ s->get_ID() : s ]);
	    // BIG HACK!!
            id->variables->stream_id = (string)vars->sid;
	}
	if ( ! vars->sid ) {
	    return "<b>ERROR</b>: Failed to create new stream!";
	}
	if ( args->debug ) {
	    return "Created Stream: " + (string)vars->sid;
	}
    } else {
	return "Whatcyou talkin' 'bout Willis?";
    }
}

string __tags_playlist( string tag, mapping args, string contents ) {
    vars +=
	([ "playlist" : (contents / "\n") - ({ "" }) ]);
    if ( args->loop ) {
	vars +=
	    ([ "loop" : 1 ]);
    }
    if ( args->shuffle ) {
	vars +=
	    ([ "shuffle" : 1 ]);
    }
    return "";
}

class metadata {

    string name;
    string genre;
    string url;
    int streamid;
    int pub = 1;
    int bitrate = 0;
    string description;
    int shuffle;
    int loop;
    int max_clients;
    int max_session;
    int pause;
    string search;
    int promos_enable;
    int promos_shuffle;
    int promos_freq;
    string promos_search;
    int titlestreaming;
    int default_metaint = 4096;
    int live_source = 0;
    int running;
    int bytes;
    int track_skip;
    int track_repeat;
    array playlist;
    mapping current_track =
	([
	  "title" : 0,
	  "file_size" : 0,
	  "file_read" : 0
	 ]);

    mixed percent_played() {
	if ( live_source == 1 ) {
	    return -1;
	}
        return (float)current_track->file_read / (float)current_track->file_size;
    }

}

class stream_client {

    inherit Thread.Mutex : r_mutex;
    inherit Thread.Mutex : w_mutex;
    object r_lock;
    object w_lock;
    mapping vars =
	([
	  "protocol" : 0,
	  "start_time" : 0,
	  "unique_id" : 0,
	  "remoteaddr" : 0
	 ]);
    object id;
    object meta;
    object fd;
    int bytes = 0;
    object queue;
    int term;
    int skip_count;

    void create( object _id, object _meta ) {
	id = _id;
	meta = _meta;
	fd = id->my_fd;
        vars->remoteaddr = id->remoteaddr;
	vars->start_time = time();
	vars->unique_id = time() * random( time() );
	if ( id->request_headers[ "icy-metadata" ] ) {
            vars->protocol = 1;
	} else if ( id->request_headers[ "x-audiocast-udpport" ] ) {
            vars->protocol = 2;
	} else {
            // Default protocol is ICY
            vars->protocol = 1;
	}
        queue = Thread.Queue();
    }

    void client_write_callback() {
	r_lock = r_mutex::lock();
	string tmp = queue->read();
	bytes += sizeof( tmp );
	fd->write( tmp );
	if ( queue->size() == 0 ) {
	    fd->set_blocking();
	}
        if ( objectp( w_lock ) ) destruct( w_lock );
    }

    void client_close_callback() {
	fd->close();
        term = 1;
    }

    void client_read_callback() {}

    void set_nonblocking() {
	fd->set_nonblocking( client_read_callback, client_write_callback, client_close_callback );
    }

    mixed client_write( string buff, void|string title ) {
	if ( term == 1 ) {
	    return this_object();
	}
	if ( ( meta->titlestreaming ) && ( title ) ) {
	    if ( meta->protocol == 1 ) {
		string m = title_encode( title );
		if ( sizeof( m ) > meta->default_metaint ) {
		    perror( "WARNING: Avoided writing metadata to client because it is too long!\n" );
		} else {
		    if ( bytes % meta->default_metaint < meta->default_metaint ) {
			int tmp = bytes % meta->default_metaint;
			if ( tmp == 0 ) {
			    buff = m + buff;
			} else {
			    buff = buff[ 0.. tmp ] + m + buff[ tmp .. sizeof( buff ) ];
			}
		    }
		}
	    }
	}

	if ( queue->size() <= 128 ) {
	    w_lock=w_mutex::lock();
	    queue->write( buff );
	    set_nonblocking();
            if ( objectp( r_lock ) ) destruct( r_lock );
	    return 0;
	}
#ifdef DEBUG
	perror( sprintf( "Client: %s buffer skipped (queue full)\n", remoteaddr() ) );
#endif
	w_lock=w_mutex::lock();
	set_nonblocking();
	if ( objectp( r_lock ) ) destruct( r_lock );
	skip_count++;
	if ( skip_count > 100 ) {
	    // If the queue has been full for more than 10 seconds then
            // feel free to disconnect them, because they must have timed out.
	    return this_object();
	}
	return 0;
    }

    string remoteaddr() {
	return vars->remoteaddr;
    }

    int bytes_written() {
	return bytes;
    }

    int start_time() {
	return vars->start_time;
    }

    mixed protocol() {
	switch (vars->protocol) {
	case 0:
	    return 0;
            break;
	case 1:
	    return "ICY";
            break;
	case 2:
	    return "Audiocast";
	    break;
	}
    }

    void write_headers() {
	string heads;
	if ( protocol() == "Audiocast" ) {
	    heads =
		"HTTP/1.0 200 OK\r\n"
		"Content-Type: audio/mpeg\r\n"
		"x-audiocast-genre:" + (meta->genre||"Unknown") + "\r\n"
		"x-audiocast-url:" + (meta->url||"http://www.caudium.net/") + "\r\n"
		"x-audiocast-name:" + meta->name + "\r\n"
		"x-audiocast-streamid:" + meta->id + "\r\n"
		"x-audiocast-public:" + meta->pub + "\r\n" +
		(meta->bitrate?"x-audiocast-bitrate:" + (meta->bitrate) + "\r\n":"") +
		"x-audiocast-description:Served by fishcast version 1.0\r\n\r\n";
	} else {
            // Default bahavior is icecast compatible mode.
	    heads =
		"ICY 200 OK\r\n"
		"Server: " + caudium.version() + "\r\n"
		"Content-Type: audio/mpeg\r\n" +
		(meta->titlestreaming?"icy-metaint:" + meta->default_metaint + "\r\n":"" ) +
		"icy-notice1:This stream requires a shoutcast compatible MP3 player.\r\n"
		"icy-notice2:Served by fishcast version 1.0\r\n"
		"icy-name:" + meta->name + "\r\n"
		"icy-genre:" + (meta->genre||"Unknown") + "\r\n"
		"icy-url:" + (meta->url||"http://www.caudium.net/") + "\r\n"
		"icy-pub:" + meta->pub + "\r\n\r\n" +
		(meta->bitrate?"icy-br:" + (string)meta->bitrate + "\r\n":"");
	}
	bytes += sizeof( heads );
	fd->write( heads );
    }

    string title_encode( string title ) {
	string m = sprintf( " StreamTitle='%s';StreamUrl='%s';", title, meta->url );
	while( strlen( m ) & 15 ) m += "\0";
	m[ 0 ]=strlen( m )/16;
	return m;
    }

    void terminate() {
	catch( fd->close() );
    }

}

class new_stream {

    array files;
    object meta;
    array clients;
    array write_callbacks;
    int ident;
    int delay_loop;
    string playing;
    int term;
    object fifo;
    int sending_to_clients;
    int _skip_track;
    int _repeat_track;

    // Used to convert kilobytes per second to to bytes per 10th of a second.
    float scale = 12.8;

    void create( object _meta ) {
        meta = _meta;
	ident = (meta->sid?meta->sid:time() * random( time() ));
	clients = ({ });
	write_callbacks = ({ });
//        fifo = Thread.Fifo();
	fifo = Thread.Queue();
    }

    int get_ID() {
	return ident;
    }

    void start() {
	// I am the actual reader thread
#ifdef DEBUG
	perror( sprintf( "Starting reader stread for %s with PID: %d\n", meta->name, getpid() ) );
#endif
	meta->running = 1;
        meta->bytes = 0;
	int _loop = 1;
	delay_loop = time();
        array promos;
	if ( meta->promos_enable ) {
	    promos = sort( get_dir( meta->search_promo ) );
	}
	while( _loop == 1 ) {
	    _loop = meta->loop;
	    array files = (meta->shuffle?Array.shuffle(meta->playlist):meta->playlist);
	    int cnt = 1;
	    int promocnt;
	    string file;
	    array playlist = ({ });
	    foreach( files, file ) {
		if ( meta->promos_enable ) {
		    if ( cnt % meta->promos_freq == 0 ) {
			string p = (meta->promos_shuffle?promos[ random( sizeof( promos ) ) ]:promos[ promocnt ]);
			playlist += ({ Stdio.append_path( meta->search_promo, p ) });
			promocnt++;
		    }
		}
		playlist += ({ Stdio.append_path( meta->search, file ) });
		cnt++;
	    }
	    foreach( playlist, string filename ) {
		// Disconnect clients at the end of the last song once
		// they have used up their max session time, unless
                // maxsession = 0
		check_client_timeouts();
		object f;
		if ( catch( f = Stdio.File( filename, "r" ) ) ) {
#ifdef DEBUG
		    perror( "Can't locate file: " + meta->search + filename + "\n" );
#endif
                    continue;
		}
		int _bitrate = get_bitrate( f );
#ifdef DEBUG
		perror( "Bitrate: "  + (string)_bitrate + "\n" );
#endif
		if ( _bitrate == -1 ) {
#ifdef DEBUG
		    perror( "No SYNC in MPEG file!\n" );
#endif
                    continue;
		}
		if ( ( meta->bitrate > 0 ) && ( _bitrate != meta->bitrate ) ) {
		    // This means that we have been told to
		    // adhere to a specific bitrate, so skip
		    // this file.
#ifdef DEBUG
		    perror( "Skipping file, wrong bitrate!\n" );
#endif
		    continue;
		}
		int block = (int)( _bitrate * 12.8 );
		playing = filename;
                meta->current_track->title = currently_playing( 1 );
//                song_change();
		meta->current_track->file_size = f->stat()[ 1 ];
                meta->current_track->file_read = 0;
#ifdef DEBUG
		perror( "Stream: " + meta->name + ", playing: " + playing + "\n" );
#endif
		if ( input( f, block, meta->current_track->title ) == -1 ) {
#ifdef DEBUG
		    perror( "Terminating Stream.\n" );
#endif
		    return;
		}
		f->close();
	    }
	}
	meta->running = 0;
    }

    void live_source( object f ) {
	// I am the reader thread if the source is live!
	meta->running = 1;
	meta->bytes = 0;
	string filename;
	int block = (int)( meta->bitrate * scale );
	delay_loop = time();
	if ( input( f, block ) == -1 ) {
#ifdef DEBUG
	    perror( "Terminating Stream.\n" );
#endif
	    return;
	}
	f->close();
	meta->running = 0;
    }

    int input( object f, int block, void|string title ) {
	string buff;
	int eof;
	float elapsed;
	while( eof == 0 ) {
	    elapsed = (float)time( delay_loop );
	    if ( _skip_track == 1 ) {
                _skip_track = 0;
		return 0;
	    }
	    buff = f->read( block );
	    if ( buff == "" ) {
		if ( _repeat_track > 0 ) {
		    _repeat_track--;
		    f->seek( 0 );
		    buff = f->read( block );
		} else {
		    eof = 1;
		    break;
		}
	    }
	    meta->bytes += block;
            meta->current_track->file_read += block;
	    if ( term == 1 ) {
#ifdef DEBUG
		perror( "Terminating thread.\n" );
#endif
		return -1;
	    }

	    while( ( sizeof( clients ) == 0 ) && ( meta->pause == 1 ) ) {
		sleep( 0.1 );
	    }
	    if ( sizeof( clients ) > 0 ) {
		fifo->write( ({ buff, title }) );
	    }
	    // this really needs to be changed so that if it takes
	    // longer than 1/10th of a second to send data to the clients
	    // then we are too busy, and should reduce samples to 9/second
	    // and increase the sample size. Or else maybe disconenct a client :)
	    sleep( abs( 0.1 - ( (float)time( delay_loop ) - elapsed ) ) );
	}
        return 0;
    }

    void send_to_clients() {
	sending_to_clients = 1;
#ifdef DEBUG
        perror( sprintf( "Creating client thread PID %d for write callbacks\n", getpid() ) );
#endif
	while( ( term == 0 ) && ( sizeof( clients ) > 0 ) ) {
	    // This is a really big issue!!
	    // If it takes too long to send data to one of the clients
	    // then this Thread.Fifo.read blocks the start() thread
	    // from sending data to clients - this is how it works,
	    // but I need a better way to get data to clients.
	    // Also, do you think that making the Fifo buffer is the
            // solution, or just an ugly hack?
	    array buff = fifo->read();
	    foreach( write_callbacks, function write ) {
		catch( mixed c = write( buff[ 0 ], buff[ 1 ] ) );
		if ( ! intp( c ) ) {
		    unregister_client( c );
		}
	    }
	}
#ifdef DEBUG
	if ( term == 1 ) {
	    perror( "Forced quit: closing sender thread!\n" );
	}
	if ( sizeof( clients ) == 0 ) {
	    perror( "No more clients for this stream, terminating\n" );
	}
#endif
	sending_to_clients = 0;
    }

    void check_client_timeouts() {
	if ( ( sizeof( clients )  > 0 ) && ( meta->max_session > 0 ) ) {
            int thyme = time();
	    foreach( clients, object client ) {
		if ( client->start_time() + meta->max_session >= thyme ) {
		    unregister_client( client );
		}
	    }
	}
    }

    void register_client( object id ) {
#ifdef DEBUG
	perror( "Client " + id->remoteaddr + " connecting: " );
#endif
	if ( ( sizeof( clients ) == meta->max_clients ) && ( meta->max_clients > 0 ) ) {
#ifdef DEBUG
	    perror( "rejecting (maxclients).\n" );
#endif
	    id->my_fd->write(
		      "HTTP/1.1 502 Server Too Busy\n"
		      "Content-Type: text/html\n\n"
		      "<head>\n"
		      "<title>Server Too Busy</title>\n"
		      "<body>\n"
		      "I'm sorry, the maximum number of clients for this stream has been exceeded\n"
                      "</body>\n"
		     );
	    id->my_fd->close();
	} else {
	    object c = stream_client( id, meta );
	    c->write_headers();
            c->set_nonblocking();
	    clients += ({ c });
	    write_callbacks += ({ c->client_write });
            mixed err;
	    if ( sending_to_clients == 0 ) {
		if ( err = catch ( thread_create( send_to_clients ) ) ) {
		    perror( sprintf( "Couldn't client create thread: %O", err ) );
		}
	    }
	    if ( meta->running == 0 ) {
		if ( err = catch ( thread_create( start ) ) ) {
		    perror( sprintf( "Couldn't reader create thread: %O", err ) );
		}
	    }
#ifdef DEBUG
	    perror( "done.\n" );
#endif
	}

    }

    void unregister_client( object client ) {
	write_callbacks -= ({ client->client_write });
	client->terminate();
	clients -= ({ client });
        destruct( client );
    }

    array list_files() {
	return files;
    }

    void terminate() {
	term = 1;
	if ( sizeof( clients ) > 0 ) {
	    foreach( clients, object client ) {
#ifdef DEBUG
		perror( "Disconnecting client: " + client->remoteaddr() + "\n" );
#endif
		unregister_client( client );
	    }
	}
    }

    array list_clients() {
	return clients;
    }

    int sent_bytes() {
	return meta->bytes;
    }

    string currently_playing( void|int shorten ) {
	if ( shorten == 1 ) {
	    array path = playing / "/";
	    path -= ({ "" });
	    return replace( path[ sizeof( path ) - 1 ], ".mp3", "" );
	}
	return playing;
    }

    int get_bitrate( object f ) {
	object mh = mpeg( f );
        return mh->bitrate_of();
    }

    void skip_track() {
	if ( meta->track_skip == 1 ) {
#ifdef DEBUG
	    perror( "Track Skip Queued\n" );
#endif
	    _skip_track = 1;
	}
    }

    void repeat_track( void|int count ) {
	if ( meta->track_repeat == 1 ) {
#ifdef DEBUG
	    perror( "Track Repeat Queued\n" );
#endif
	    _repeat_track = (count?count:_repeat_track + 1);
	}
    }

}

class mpeg {
    /*
     * This class ported C->pike from mpeg.[c,h] from the icecast clients
     * package.
     * In turn ported from C++ in mp3info by slicer@bimbo.hive.no
     */


    mapping mh = ([
		   "lay" : 0,
		   "version" : 0,
		   "error_protection" : 0,
		   "bitrate_index" : 0,
		   "sampling_frequency" : 0,
		   "padding" : 0,
		   "extension" : 0,
		   "mode" : 0,
		   "mode_ext" : 0,
		   "copyright" : 0,
		   "original" : 0,
		   "emphasis" : 0,
		   "stereo" : 0,
		   "framesize" : 0,
		   "frametime" : 0
		  ]);

    array bitrate =
	({
		({
			({ 0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448 }),
			({ 0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384 }),
			({ 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 })
		}),
		({
			({ 0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256 }),
			({ 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 }),
			({ 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 })
		}),
		({
			({ 0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256 }),
			({ 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 }),
			({ 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 })
		})
	});
    array s_freq =
	({
		({ 44100, 48000, 32000, 0 }),
		({ 22050, 24000, 16000, 0 }),
		({ 11025, 8000, 8000, 0 })
	});
    array mode_names = ({ "stereo", "j-stereo", "dual-ch", "single-ch", "multi-ch" });
    array layer_names = ({ "I", "II", "III" });
    array version_names = ({ "MPEG-1", "MPEG-2 LSF", "MPEG-2.5" });
    array version_nums = ({ "1", "2", "2.5" });
    int error;

    void create( object f ) {
	f->seek( 0 );
	string buff = f->read( 1024 );
	int readsize = sizeof( buff );
	readsize -= 4;
	if ( readsize <= 0 ) {
	    error = 1;
	    return;
	}
	string buffer;
        int temp;
        int count = 0;
	while( ( temp != 0xFFE ) && ( count <= readsize ) ) {
	    buffer = buff[ count..sizeof( buff ) ];
	    temp = ((buffer[ 0 ] << 4) & 0xFF0) | ((buffer[ 1 ] >> 4) & 0xE);
	    count++;
	}
	if ( temp != 0xFFE ) {
	    error = 1;
            return;
	} else {
	    switch((buffer[1] >> 3 & 0x3)) {
	    case 3:
		mh->version = 0;
                break;
	    case 2:
		mh->version = 1;
		break;
	    case 0:
		mh->version = 2;
		break;
	    default:
		error = 1;
                return;
		break;
	    }
	    mh->lay = 4 - ((buffer[1] >> 1) & 0x3);
	    mh->error_protection = !(buffer[1] & 0x1);
	    mh->bitrate_index = (buffer[2] >> 4) & 0x0F;
	    mh->sampling_frequency = (buffer[2] >> 2) & 0x3;
	    mh->padding = (buffer[2] >> 1) & 0x01;
	    mh->extension = buffer[2] & 0x01;
	    mh->mode = (buffer[3] >> 6) & 0x3;
	    mh->mode_ext = (buffer[3] >> 4) & 0x03;
	    mh->copyright = (buffer[3] >> 3) & 0x01;
	    mh->original = (buffer[3] >> 2) & 0x1;
	    mh->emphasis = (buffer[3]) & 0x3;
	    mh->stereo = (mh->mode == 3)?1:2;
	}
        f->seek( 0 );
    }

    int bitrate_of() {
        int _bitrate;
	if ( mixed err = catch( _bitrate = (error?-1:bitrate[ mh->version ][ mh->lay - 1 ][ mh->bitrate_index ]) ) ) {
	    return -1;
#ifdef DEBUG
	    perror( sprintf( "%O\n", err ) );
#endif
	} else {
	    return _bitrate;
	}
    }

}
