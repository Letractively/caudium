
#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK() 
#define UNLOCK()
#endif

#define SYNC_IN 5

static mapping storage;
static object permstore;
static mapping clients;

void create(string _permstore, string path) {
  start(_permstore, path);
}

void start(string _permstore, string path) {
  LOCK();
  if (objectp(permstore)) {
    destruct(permstore);
  }
  storage = ([]);
  clients = ([]);
  switch (_permstore) {
  case "Disk":
    permstore = Storage.Methods.Disk(path);
    break;
  case "MySQL":
    permstore = Storage.Methods.MySQL(path);
    break;
  }
#ifdef STORAGE_DEBUG
  write("Starting storage manager with %s backed.\n", _permstore);
#endif
}

public object get_storage(string namespace) {
  LOCK();
  if (! clients[namespace]) {
    clients += ([ namespace : Storage.Client(namespace,store,retrieve,unlink) ]);
  }
  return clients[namespace];
}

static void store(string namespace, string key, mixed val) {
  LOCK();
  if (! storage[ namespace ])
    storage += ([ namespace : ([]) ]);
  storage[ namespace ] += ([ key : val ]);
  UNLOCK();
  call_out( sync, SYNC_IN, namespace, key );
}

static mixed retrieve(string namespace, string key) {
  LOCK();
  if (storage[namespace])
    if (storage[namespace][key])
      return storage[namespace][key];
  UNLOCK();
  return permstore->retrieve(namespace, key);
}

static void sync(string namespace, string key) {
  LOCK();
  if (storage[namespace])
    if (storage[namespace][key]) {
      permstore->store(namespace, key, storage[namespace][key]);
    }
}

static void unlink(string namespace, void|string key) {
  LOCK();
  if (stringp(key)) {
    if (storage[namespace][key])
      m_delete(storage[namespace], key);
  }
  else
    m_delete(storage,namespace);
  UNLOCK();
  permstore->unlink(key);
}

void destroy() {
  stop();
}

void stop() {
  foreach(indices(storage), string namespace)
    foreach(indices(storage[namespace]), string key)
      sync(namespace, key);
}

string storage_backend() {
  return permstore->name();
}
