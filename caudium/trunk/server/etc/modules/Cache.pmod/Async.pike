inherit "cachelib";

object in, out;
function store, retrieve;
string data, name;
int exp;

void create(function _store, function _retrieve, string _name, object _in, object _out, void|int _exp) {
  in = _in;
  out = _out;
  store = _store;
  retrieve = _retrieve;
  data = "";
  exp = (_exp?_exp:300);
  in->set_buffer(8192000);
  out->set_buffer(8192000);
  in->set_nonblocking(read, 0, close);
}

static void read(mixed id, string _data) {
  out->write(_data);
  data += _data;
}

static void close() {
  in->close();
  out->close();
  object pipe_in = Stdio.File();
  object pipe_out = pipe_in->pipe();
  pipe_in->write(data);
  store(cache_file(name, pipe_out, exp));
}
