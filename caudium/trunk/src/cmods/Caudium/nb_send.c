/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/* Non-blocking sending of a string and/or data from a file object
 * to another file object. I.e data pipe function. */

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "caudium.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#ifdef HAVE_SYS_MMAN_H
#include <sys/mman.h>
#else
#ifdef HAVE_LINUX_MMAN_H
#include <linux/mman.h>
#else
#ifdef HAVE_MMAP
/* sys/mman.h is _probably_ there anyway. */
#include <sys/mman.h>
#endif
#endif
#endif

#ifndef S_ISREG
#ifdef S_IFREG
#define S_ISREG(mode)   (((mode) & (S_IFMT)) == (S_IFREG))
#else
#define S_ISREG(mode)   (((mode) & (_S_IFMT)) == (_S_IFREG))
#endif
#endif
#ifdef USE_MMAP
#ifndef MAP_FILE
# define MAP_FILE 0
#endif
#ifndef MAP_FAILED
# define MAP_FAILED -1
#endif
#endif
#define THIS ((nbio_storage *)(Pike_fp->current_storage))
#define THISOBJ (Pike_fp->current_object)

extern int fd_from_object(struct object *o);

/*#define NB_DEBUG*/
#ifdef NB_DEBUG
# define DERR(X) do { fprintf(stderr, "** Caudium.nbio: "); X; } while(0)
#else
# define DERR(X) 
#endif

static int output_write_cb_off;
static int input_read_cb_off;
static int input_close_cb_off;
static struct program *nbio_program;

/* Statistics for flashy output */
static int noutputs;  /* number of outputs */
static int ninputs;   /* number of inputs */
static int nstrings;  /* number of string inputs */
static int nobjects;  /* number of in/out objects  */
static NBIO_INT_T mmapped;  /* size of mmapped data */
static int nbuffers;  /* number of allocated buffers */
static int sbuffers;  /* size of allocated buffers */			

/* Push a callback to this object given the internal function number.
 */
static void push_callback(int no)
{
  add_ref(Pike_sp->u.object = THISOBJ);
  Pike_sp->subtype = no + Pike_fp->context.identifier_level;
  Pike_sp->type = T_FUNCTION;
  Pike_sp++;
}

/* allocate / initialize the struct */
static void alloc_nb_struct(struct object *obj) {
  THIS->inputs     = NULL;
  THIS->last_input = NULL;
  THIS->outp       = NULL;
  THIS->buf        = NULL;
  THIS->cb.type    = T_INT;
  THIS->args.type  = T_INT;
  THIS->args.u.integer = 0;
  THIS->buf_len    = 0;
  THIS->buf_pos    = 0;
  THIS->buf_size   = 0;
  THIS->written    = 0;
  THIS->finished   = 0;
}

/* Free an input */
static INLINE void free_input(input *inp) {
  DERR(fprintf(stderr, "Freeing input 0x%x\n", (unsigned int)inp));
  ninputs--;
  switch(inp->type) {
   case NBIO_STR: 
    free_string(inp->u.data);
    nstrings--;
    break;
#ifdef USE_MMAP
   case NBIO_MMAP:
    if(inp->u.mmap_storage->data != MAP_FAILED) {
      munmap(inp->u.mmap_storage->data, inp->u.mmap_storage->m_len);
      mmapped -= inp->u.mmap_storage->m_len;
    }
    free_object(inp->u.mmap_storage->file);
    free(inp->u.mmap_storage);
    break;
#endif
   case NBIO_OBJ:
    apply_low(inp->u.file, inp->set_b_off, 0);
    pop_stack();
    /* FALL THROUGH */
    
   case NBIO_BLOCK_OBJ:
    free_object(inp->u.file);
    nobjects--;
    break;
    
  }
  if(THIS->last_input == inp)
    THIS->last_input = NULL;
  THIS->inputs = inp->next;
  if(!THIS->finished && THIS->inputs && THIS->inputs->type == NBIO_OBJ) {
    /* Aha! Set read callback here */
    push_callback(input_read_cb_off);
    push_int(0);
    push_callback(input_close_cb_off);
    apply_low(THIS->inputs->u.file, THIS->inputs->set_nb_off, 3);
    THIS->inputs->mode = READING;    
  }
  free(inp);
}

