#ifndef _CAUDIUM_H_
#define _CAUDIUM_H_
#include "caudium_machine.h"

#if defined(HAVE_MMAP) && defined(HAVE_MUNMAP)
#define USE_MMAP 1
#endif


static void f_parse_headers( INT32 args );
static void f_parse_query_string( INT32 args );
void pike_module_init( void );
void pike_module_exit( void );
static void free_buf_struct(struct object *);
static void alloc_buf_struct(struct object *);
void init_nbio(void);
void exit_nbio(void);

/* The size of the mmap window used for large files. For busy sites,
 * you might  have to lower this value if you run out of process address
 * space. It should be a multiple of PAGESIZE (4096 bytes?)
 */
#define MAX_MMAP_SIZE    2097152 /* mmap at most 2 MB at once */

/* Size of the buffer used when reading data from files (when mmap
 * can't be used
 */
#define READ_BUFFER_SIZE 65536

#define BUFSIZE 16535
#define BUF ((buffer *)Pike_fp->current_storage)
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
  unsigned char *pos;
  int free;
  struct mapping *headers;
  struct mapping *other;
  unsigned char *data;
} buffer;

#ifdef INT64
# define push_nbio_int(X) push_int64(X)
# define NBIO_INT_T INT64
#else
# define push_nbio_int(X) push_int(X)
# define NBIO_INT_T INT32
#endif

#ifdef USE_MMAP
typedef struct
{
  struct object *file; /* the Stdio.File object, kept for reference sake */
  char *data; /* mmapped data */
  unsigned NBIO_INT_T m_start; /* Start of mmapped area */
  unsigned NBIO_INT_T m_end;   /* End of mmapped area */
  unsigned NBIO_INT_T m_len;   /* Lengh of mmapped area */
} mmap_data;
#endif


/* Input data (object or string) */
typedef struct _input_struct
{
  NBIO_INT_T len;  /* Length of input, or -1 for 'till end' for files */
  NBIO_INT_T pos;  /* current position */
  enum { NBIO_STR, NBIO_OBJ
#ifdef USE_MMAP
	 , NBIO_MMAP
#endif
  } type;
  union {
    struct object *file;      /* Pike file object */
    struct pike_string *data; /* Data */
#ifdef USE_MMAP
    mmap_data *mmap;               /* mmap memory area */
#endif
  } u;
  int read_off;
  int fd; /* Numerical FD or -1 if fake object */
  struct _input_struct *next;
} input;

/* Output data (fd or fake fd) */
typedef struct
{
  struct object *file;      /* Pike file object */
  int set_b_off;
  int set_nb_off;
  int write_off;
  int fd; /* Numerical FD or -1 if fake object */
} output;

typedef struct
{
  NBIO_INT_T written;
  int buf_len;
  int buf_pos;
  char *buf;
  output *outp;
  input *inputs;
  input *last_input;
  struct pike_string *objread;
  struct svalue args;
  struct svalue cb;

} nbio_storage;

#ifndef MIN
#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#endif
#ifndef MAX
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#endif
#endif
