

/* This allows execution of c-code that requires the Pike interpreter to 
 * be locked from the Sablotron callback functions.
 */
#if defined(PIKE_THREADS) && defined(_REENTRANT)
#define THREAD_SAFE_RUN(COMMAND)  do {\
  struct thread_state *state;\
 if((state = thread_state_for_id(th_self()))!=NULL) {\
    if(!state->swapped) {\
      COMMAND;\
    } else {\
      mt_lock(&interpreter_lock);\
      SWAP_IN_THREAD(state);\
      COMMAND;\
      SWAP_OUT_THREAD(state);\
      mt_unlock(&interpreter_lock);\
    }\
  }\
} while(0)
#else
#define THREAD_SAFE_RUN(COMMAND) COMMAND
#endif

#define THIS ((xslt_storage *)Pike_fp->current_object->storage)
#define CURRENT ((xslt_storage *)current_object)

typedef struct
{
  struct pike_string *xml;
  struct pike_string *xsl;
  struct pike_string *base_uri;
  struct pike_string *encoding;
  struct pike_string *err_str;

  struct svalue* match_include;
  struct svalue*  open_include;
  struct svalue*  read_include;
  struct svalue* close_include;

  struct object* file;
  int iPosition;

  int xml_type, xsl_type;
  struct mapping *variables;  
  struct mapping *err;
  char *content_type, *charset;
} xslt_storage;

typedef struct {
    char* identifier;
    char* content;
    struct ContentCache* next;
} ContentCache;

typedef struct {
    xsltStylesheetPtr stylesheet;
    int time;
    struct StylesheetCache* next;
} StylesheetCache;


#ifndef ADD_STORAGE
/* Pike 0.6 */
#define ADD_STORAGE(x) add_storage(sizeof(x))
#define MY_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->hashsize; COUNT++ ) \
	for(KEY=md->hash[COUNT];KEY;KEY=KEY->next)
#else
/* Pike 7.x and newer */
#define MY_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->data->hashsize; COUNT++ ) \
	for(KEY=md->data->hash[COUNT];KEY;KEY=KEY->next)
#endif

static void f_set_xml_data(INT32 args); 
static void f_set_xml_file(INT32 args); 
static void f_set_xsl_data(INT32 args); 
static void f_set_xsl_file(INT32 args); 
static void f_set_variables(INT32 args); 
static void f_set_base_uri(INT32 args); 
static void f_parse( INT32 args );
static void f_create( INT32 args );
static void f_parse_files( INT32 args );
static void f_content_type( INT32 args );
static void f_charset( INT32 args );
static void f_set_uri_callback( INT32 args );