/* Allocate new input object and add it to our list */
static INLINE void new_input(struct svalue inval, NBIO_INT_T len, int first) {
  struct stat s;
  input *inp;

  inp = malloc(sizeof(input));
  if(inp == NULL) {
    Pike_error("Out of memory!\n");
    return;
  }

  inp->pos  = 0;
  inp->mode = SLEEPING;
  
  DERR(fprintf(stderr, "Allocated new input at 0x%x\n", (unsigned int)inp));

  if(inval.type == T_STRING) {
    inp->type   = NBIO_STR;
    add_ref(inp->u.data = inval.u.string);
    inp->len = len ? len : inval.u.string->len << inval.u.string->size_shift;
    nstrings++;
    DERR(fprintf(stderr, "string input added: %ld bytes\n", (long)inp->len));
  } else if(inval.type == T_OBJECT) {
    inp->fd     = fd_from_object(inval.u.object);
    inp->len    = len;
    if(inp->fd == -1) {
      inp->u.file = inval.u.object;
      inp->type   = NBIO_BLOCK_OBJ; /* Not an actual FD, use blocking IO */

      DERR(fprintf(stderr, "input object not a real FD\n"));
      if ((inp->read_off = find_identifier("read", inp->u.file->prog)) < 0) {
	free(inp);
	Pike_error("Caudium.nbio()->input: Illegal file object, "
		   "missing read()\n");
	return;
      }
      add_ref(inp->u.file);
      nobjects++;
    } else {
      inp->type   = NBIO_OBJ;
#ifdef USE_MMAP
      if (fstat(inp->fd, &s) == 0 && S_ISREG(s.st_mode)) 
      {
	char *mtmp;
	unsigned NBIO_INT_T filep = lseek(inp->fd, 0L, SEEK_CUR);
	int alloc_len = MIN(s.st_size - filep, MAX_MMAP_SIZE);
	mtmp = (char *)mmap(0, alloc_len, PROT_READ, MAP_FILE | MAP_SHARED,
			    inp->fd, filep);
	if(mtmp != MAP_FAILED)
	{
	  if( (inp->u.mmap_storage = malloc(sizeof(mmap_data))) == NULL) {
	    Pike_error("Failed to allocate mmap structure. Out of memory?\n");
	  }
	  inp->type   = NBIO_MMAP;
	  inp->len    = s.st_size;
	  inp->pos    = filep;

	  inp->u.mmap_storage->data    = mtmp;
	  inp->u.mmap_storage->m_start = filep;
	  inp->u.mmap_storage->m_len   = alloc_len;
	  inp->u.mmap_storage->m_end   = filep + alloc_len;
	  add_ref(inp->u.mmap_storage->file = inval.u.object);
	  
	  DERR(fprintf(stderr, "new mmap input (fd %d)\n", inp->fd));
	  mmapped += alloc_len;
#ifdef NB_DEBUG
	} else {
	  DERR(perror("mmap failed"));
#endif
	}
      }
#endif
      if(inp->type == NBIO_OBJ) {
	/* mmap failed or not a regular file. We'll use non-blocking IO
	 * here, to support pipes and such (which are actual fds, but can
	 * block). Typical example is CGI.
	 */
	int snbo;
	inp->u.file = inval.u.object;
	inp->set_nb_off = find_identifier("set_nonblocking",inp->u.file->prog);
	inp->set_b_off  = find_identifier("set_blocking", inp->u.file->prog);
	
	if(inp->set_nb_off < 0 || inp->set_b_off < 0)
	{
	  free(inp);
	  Pike_error("set_nonblocking and/or set_blocking missing from actual file object!\n");
	}
	add_ref(inp->u.file);
	nobjects++;
	DERR(fprintf(stderr, "new input FD == %d\n", inp->fd));
      }
    }
  }

  ninputs++;

  if(first) {
    /* Add first in list */
    inp->next = THIS->inputs;
    THIS->inputs = inp;
  } else {
    inp->next = NULL;
    if (THIS->last_input)
      THIS->last_input->next = inp;
    else
      THIS->inputs = inp;
    THIS->last_input = inp;
  }
}



