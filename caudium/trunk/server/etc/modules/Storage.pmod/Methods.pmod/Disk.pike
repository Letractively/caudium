
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
  if (Stdio.exist(objpath)) {
    PREFLOCK();
    FLOCK(objpath, "r", 1);
    return decode(Stdio.read_file(objpath))->value;
  }
  else
    return 0;
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  LOCK();
  PREFLOCK();
  string _path = path;
  UNLOCK();
  if (stringp(key)) {
    string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
    if (Stdio.exist(objpath)) {
      FLOCK(objpath, "w", 1);
      rm(objpath);
      FUNLOCK();
    }
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

void unlink_regexp(string namespace, string regexp) {
  PRELOCK();
  PREFLOCK();
  LOCK();
  string _path = path;
  UNLOCK();
  object r = Regexp(regexp);
  foreach(get_dir(path), string fname) {
    string objpath = Stdio.append_path(_path, fname);
    FLOCK(objpath,"r",1);
    mapping p;
    if (catch(p = decode(Stdio.read_file(objpath)))) {
      FUNLOCK();
      continue;
    }
    FUNLOCK();
    if (!mappingp(p))
      continue;
    if (p->namespace = namespace)
      if (r->match(p->key)) {
        FLOCK(objpath, "w", 1);
	rm(objpath);
	FUNLOCK();
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
  mixed val;
  catch(val = decode_value(MIME.decode_base64(data), master()->Codec()));
  return val;
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

string name() {
  return "Disk";
}

int size(string namespace) {
  PREFLOCK();
  int total;
  foreach(get_dir(path), string fname) {
    string objpath = Stdio.append_path(path, fname);
    FLOCK(objpath, "r", 1);
    mapping p;
    if (catch(p = decode(Stdio.read_file(objpath))))
      continue;
    if (!mappingp(p))
      continue;
    if (p->namespace == namespace) {
      string data = decode(Stdio.read_file(objpath))->value;
      FUNLOCK();
      total += sizeof(data);
    }
  }
}

array list(string namespace) {
  PREFLOCK();
  array ret = ({ });
  foreach(get_dir(path), string fname) {
    string objpath = Stdio.append_path(path, fname);
    FLOCK(objpath, "r", 1);
    if (decode(Stdio.read_file(objpath))->namespace == namespace) {
      string key = decode(Stdio.read_file(objpath))->key;
      ret += ({ key });
    }
    FUNLOCK();
  }
}
