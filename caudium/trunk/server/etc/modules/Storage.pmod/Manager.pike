
#include <module.h>

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
function destroy = sync_all;
function stop = sync_all;

void create(string _permstore, string path) {
  start(_permstore, path);
  storage = ([ ]);
  clients = ([ ]);
}

void start(string _permstore, string path) {
  LOCK();
  if (objectp(permstore)) {
    destruct(permstore);
  }
  switch (_permstore) {
  case "Disk":
    permstore = Storage.Methods.Disk(path);
    break;
  case "MySQL":
    permstore = Storage.Methods.MySQL(path);
    break;
  case "GDBM":
    permstore = Storage.Methods.GDBM(path);
    break;
  }
#ifdef STORAGE_DEBUG
  write("Starting storage manager with %s backed.\n", _permstore);
#endif
}

public object get_storage(string namespace) {
  LOCK();
  mapping callbacks = ([ "store" : store, "retrieve" : retrieve, "unlink" : unlink, "size" : size, "list" : list, "stop" : stop, "unlink_regexp" : unlink_regexp ]);
  if (! clients[namespace]) {
    clients += ([ namespace : Storage.Client(namespace, callbacks) ]);
  }
  return clients[namespace];
}

public mapping storage_globvar() {
  return ([
    "default" : permstore->storage_default|"",
    "name " : permstore->storage_name,
    "doc" : permstore->storage_doc
  ]);
}

public array storage_types() {
  return ({ "Disk", "MySQL", "GDBM" });
}

public string storage_default() {
  return "Disk";
}

static void store(string namespace, string key, mixed val) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Storing %s from %s\n", key, namespace);
#endif
  LOCK();
  if (! storage[ namespace ])
    storage += ([ namespace : ([]) ]);
  storage[ namespace ] += ([ key : val ]);
  UNLOCK();
  call_out( sync, SYNC_IN, namespace, key );
}

static mixed retrieve(string namespace, string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Retrieving %s from %s\n", key, namespace);
#endif
  LOCK();
  if (storage[namespace])
    if (storage[namespace][key])
      return storage[namespace][key];
  UNLOCK();
  return permstore->retrieve(namespace, key);
}

static void sync(string namespace, string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Syncing %s/%s to permanent storage\n", key, namespace);
#endif
  LOCK();
  if (storage[namespace])
    if (storage[namespace][key]) {
      permstore->store(namespace, key, storage[namespace][key]);
    }
}

static void unlink(string namespace, void|string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Removing %s in %s\n", (key?key:"all"), namespace);
#endif
  LOCK();
  if (stringp(key)) {
    if (storage[namespace])
      if (storage[namespace][key])
        m_delete(storage[namespace], key);
  }
  else
    m_delete(storage,namespace);
  UNLOCK();
  permstore->unlink(namespace, key);
}

static void unlink_regexp(string namespace, string regexp) {
  sync_all(namespace);
  permstore->unlink_regexp(namespace, regexp);
}

static void sync_all(void|string namespace) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Syncing all objects\n");
#endif
  if (namespace)
    if (storage[namespace])
      foreach(indices(storage[namespace]), string key)
        sync(namespace, key);
  foreach(indices(storage), string _namespace)
    foreach(indices(storage[_namespace]), string key)
      sync(namespace, key);
}

string storage_backend() {
  return permstore->name();
}

static int size(string namespace) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Getting total size of %s\n", namespace);
#endif
  sync_all();
  return permstore->size(namespace);
}

static array list(string namespace) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Listing objects in %s\n", namespace);
#endif
  sync_all();
  array _list = permstore->list(namespace);
  if (arrayp(_list))
    return _list;
  else
    return ({ });
}
