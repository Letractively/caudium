
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
#define DB() get_database()

static string sqlurl;
static string version = sprintf("%d.%d.%d", __MAJOR__, __MINOR__, __BUILD__); 
static object db;

void create(string _sqlurl) {
  PRELOCK();
  LOCK();
  sqlurl = _sqlurl;
  if (catch(Sql.sql(sqlurl)))
    throw(({"Unable to connect to database", backtrace()}));
  UNLOCK();
  init_tables();
}

void store(string namespace, string key, string value) {
  PRELOCK();
  object db = DB();
  LOCK();
  array res = db->query("select dkey from storage where namespace = %s and dkey = %s", namespace, key);
  if (sizeof(res) > 0)
    db->query("delete from storage where namespace = %s and dkey = %s", namespace, key);
  db->query("insert into storage values (%s, %s, %s, %s)", version, namespace, key, value);
}

mixed retrieve(string namespace, string key) {
  PRELOCK();
  object db = DB();
  LOCK();
  return db->query("select value from storage where namespace = %s and dkey = %s", namespace, key)[0]->value;
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  object db = DB();
  LOCK();
  if (stringp(key))
    db->query("delete from storage where namespace = %s and dkey = %s", namespace, key);
  else
    db->query("delete from storage where namespace = %s", namespace);
}

static object get_database() {
  PRELOCK();
  LOCK();
  if (!objectp(db))
    db = Sql.sql(sqlurl);
  return db;
}

static object init_tables() {
  PRELOCK();
  object db = DB();
  LOCK();
  multiset tables = (multiset)db->list_tables();
  if (!tables->storage)
    db->query(
      "create table storage(\n"
      "  pike_version varchar(255),\n"
      "  namespace varchar(250),\n"
      "  dkey varchar(250),\n"
      "  value longblob,\n"
      "  UNIQUE KEY storage (namespace, dkey)\n"
      ")"
    );
  else
    db->query("delete from storage where pike_version != %s", version);
}

string name() {
  return "MySQL";
}
