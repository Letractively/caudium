#ifndef _CAUDIUM_H_
#define _CAUDIUM_H_
#include "caudium_machine.h"

#if defined(HAVE_MMAP) && defined(HAVE_MUNMAP)
#define USE_MMAP 1
#endif

#include <sys/time.h>
#include <sys/resource.h>

void pike_module_init( void );
void pike_module_exit( void );
#ifdef ENABLE_NBIO
void init_nbio(void);
void exit_nbio(void);
#endif /* ENABLE_NBIO */

/* The size of the mmap window used for large files. For busy sites,
 * you might  have to lower this value if you run out of process address
 * space. It should be a multiple of PAGESIZE (4096 bytes?)
 */
#define MAX_MMAP_SIZE    2097152 /* mmap at most 2 MB at once */

/* Size of the buffer used when reading data from files (when mmap
 * can't be used
 */
#define READ_BUFFER_SIZE 65536

#define BUFSIZE        16535
#define BUFSIZE_MIN    100
#define BUFSIZE_MAX    (1024*1024)
#define BUF ((buffer *)Pike_fp->current_storage)
#define STRS(x) strs.x.u.string
#define SVAL(x) (&(strs.x))

struct plimit
{
  int resource;
  struct rlimit rlp;
  struct plimit *next;
};

struct perishables
{
  char **env;
  char **argv;

  int *fds;

  int disabled;
  struct plimit *limits;

#ifdef HAVE_SETGROUPS
  gid_t *wanted_gids;
  struct array *wanted_gids_array;
  int num_wanted_gids;
#endif
};

typedef struct
{
  struct svalue data;
  struct svalue file;
  struct svalue method;
  struct svalue protocol;
  struct svalue query;
  struct svalue raw_url;
  struct svalue mta_slash;
  struct svalue mta_equals;
  PCHARP        mta_equals_p;
  
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
  unsigned char  *pos;
  unsigned        free;
  struct mapping *headers;
  struct mapping *other;
  unsigned char  *data;
} buffer;

#ifdef ENABLE_NBIO

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
  NBIO_INT_T len;        /* Length of input, or -1 for 'till end' for files */
  NBIO_INT_T pos;        /* current position    */
  enum { NBIO_STR,       /* string buffer       */
	 NBIO_OBJ,       /* non-blocking object */
	 NBIO_BLOCK_OBJ /* blocking object     */
#ifdef USE_MMAP
	 , NBIO_MMAP     /* mmapped file        */ 
#endif
  } type;
  union {
    struct object *file;      /* Pike file object */
    struct pike_string *data; /* Data */
#ifdef USE_MMAP
    mmap_data *mmap_storage;               /* mmap memory area */
#endif
  } u;
  int read_off;
  int set_b_off;
  int set_nb_off;
  int fd; /* Numerical FD or -1 if fake object */
  enum { SLEEPING, READING } mode;
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
  enum { IDLE, ACTIVE } mode;
} output;

typedef struct
{
  NBIO_INT_T written;
  unsigned int finished : 1; 
  int buf_size; 	/* allocated size of buf */
  int buf_len;  	/* Length of data to read */
  int buf_pos;  	/* Current position in buffer */
  char *buf;    	/* The buffer pointer */
  output *outp; 	/* The output */
  input *inputs; 	/* The first input in the linked list */
  input *last_input;    /* Pointer to the last input */
  struct svalue args;   /* Optional arguments to callback function */
  struct svalue cb;     /* Callback function */
  
} nbio_storage;         /* nbio object storage */

#endif /* ENABLE_NBIO */

#ifndef MIN
#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#endif
#ifndef MAX
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#endif

extern void do_set_close_on_exec(void);
#endif
