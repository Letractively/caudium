/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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


/*
 * include for sqlfs.pike
 *
 * $Id$
 */


class sqlfs_cache {
    /*
     * I am the object cache object.
     * -----------------------------
     * I maintain a memory cache of all things that are asked of class
     * sqlfs_read(), I also age these entries, so that if they are too old
     * by the time they are asked for again, I discard what I have and
     * leave it at that.
     * If the TTL is set to 0 then I cache things forever.
     *
     * TODO: General tidy up
     *        - Most of the functionality should be removed from the public
     *          methods and put into private ones.
     *
     */

    mapping cache;
    int ttl;
    float reqs;
    float hits;
    int verbose_status_output;

    /*
     * Constructor
     * -----------
     * This creates the empty mapping for storage, and it also
     * sets the time to live for cached objects either by an int (secs)
     * MUST BE passed to it when cloned.
     */

    void create ( int cache_for, int fart ) {
	ttl = cache_for;
	cache = ([ ]);
        verbose_status_output = fart;
    }

    /*
     * Public methods
     * --------------
     * These are the methods called by external routines, they are used to
     * store, retrieve, and check freshness of the cache.
     * Also, status() is called by the Roxen FS module to place in the config
     * interface.
     * flush() is used by some contob->set* routines to remove objects from
     * the cache, and also by the Roxen FS module if id->pragma[ "no-cache" ]
     */

    void store ( string filepath, string operation, mixed value ) {
	filepath = fix_path( filepath );
	if ( cache[ filepath ] ) {
	    cache[ filepath ] += ([ operation : ([ "value" : value,
						   "timestamp" : time()
						 ]),
				    "hits" : 0
				  ]);
	} else {
	    cache += ([ filepath : ([ operation : ([ "value" : value,
						     "timestamp" : time()
						   ]),
				      "hits" : 0
				    ])
		      ]);
	}
    }

    mixed retrieve( string filepath, string operation ) {
        filepath = fix_path( filepath );
	if ( !cache[ filepath ] ) {
	    return 0;
	} else if ( !cache[ filepath ][ operation ] ) {
	    return 0;
	} else if ( cache[ filepath ][ operation ][ "timestamp" ] < time() - ttl ) {
	    if ( ttl == 0 ) {
		cache[ filepath ][ "hits" ]++;
                return cache[ filepath ][ operation ][ "value" ];
	    } else {
                flush( filepath, operation );
		return 0;
	    }
	} else {
            cache[ filepath ][ "hits" ]++;
	    return cache[ filepath ][ operation ][ "value" ];
	}
    }

    int have( string filepath, string operation ) {
        filepath = fix_path( filepath );
	reqs++;
	if ( !cache[ filepath ] ) {
	    return 0;
	} else if ( !cache[ filepath ][ operation ] ) {
	    return 0;
	} else if ( cache[ filepath ][ operation ][ "timestamp" ] < time() - ttl ) {
	    if ( ttl == 0 ) {
		hits++;
		return 1;
	    } else {
                flush( filepath, operation );
		return 0;
	    }
	} else {
            hits++;
	    return 1;
	}
    }

    void flush( void|string filepath, void|string operation ) {
	if ( filepath ) {
            filepath = fix_path( filepath );
	    if ( operation ) {
		cache[ filepath ] = m_delete( cache[ filepath ], operation );
	    } else {
		cache = m_delete( cache, filepath );
	    }
	} else {
	    cache = ([ ]);
	}
    }

    string status() {
	string table = "";
        string indexname;
	foreach( indices( cache ), indexname ){
	    if ( verbose_status_output == 0 ) {
		if ( sizeof( cache[ indexname ] ) < 3 ) {
		    continue;
		}
	    }
	    table +=
		"<tr><td>" +
		indexname +
		"</td><td>" +
		sprintf( "%d", cache[ indexname ][ "hits" ] ) +
		"</td><td>" +
		sprintf( "%d", sizeof( cache[ indexname ] ) -1 ) +
                "</td></tr>\n";
	}
	string hitrate;
	if ( catch ( hitrate = sprintf( "%:2f", hits / reqs * 100 ) + "%" ) ) {
	    return
                "<font size=+1><b>SQL Filesystem Cache Status</b></font><br><br>\n" +
		"<b>Cache Empty</b><br><br>\n";
	}
	return
	    "<font size=+1><b>SQL Filesystem Cache Status</b></font><br><br>\n" +
	    "<b>Number of cached objects:</b> " + sprintf( "%d", sizeof( cache ) ) + "<br>\n" +
	    "<b>Cache hitrate:</b> " + hitrate + "<br>\n" +
	    // "<b>Cache TTL:</b> " + sprintf( "%d", ttl ) + "<br>\n" +
	    "<b>Cache Size (KB):</b> " + sprintf( "%d", cache_size() ) + "<br>\n" +
	    "<br>\n" +
	    "<table border=1>\n" +
	    "<tr><td colspan=3><font size=+1><b>Cache Contents</b></font></td></tr>\n" +
	    "<tr><td><b>File</b></td><td><b>Hits</b></td><td><b>Buckets used</b></td></tr>\n" +
	    table +
	    "</table>\n" +
	    "<font size=-1>(due to the way the directory parsing module looks for index files it is possible there will be files in the cache that don't exist)<font><br>\n" +
            "<br>\n";
    }

    /*
     * Private methods
     * ---------------
     * These methods are used internally to the class.
     * fix_path() is used by all the public methods to make sure that we
     * don't wind up with cache inconsistencies (ie difference between "narf"
     * and "narf/").
     */

    private int cache_size() {
	int mem = 0;
        mixed var;
	array tmpstor = ({ });
	foreach( indices( cache ), var ) {
            mixed var2;
	    foreach( indices( var ), var2 ) {
		tmpstor += ({ var2 });
	    }
	}
	foreach( indices( tmpstor ), var ) {
	    mem += sizeof( var );
	}
	tmpstor = ({ });
        return mem;
    }

    private string fix_path( string filepath ) {
        // there really must be a better way to do this!
	if ( filepath == "" ) {
	    filepath = "/";
	}
	if ( filepath[ 0 ] != '/' ) {
	    filepath = "/" + filepath;
	}
	if ( filepath[ -1 ] == '/' ) {
            filepath = filepath[ 0..sizeof( filepath ) - 2 ];
	}
	return filepath;
    }

}
