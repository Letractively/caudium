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
static function _unlink_regexp;
static function _size;
static function _list;
static function _stop;
static string namespace;

void create(string _namespace, mapping callbacks) {
  LOCK();
  _store = callbacks->store;
  _retrieve = callbacks->retrieve;
  _unlink = callbacks->unlink;
  _unlink_regexp = callbacks->unlink_regexp;
  _size = callbacks->size;
  _list = callbacks->list;
  _stop = callbacks->stop;
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

public void unlink_regexp(void|string regexp) {
  LOCK();
  _unlink_regexp(namespace, regexp);
}

public int size() {
 LOCK();
 return _size(namespace);
}

public array list() {
  return _list(namespace);
}

public void stop() {
  _stop(namespace);
}
