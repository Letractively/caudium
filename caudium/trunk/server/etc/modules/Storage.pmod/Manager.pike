
#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK() 
#define UNLOCK()
#endif

#define SYNC_IN 30

static mapping storage;
static object permstore;
static mapping clients;

void create(string _permstore, string path) {
  LOCK();
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
}

public object get_storage(string namespace) {
  LOCK();
  if (! clients[namespace]) {
    clients += ([ namespace : Storage.Client(namespace,store,retrieve,flush) ]);
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

static void flush(string namespace) {
  LOCK();
  m_delete(storage,namespace);
  UNLOCK();
  permstore->flush();
}
