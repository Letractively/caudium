#define DEFAULT_TTL 300
// Stupid arbitary number.

  mapping cache_file_object( object file, string name, void|int exp ) {
	// Use this to store a file to a cache.
	// file: The Stdio.file object that we are working with
	// name: the name of the file.
	// the expiry time of the object, -1 for never.
    if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
      exp = exp + time();
    }
    return ([
              "object" : file,
              "name" : name,
              "size" : file->stat()[1],
              "expires" : (exp?exp:time() + DEFAULT_TTL),
              "type" : "stdio",
              "ram_cache" : 1,
              "disk_cache" : 1,
              "nbio" : 1,
              "_file" : 1
           ]);
  }

  mapping cache_pike_object( mixed var, string name, void|int exp ) {
	// Use this to place any kind of pike data structure in cache.
	// var: The pike datatype being stored in RAM.
	// name: the name of the object
	// exp: the expiry time of the object, -1 for never.
    if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
      exp = exp + time();
    }
    mapping retval = ([
                      "object" : var,
                      "name" : name,
                      "size" : 0,
                      "expires" : (exp?exp:time() + DEFAULT_TTL),
                      "type" : "variable",
                      "ram_cache" : 1,
                      "disk_cache" : 0,
                      "nbio" : 0
                   ]);
    if ( intp( var ) ) {
      retval->_int = 1;
    } else if ( stringp ( var ) ) {
      retval->_string = 1;
      retval->size = sizeof( var );
      retval->disk_cache = 1;
    } else if ( arrayp( var ) ) {
      retval->_array = 1;
      retval->size = sizeof( var * "" );
    } else if ( multisetp( var ) ) {
      retval->_multiset = 1;
      retval->size = sizeof( indices( var ) * "" );
    } else if ( mappingp( var ) ) {
      retval->_mapping = 1;
      retval->size = sizeof( indices( var ) * "" ) + sizeof( values ( var * "" ) );
    } else if ( objectp( var ) ) {
      retval->_object = 1;
      retval->size = sizeof( indices( var ) * "" ) + sizeof( values ( var * "" ) );
    } else if ( functionp( var ) ) {
      retval->_function = 1;
    } else if ( programp( var ) ) {
      retval->_program = 1;
      retval->disk_cache = 1;
    }
    return retval;
  }

  mapping cache_program_object( program p, string name, void|int exp ) {
    if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
      exp = exp + time();
    }
    return ([
              "object" : p,
              "name" : name,
              "size" : 0,
              "expires" : (exp?exp:time() + DEFAULT_TTL),
              "type" : "variable",
              "ram_cache" : 1,
              "disk_cache" : 1,
              "nbio" : 0,
              "_program" : 1
            ]);
  }

  mapping cache_string_object( string s, string name, void|int exp) {
    if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
      exp = exp + time();
    }
    return ([
              "object" : s,
              "name" : name,
              "size" : sizeof( s ),
              "expires" : (exp?exp:time() + DEFAULT_TTL),
              "type" : "variable",
              "ram_cache" : 1,
              "disk_cache" : 1,
              "nbio" : 0,
              "_string" : 1
            ]);
  }