/* Allocate the temporary read buffer */
static INLINE void alloc_data_buf(int size) {
  if(THIS->buf == NULL) {
    THIS->buf = malloc(size);
    nbuffers ++;
  } else {
    sbuffers -= THIS->buf_size;
    THIS->buf = realloc(THIS->buf, size);
  }
  if(THIS->buf == NULL) {
    nbuffers --;
    Pike_error("Failed to allocate read buffer.\n");
  }
  sbuffers += size;
  THIS->buf_size = size;
}

/* Allocate the temporary read buffer */
static INLINE void free_data_buf(void) {
  if(THIS->buf != NULL) {
    free(THIS->buf);
    nbuffers --;
    sbuffers -= THIS->buf_size;
    THIS->buf = NULL;
    THIS->buf_size = 0;
  }
}

/* free output object */
static INLINE  void free_output(output *outp) {
  noutputs--;
  free_object(outp->file);
  free(outp);
}

/* Free any allocated data in the struct */
static void free_nb_struct(struct object *obj) {
  while(THIS->inputs != NULL) {
    free_input(THIS->inputs);
  }

  if(THIS->outp != NULL) {
    free_output(THIS->outp);
    THIS->outp = NULL;
  }
  free_data_buf();
  free_svalue(&THIS->args);
  free_svalue(&THIS->cb);
  THIS->cb.type = T_INT; 
  THIS->args.type = T_INT; 
}

/* Set the input file (file object, (max) bytes to read ) */
static void f_input(INT32 args) {
  NBIO_INT_T len = -1;
  switch(args) {
   case 2:
    if(ARG(2).type != T_INT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->input", 2, "integer");
    } else {
      len = ARG(2).u.integer;
    }
    /* FALL THROUGH */
   case 1:
    if(ARG(1).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->input", 1, "object");
    } else {
      /* Allocate a new input object and add it to our linked list */
      new_input(ARG(1), len, 0);
    }
    break;
    
   case 0:
    SIMPLE_TOO_FEW_ARGS_ERROR("Caudium.nbio()->input", 1);
    break;
  }
  pop_n_elems(args-1);
}

