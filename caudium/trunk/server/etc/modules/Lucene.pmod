#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

string cvs_version = "$Id$";

#if constant(Java)

class Indexer
{

static constant jvm = Java.machine;

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))
static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");

static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");
static object dictionary_class = FINDCLASS("java/util/Dictionary");
static object arraylist_class = FINDCLASS("java/util/ArrayList");
static object list_class = FINDCLASS("java/util/List");
static object hashmap_class = FINDCLASS("java/util/HashMap");
static object collection_class = FINDCLASS("java/util/Collection");
static object string_class = FINDCLASS("java/lang/String");

static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");


static object arraylist_init = arraylist_class->get_method("<init>", "()V");
static object arraylist_get = list_class->get_method("get", "(I)Ljava/lang/Object;");
static object arraylist_size = collection_class->get_method("size", "()I");
static object hashmap_get = hashmap_class->get_method("get", "(Ljava/lang/Object;)Ljava/lang/Object;");


static object index_class = FINDCLASS("net/caudium/search/Indexer");
static object summary_class = FINDCLASS("net/caudium/search/URLSummary");

static object index_init = index_class->get_method("<init>", "(Ljava/lang/String;Z)V");
static object summary_init = summary_class->get_method("<init>", "()V");
static object index_close = index_class->get_method("close", "()V");
static object index_add = index_class->get_method("add", "(Lnet/caudium/search/URLSummary;)V");

static object summary_url=summary_class->get_field("url", "Ljava/lang/String;");
static object summary_body=summary_class->get_field("body", "Ljava/lang/String;");
static object summary_desc=summary_class->get_field("desc", "Ljava/lang/String;");
static object summary_title=summary_class->get_field("title", "Ljava/lang/String;");
static object summary_type=summary_class->get_field("type", "Ljava/lang/String;");
static object summary_date=summary_class->get_field("date", "Ljava/lang/String;");

object ie;

void create(string datadir)
{
  ie=index_class->alloc();
  index_init(ie, datadir, 0);
  check_exception();
}

void destroy()
{
  index_close(ie);
}
 
void close()
{
  index_close(ie);
}

int index(string uri, string data, string title, string type, string date)
{
  //werror(data + "\n\n");
  object us=summary_class->alloc();
  check_exception();
  summary_init(us);
  check_exception();
  summary_url->set(us, uri);
  check_exception();
  summary_body->set(us, data);
  check_exception();
  summary_title->set(us, title);
  check_exception();
  summary_desc->set(us, (sizeof(data)<254?data:data[0..253]+"..."));
  check_exception();
  summary_date->set(us, date);
  check_exception();
  summary_type->set(us, type);
  check_exception();
  index_add(ie, us);
  check_exception();
//werror((string)us);
  return 1;
}

#define error(X) throw(({(X), backtrace()})) 
static void check_exception() {
 jvm->exception_describe();
}

}

class Index
{

static constant jvm = Java.machine;

static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");

static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");
static object dictionary_class = FINDCLASS("java/util/Dictionary");
static object arraylist_class = FINDCLASS("java/util/ArrayList");
static object list_class = FINDCLASS("java/util/List");
static object hashmap_class = FINDCLASS("java/util/HashMap");
static object collection_class = FINDCLASS("java/util/Collection");
static object string_class = FINDCLASS("java/lang/String");

static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");


static object arraylist_init = arraylist_class->get_method("<init>", "()V");
static object arraylist_get = list_class->get_method("get", "(I)Ljava/lang/Object;");
static object arraylist_size = collection_class->get_method("size", "()I");
static object hashmap_get = hashmap_class->get_method("get", "(Ljava/lang/Object;)Ljava/lang/Object;");


static object search_class = FINDCLASS("net/caudium/search/Search");
static object search_init = search_class->get_method("<init>", "(Ljava/lang/String;)V");
static object search_search = search_class->get_method("search", "(Ljava/lang/String;)Ljava/util/ArrayList;");

object se;

void create(string dbdir)
{
  se=search_class->alloc();
  search_init(se, dbdir);
  check_exception();
}

void search(string q)
{
  object r=search_search(se,q);
  for(int i=0; i< arraylist_size(r); i++)
  {
     object re=arraylist_get(r, i);
     werror((string)hashmap_get(re,"url")  + "\n");
     werror((string)hashmap_get(re,"title")  + "\n");
     werror((string)hashmap_get(re,"type")  + "\n");
     werror((string)hashmap_get(re,"date")  + "\n");
     werror((string)hashmap_get(re,"desc")  + "\n");
     werror("\n");
  }
}

#define error(X) throw(({(X), backtrace()})) 
static void check_exception() {
 jvm->exception_describe();
}

}


#endif


