#ifndef _CAUDIUM_H_
#define _CAUDIUM_H_
static void f_parse_headers( INT32 args );
static void f_parse_query_string( INT32 args );
void pike_module_init( void );
void pike_module_exit( void );
void free_buf_struct(struct object *);

#define BUFSIZE 16535
#define BUF ((buffer *)fp->current_object->storage)
#define STRS(x) strs.x.u.string
#define SVAL(x) (&(strs.x))
typedef struct
{
  struct svalue data;
  struct svalue file;
  struct svalue method;
  struct svalue protocol;
  struct svalue query;
  struct svalue raw_url;

  struct pike_string *h_clength;
  struct pike_string *h_auth;
  struct pike_string *h_proxyauth;
  struct pike_string *h_pragma;
  struct pike_string *h_useragent;
  struct pike_string *h_referrer;
  struct pike_string *h_range;
  struct pike_string *h_conn;
  struct pike_string *h_ctype;
  
} static_strings;


typedef struct
{
  char data[BUFSIZE];
  char *pos;
  int free;
  struct mapping *headers;
  struct mapping *other;
} buffer;

#ifdef NEW_MAPPING_LOOP
/* Pike 7.x and newer */
#define MY_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->data->hashsize; COUNT++ ) \
	for(KEY=md->data->hash[COUNT];KEY;KEY=KEY->next)
#else
/* Pike 0.6 */
#define MY_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->hashsize; COUNT++ ) \
	for(KEY=md->hash[COUNT];KEY;KEY=KEY->next)
#endif


#ifndef MIN
#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#endif
#ifndef MAX
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#endif
#endif
