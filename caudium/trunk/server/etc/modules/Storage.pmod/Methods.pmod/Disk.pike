
#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK()
#define UNLOCK()
#endif

string path;

void create(string _path) {
  path = _path;
}

void store(string namespace, string key, string value) {
}

mixed retrieve(string namespace, string key) {
}

void flush(string namespace) {
}
