
#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define PRELOCK() object __key
#define LOCK() __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define PRELOCK()
#define LOCK()
#define UNLOCK()
#endif

#ifdef NFS_LOCK
static object hitch = HitchingPost;
#define PREFLOCK() object __fkey
#define FLOCK(X, Y, Z) __fkey = hitch->lock(X, Y, Z)
#define FUNLOCK() destruct(__fkey);
#else
#define PREFLOCK()
#define FLOCK(X,Y,Z) ({X, Y, Z})
#define FUNLOCK()
#endif

static string path;

void create(string _path) {
  PRELOCK();
  LOCK();
  path = Stdio.append_path(_path, sprintf("%d.%d.%d", __MAJOR__, __MINOR__, __BUILD__));
  if (!Stdio.is_dir(path))
    Stdio.mkdirhier(path);
}

void store(string namespace, string key, string value) {
  PRELOCK();
  LOCK();
  string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
  PREFLOCK();
  FLOCK(objpath, "w", 1);
  Stdio.write_file(objpath, encode(namespace, key, value));
}

mixed retrieve(string namespace, string key) {
  PRELOCK();
  LOCK();
  string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
  PREFLOCK();
  FLOCK(objpath, "r", 1);
  return decode(Stdio.read_file(objpath))->value;
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  LOCK();
  PREFLOCK();
  string _path = path;
  UNLOCK();
  if (stringp(key)) {
    string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
    FLOCK(objpath, "w", 1);
    rm(objpath);
  }
  else {
    foreach(get_dir(_path), string fname) {
      string objpath = Stdio.append_path(_path, fname);
      if (decode(Stdio.read_file(objpath))->namespace == namespace) {
        FLOCK(objpath, "w", 1);
        rm(objpath);
	FUNLOCK();
      }
    }
  }
}

static string encode(string namespace, string key, string value) {
  mapping p = ([
    "namespace" : namespace,
    "key"       : key,
    "value"     : value
  ]);
  return MIME.encode_base64(encode_value(p,master()->Codec()), 1);
}

static mixed decode(string data) {
  return decode_value(MIME.decode_base64(data), master()->Codec());
}

static string get_hash( string data ) {
  string retval;
#if constant(_Lobotomized_Crypto)
  retval = _Lobotomized_Crypto.md5()->update( data )->digest();
#elseif constant(Crypto)
  retval = Crypto.md5()->update( data )->digest();
#else
  retval = MIME.encode_base64( data );
#endif
  return sprintf("%@02x",(array(int)) retval);
}
