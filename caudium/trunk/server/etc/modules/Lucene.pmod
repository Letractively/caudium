#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

string cvs_version = "$Id$";

#if constant(Java)

static constant jvm = Java.machine;

static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");

static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");
static object throwable_getmessage = throwable_class->get_method("getMessage", "()Ljava/lang/String;");

import Parser.XML.Tree;

mapping read_profile(string filename)
{
  mapping profile=([]);

  if(!file_stat(filename))
  {
    error("profile " + filename + " does not exist.\n");
  }

  string f=Stdio.read_file(filename);
  if(!f)
  {
    error("profile " + filename + " is empty.\n");
  }
  
  Node configxml = Parser.XML.Tree->parse_input(f);
  
  configxml->iterate_children(lambda(Node c, mapping profile){
    if(c->get_tag_name()=="profile") c->iterate_children(parse_profile, profile);}, profile);
  
  return profile;
}

private void parse_profile(Node p, mapping profile)
{
  if(p->get_node_type()==XML_ELEMENT)
    switch(p->get_tag_name())
    {
      case "indexer":
      case "crawler":
      case "index":
      case "converters":
        p->iterate_children(parse_section, p->get_tag_name(), profile);
        break;

      default:
        error("unknown profile section " + p->get_tag_name() + "\n");
    }
}

private void parse_section(Node s, string sect, mapping profile)
{
  if(s->get_node_type()==XML_ELEMENT)
  {
    if(!profile[sect])
      profile[sect]=([]);
    if(!profile[sect][s->get_tag_name()])
      profile[sect][s->get_tag_name()]=({});
    profile[sect][s->get_tag_name()]+=({ s->get_attributes() + (["value":s->value_of_node() ]) });
  }

}



void check_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    jvm->exception_clear();
    object sw = stringwriter_class->alloc();
    stringwriter_init(sw);
    object pw = printwriter_class->alloc();
    printwriter_init(pw, sw);
/*
    if (e->is_instance_of(servlet_exc_class))
      {
        object re = servlet_exc_getrootcause(e);
        if (re)
          throwable_printstacktrace(re, pw);
      }
*/
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
    array bt = backtrace();
    // FIXME: KLUDGE: Sometimes the cast fails for some reason.
    string s = "Unknown Java exception (StringWriter failed)";
    catch {
      s = (string)sw;
    };
    throw(({s, bt[..sizeof(bt)-2]}));
  }
}

class Indexer
{

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))
static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");

static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

static object dictionary_class = FINDCLASS("java/util/Dictionary");
static object arraylist_class = FINDCLASS("java/util/ArrayList");
static object list_class = FINDCLASS("java/util/List");
static object hashmap_class = FINDCLASS("java/util/HashMap");
static object collection_class = FINDCLASS("java/util/Collection");
static object string_class = FINDCLASS("java/lang/String");

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
  Lucene->check_exception();
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
  data=replace(data, ({"\r", "\n"}), ({" ", " "}));

  data=(((data/" ")-({""}))*" ");

  //werror(data + "\n\n");
  object us=summary_class->alloc();
  Lucene->check_exception();
  summary_init(us);
  Lucene->check_exception();
  summary_url->set(us, uri);
  Lucene->check_exception();
  summary_body->set(us, data);
  Lucene->check_exception();
  summary_title->set(us, title);
  Lucene->check_exception();
  summary_desc->set(us, (sizeof(data)<254?data:data[0..253]+"..."));
  Lucene->check_exception();
  summary_date->set(us, date);
  Lucene->check_exception();
  summary_type->set(us, type);
  Lucene->check_exception();
  index_add(ie, us);
  Lucene->check_exception();
//werror((string)us);
  return 1;
}
  class PikeFilter(function convert)
  {

  }

  class Filter(string command)
  {
    string convert(string data)
    {
       string ret="";
       object i=Stdio.File();
       object o=Stdio.File();
       object e=Stdio.File();
       array args=command/" ";

       object p=Process.create_process(args, (["stdin": i->pipe(), "stdout": o->pipe(), "stderr": 
         e->pipe()]));

       i->write(data);
       i->close();

       mixed r;
       do
       {  
         r=o->read(1024, 1);
         if(sizeof(r)>0)
           ret+=r;
         else break;
       } 
       while(1);
	werror(e->read(1024,1));
       return ret;
    }
  }

  class Converter(string command, string tempdir)
  {
    int i=0;

    string convert(string data)
    {
       string ret="";
       i++;       
       string tempfile=MIME.encode_base64(Crypto.md5()->update(data + i)->update((string)time())->digest());

       tempfile=(string)hash(tempfile);
       tempfile=combine_path(tempdir, tempfile);
       command=replace(command, "%f", tempfile );
       array args=command/" ";

       Stdio.write_file(tempfile, data);

       object o=Stdio.File();
       object e=Stdio.File();
       object p=Process.create_process(args, (["stdout": o->pipe(), "stderr": e->pipe()]));

      
       mixed r;
       do
       {  
         r=o->read(1024, 1);
//werror("r: " + r + "\n");
         if(sizeof(r)>0)
           ret+=r;
         else break;
       } 
       while(1);
       werror(e->read(1024,1));
//       rm(tempfile);

       return ret;
    }
  }
}

class Index
{

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
  Lucene->check_exception();
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

}


#endif