/* Set the output file (file object) */
static void f_output(INT32 args) {
  if(args) {
    if(ARG(1).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->output", 1, "object");
    } else {
      output *outp;
      if(THIS->outp != NULL) {
	free_output(THIS->outp);
      }
      outp = malloc(sizeof(output));
      outp->file = ARG(1).u.object;
      outp->fd = fd_from_object(outp->file);

      if(outp->fd == -1) {
	free(outp);
	Pike_error("Only real files are accepted as outputs.\n");
      }
	
      outp->set_nb_off = find_identifier("set_nonblocking", outp->file->prog);
      outp->set_b_off  = find_identifier("set_blocking", outp->file->prog);
      outp->write_off  = find_identifier("write", outp->file->prog);

      if (outp->write_off < 0 || outp->set_nb_off < 0 || outp->set_b_off < 0) 
      {
	free(outp);
	Pike_error("Caudium.nbio()->output: illegal file object%s%s%s\n",
		   ((outp->write_off < 0)?"; no write":""),
		   ((outp->set_nb_off < 0)?"; no set_nonblocking":""),
		   ((outp->set_b_off < 0)?"; no set_blocking":""));
      }

      outp->mode = ACTIVE;
      add_ref(outp->file);
      THIS->outp = outp;
      noutputs++;
      /* Set up the read callback. We don't need a close callback since
       * it never will be called w/o a read_callback (which we don't want one).
       */
      push_int(0);
      push_callback(output_write_cb_off);
      push_int(0);
      apply_low(outp->file, outp->set_nb_off, 3);
      pop_stack();
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("Caudium.nbio()->output", 1);
  }
  pop_n_elems(args-1);
}

/* Set the output data (string) */
static void f_write(INT32 args) {
  if(args) {
    if(ARG(1).type != T_STRING) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->write", 1, "string");
    } else {
      int len = ARG(1).u.string->len << ARG(1).u.string->size_shift;
      if(len > 0)
	new_input(ARG(1), len, 0);
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("Caudium.nbio()->write", 1);
  }
  pop_n_elems(args-1);
}

/* Called when the sending is finished. Either due to broken connection
 * or no more data to send.
 */
static void finished(void)
{
  DERR(fprintf(stderr, "Done writing (%d sent)\n", (INT32)THIS->written));

  THIS->finished   = 1;
  while(THIS->inputs != NULL) {
    free_input(THIS->inputs);
  }

  if(THIS->outp != NULL) {
    apply_low(THIS->outp->file, THIS->outp->set_b_off, 0);
    pop_stack();
    free_output(THIS->outp);
    THIS->outp = NULL;
  }

  if(THIS->cb.type != T_INT)
  {
    push_svalue(&(THIS->args));
    apply_svalue(&(THIS->cb),1);
    pop_stack();
  }
}

/* This function reads some data from the current input (file object)
 */
static INLINE int read_data(void)
{
  int buf_size = READ_BUFFER_SIZE;
  NBIO_INT_T to_read  = 0;
  char *rd;
  input *inp;
 redo:
  DERR(fprintf(stderr, "Reading from blocking input.\n"));
  THIS->buf_pos = 0;
  inp = THIS->inputs;
  if(inp == NULL)
    return -1; /* No more inputs */
  if(inp->type != NBIO_BLOCK_OBJ)
    return -2; /* invalid input for read_data */
  if(inp->fd != -1) {
    char * ptr;
    DERR(fprintf(stderr, "Reading from real fd.\n"));
	
    if(inp->len != -1) 
      to_read = MIN(buf_size, inp->len - inp->pos);
    else
      to_read = buf_size;
    if(THIS->buf == NULL || THIS->buf_size < to_read) {
      alloc_data_buf(to_read);
    }
	
    ptr = THIS->buf;
    THREADS_ALLOW();
    to_read = fd_read(inp->fd, ptr, to_read);
    THREADS_DISALLOW();
    DERR(fprintf(stderr, "read %ld from file\n", (long)to_read));
  } else {
    DERR(fprintf(stderr, "Reading from fake fd.\n"));
    if(inp->len != -1 && inp->pos >= inp->len) {
      /* We are done reading from this one */
      free_input(inp);
      DERR(fprintf(stderr, "Data done from fake fd.\n"));
      goto redo; /* goto == ugly, but we want to read the next input
		  * if any
		  */
    }	

    to_read = READ_BUFFER_SIZE;
    push_int(to_read);
    push_int(1);
    apply_low(inp->u.file, inp->read_off, 2);
    if(Pike_sp[-1].type == T_STRING) {
      if(Pike_sp[-1].u.string->len == 0) {
	DERR(fprintf(stderr, "Read zero bytes from fake fd (EOF).\n"));
	to_read = 0;
      } else {
	new_input(Pike_sp[-1], 0, 1);
	to_read = THIS->inputs->len;
	inp->pos += to_read;
 	DERR(fprintf(stderr, "read %ld bytes from fake file\n",
		     (long)to_read));
	pop_stack();
	return -3; /* Got a string buffer appended to the input list */
      }
    } else if(Pike_sp[-1].type == T_INT && Pike_sp[-1].u.integer == 0) {
      to_read = 0;
    } else {
      Pike_error("Incorrect result from read, expected string.\n");
    }
    pop_stack();
  }
  switch(to_read) {
   case 0: /* EOF */
    free_input(inp);
    DERR(fprintf(stderr, "read zero blocking bytes == EOF\n"));
    break;

   case -1:
    if(errno != EAGAIN) {
      /* Got an error. Free input and continue */
      free_input(inp); 
    }
    goto redo;

   default:
    inp->pos += to_read;
    if(inp->pos == inp->len)
      free_input(inp);
    break;
  }
  return to_read;
}

static INLINE int do_write(char *buf, int buf_len) {
  int fd, written = 0;
  fd = THIS->outp->fd;
 write_retry:
  if(fd != -1) {
    THREADS_ALLOW();
    written = fd_write(fd, buf, buf_len);
    THREADS_DISALLOW();  
  } else {
    /*... */
  }

  if(written < 0)
  { 
    DERR(fprintf(stderr, "write returned -1 (errno %d)\n", errno));
    switch(errno)
    {      
     default:
      DERR(perror("Error while writing"));
      finished();
      return -1; /* -1 == write failed and that's it */

     case EINTR: /* interrupted by signal - try again */
      goto write_retry;
      

     case EWOULDBLOCK:
      return 0; /* Treat this as if we wrote no data */      
    }
  } else {
    DERR(fprintf(stderr, "Wrote %d bytes of %d\n", written, buf_len));
    THIS->written += written;
  }

  if(fd != -1) {
    /* Need to set_nonblocking again to trigger the write cb again.
     * FIXME: only call when there is more to write...
     */
    push_int(0);
    push_callback(output_write_cb_off);
    push_int(0);
    apply_low(THIS->outp->file, THIS->outp->set_nb_off, 3);
    pop_stack();
  }
  return written;
}

/* Our write callback */
static void f__output_write_cb(INT32 args)
{
  NBIO_INT_T written = 0, len = 0;
  char *buf = NULL;
  input *inp = THIS->inputs;

  pop_n_elems(args);
  DERR(fprintf(stderr, "output write callback\n"));
  if(THIS->buf_len) {
    /* We currently have buffered data to write */
    len = THIS->buf_len;
    buf = THIS->buf + THIS->buf_pos;
    DERR(fprintf(stderr, "Sending buffered data (%ld bytes left)\n", (long)len));
    written = do_write(THIS->buf + THIS->buf_pos, THIS->buf_len);
    switch(written) {
     case -1: /* We're done here. The write failed. Goodbye. */
     case 0:  /* Done, but because the write would block or
	       * nothing was written. I.e try again later.
	       */
      return; 

     default:
      /* Write succeeded */
      THIS->buf_len -= written;
      THIS->buf_pos += written;
      if(THIS->buf_len) {
	/* We couldn't write everything. Return to try later. */
	return;
      }
      
      /* We wrote all our buffered data. Just fall through to possibly
       * write more.
       */
      THIS->buf_pos = 0;
      THIS->buf_len = 0;
    }
  }
  if(inp == NULL) {
    finished();
    return;
  }
  switch(inp->type) {
   case NBIO_OBJ: /* non-blocking input - if no data available,
		   * just return. once data is available, write_cb will
		   * be called. 
		   */
    if(written <= 0) {
      /* We didn't write anything previously */
      THIS->outp->mode = IDLE;
    }
    DERR(fprintf(stderr, "Waiting for NB input data.\n"));
    if(inp->mode == SLEEPING) {
      /* Set read callback here since object is idle */
      push_callback(input_read_cb_off);
      push_int(0);
      push_callback(input_close_cb_off);
      apply_low(THIS->inputs->u.file, THIS->inputs->set_nb_off, 3);
      inp->mode = READING;
    }
    return;
    
   case NBIO_STR: 
    buf = inp->u.data->str + inp->pos;
    len = inp->len - inp->pos;
    DERR(fprintf(stderr, "Sending string data (%ld bytes left)\n", (long)len));
    written = do_write(buf, len);

    if(written > 0) {
      inp->pos += written;
      if(inp->pos == inp->len)
	free_input(inp);
    }
    break;

#ifdef USE_MMAP
   case NBIO_MMAP:
    len = inp->u.mmap_storage->m_end - inp->pos;
    if(!len) {
      /* need to mmap more data. No need to check if there's more to allocate
       * since the object would have been freed in that case */
      DERR(fprintf(stderr, "mmapping more data from fd %d\n", inp->fd));
      len = MIN(inp->len - inp->pos, MAX_MMAP_SIZE);
      munmap(inp->u.mmap_storage->data, inp->u.mmap_storage->m_len);
      mmapped -= inp->u.mmap_storage->m_len;
      DERR(fprintf(stderr, "trying to mmap %ld bytes starting at pos %ld\n",
		   (long)len, (long)inp->pos));
      inp->u.mmap_storage->data =
	(char *)mmap(0, len, PROT_READ,
		     MAP_FILE | MAP_SHARED, inp->fd,
		     inp->pos);
      if(inp->u.mmap_storage->data == MAP_FAILED) {
	DERR(perror("additional mmap failed"));
	free_input(inp);
	/* FIXME: Better error handling here? */
	f__output_write_cb(0);
	return;
      } else {
	inp->u.mmap_storage->m_start = inp->pos;
	inp->u.mmap_storage->m_len   = len;
	inp->u.mmap_storage->m_end   = len + inp->pos;
	mmapped += len;
      }
    }
    buf = inp->u.mmap_storage->data +
      (inp->pos - inp->u.mmap_storage->m_start);
    DERR(fprintf(stderr,"Sending mmapped file (%ld to write, %ld total left)\n"
		 , (long)len, (long)(inp->len - inp->pos)));
    written = do_write(buf, len);

    if(written > 0) {
      inp->pos += written;
      if(inp->pos == inp->len)
	free_input(inp);
    }
#endif
    break;
    
   case NBIO_BLOCK_OBJ: {
     int read;
     read = read_data(); /* At this point we have no data, so read some */
     switch(read) {
      case  -1:
       /* We are done. No more inputs */
       finished();
       return;
      case -2: /* Invalid input for read_data == redo this function */
      case -3: /* We read from a fake object and got a string == redo */
       f__output_write_cb(0);
       return;
     }
     len = THIS->buf_len;
     buf = THIS->buf;
     DERR(fprintf(stderr, "Sending buffered data (%ld bytes left)\n", (long)len));
     written = do_write(buf, len);
     if(written > 0) {
       THIS->buf_len -= written;
       THIS->buf_pos += written;
     }
   }
  }   
  if(written < 0) {
    return;
  } 
  if(!THIS->buf_len && THIS->inputs == NULL) {
    finished();
  }
}

/* Our nb input close callback */
static void f__input_close_cb(INT32 args) {
  DERR(fprintf(stderr, "Input close callback.\n"));
  pop_n_elems(args);
  if(THIS->inputs) {
    free_input(THIS->inputs);
  }
  if(!THIS->buf_len && THIS->inputs == NULL) {
    finished();
  }
}

/* Our nb input read callback */
static void f__input_read_cb(INT32 args)
{
  int avail_size = 0, len;
  struct pike_string *str;
  input *inp = THIS->inputs;
  if(inp == NULL) {
    Pike_error("Input read callback without inputs.");
  }    
  if(args != 2)
    Pike_error("Invalid number of arguments to read callback.");
  if(ARG(2).type != T_STRING) {
    SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->_input_read_cb", 2, "string");
  }
  str = ARG(2).u.string;
  len = str->len << str->size_shift;
  inp->pos += len;
  if(inp->len != -1 && inp->pos >= inp->len) {
    len -= inp->pos - inp->len; /* Don't "read" too much */
    free_input(inp);
  }
  DERR(fprintf(stderr, "Input read callback (got %d bytes).\n", len));
  if(THIS->buf_size) {
    avail_size = THIS->buf_size - (THIS->buf_len + THIS->buf_pos);
  } 
  if(avail_size < len) {
    alloc_data_buf(THIS->buf_size + (len - avail_size));
  }
  DERR(fprintf(stderr, "Copying %d bytes to buf starting at 0x%x (pos %d).\n",
	       len, (int)(THIS->buf + THIS->buf_pos + THIS->buf_len), THIS->buf_pos + THIS->buf_len));
  memcpy(THIS->buf + THIS->buf_pos + THIS->buf_len, str->str, len);
  THIS->buf_len += len;
  if((THIS->buf_len + THIS->buf_pos) > READ_BUFFER_SIZE) {
    DERR(fprintf(stderr, "Read buffer full (%d bytes).\n", THIS->buf_size));
    push_int(0);   push_int(0);  push_int(0);
    apply_low(inp->u.file, inp->set_nb_off, 3);
    pop_stack();
    inp->mode = SLEEPING;
  }
  pop_n_elems(args);
  if(THIS->outp->mode == IDLE) {
    DERR(fprintf(stderr, "Waking up output.\n"));
    THIS->outp->mode = ACTIVE;
    f__output_write_cb(0);
  }
}
 
/* Set the done callback */
static void f_set_done_callback(INT32 args)
{
  switch(args) {
   case 2:
    assign_svalue(&(THIS->args), &ARG(2)); 

   case 1:
    if (Pike_sp[-args].type != T_FUNCTION)
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->set_done_callback", 1, "function");
    assign_svalue(&(THIS->cb), &Pike_sp[-args]);
    break;
   case 0:
    free_svalue(&THIS->cb);
    free_svalue(&THIS->args);
    THIS->cb.type=T_INT;
    THIS->args.type=T_INT;
    THIS->args.u.integer = 0;
    return;
    
   default:
    Pike_error("Caudium.nbio()->set_done_callback: Too many arguments.\n");
    break;
  }
  pop_n_elems(args - 1); 
}

/* Number of bytes written */
static void f_bytes_sent(INT32 args)
{
  pop_n_elems(args);
  DERR(fprintf(stderr, "bytes_sent() => %ld\n", (long)THIS->written));
  push_nbio_int(THIS->written);
}


static void f_nbio_status(INT32 args)
{
  pop_n_elems(args);
  push_int(noutputs);
  push_int(ninputs);
  push_int(nstrings);
  push_int(nobjects);
  push_nbio_int(mmapped);
  push_int(nbuffers);
  push_int(sbuffers);
  f_aggregate(7);
}

/* Initialized the sender */
void init_nbio(void) {
  start_new_program();
  ADD_STORAGE( nbio_storage );
  set_init_callback(alloc_nb_struct);
  set_exit_callback(free_nb_struct);
  ADD_FUNCTION("nbio_status", f_nbio_status, tFunc(tVoid, tArray), 0);
  ADD_FUNCTION("input",  f_input, tFunc(tObj tOr(tInt, tVoid), tVoid), 0);
  ADD_FUNCTION("write",  f_write, tFunc(tStr, tVoid), 0);
  ADD_FUNCTION("output", f_output, tFunc(tObj, tVoid), 0);
  ADD_FUNCTION("_output_write_cb", f__output_write_cb, tFunc(tInt, tVoid), 0);
  ADD_FUNCTION("_input_read_cb", f__input_read_cb, tFunc(tInt tStr, tVoid), 0);
  ADD_FUNCTION("_input_close_cb", f__input_close_cb, tFunc(tInt, tVoid), 0);
  ADD_FUNCTION("set_done_callback", f_set_done_callback, tFunc(tOr(tVoid,tFunc(tMix, tMix)) tOr(tVoid,tMix),tVoid),0);
  ADD_FUNCTION("bytes_sent", f_bytes_sent, tFunc(tNone,tInt), 0);
  nbio_program = end_program();
  add_program_constant("nbio", nbio_program, 0);
  
  output_write_cb_off = find_identifier("_output_write_cb", nbio_program);
  input_read_cb_off   = find_identifier("_input_read_cb", nbio_program);
  input_close_cb_off  = find_identifier("_input_close_cb", nbio_program);
}

/* Module exit... */
void exit_nbio(void) {
  free_program(nbio_program);
}

