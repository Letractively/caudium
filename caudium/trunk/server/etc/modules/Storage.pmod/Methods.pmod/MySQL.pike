
#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK()
#define UNLOCK()
#endif

string path;
object db;

void create(string _path) {
  path = _path;
  db = Sql.sql(path);
  if (! objectp(db))
    throw(({ "Unable to connect to SQL Database: " + path, backtrace() }));
}

void store(string namespace, string key, string value) {
}

mixed retrieve(string namespace, string key) {
}

void flush(string namespace) {
}
