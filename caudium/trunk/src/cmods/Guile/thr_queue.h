/* tqueue.h --
 *
 * Structures for thread queue
 */

/* An entry in the queue */
typedef struct thr_queue_entry {
  char *code;
  struct thr_queue_entry *next;
} thr_queue_entry_t;

typedef struct thr_queue {
  int max_size;
  int size;
  thr_queue_entry_t *q_head;
  thr_queue_entry_t *q_tail;
  
  /* Thread queue synchronization variables */
  PIKE_MUTEX_T q_lock;
  COND_T q_not_empty;
  COND_T q_not_full;
} thr_queue_t;

void thr_queue_init(int);
int thr_queue_write(char *);
thr_queue_entry_t *thr_queue_read(void);
