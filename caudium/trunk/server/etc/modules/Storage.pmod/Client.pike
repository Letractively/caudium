#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK() 
#define UNLOCK()
#endif

static function _store;
static function _retrieve;
static function _unlink;
static string namespace;

void create(string _namespace, function __store, function __retrieve, function __unlink) {
  LOCK();
  _store = __store;
  _retrieve = __retrieve;
  _unlink = __unlink;
  namespace = _namespace;
}

public void store(string key, mixed val) {
  LOCK();
  _store(namespace, key, val);
}

public mixed retrieve(string key) {
  LOCK();
  return _retrieve(namespace, key);
}

public void unlink(void|string key) {
 LOCK();
 _unlink(namespace, key);
}
