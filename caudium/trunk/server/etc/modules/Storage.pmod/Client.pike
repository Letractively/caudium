
static function _store;
static function _retrieve;
static function _flush;
static string namespace;

void create(string _namespace, function __store, function __retrieve, function __flush) {
  _store = __store;
  _retrieve = __retrieve;
  _flush = __flush;
  namespace = _namespace;
}

public void store(string key, mixed val) {
  _store(namespace, key, val);
}

public mixed retrieve(string key) {
  return _retrieve(namespace, key);
}

public void flush() {
 _flush(namespace);
}
