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
 * to another file object. I.e data pipe function.
 */

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

/*#define NB_DEBUG */
#ifdef NB_DEBUG
# define DERR(X) do { fprintf(stderr, "** Caudium.nbio: "); X; } while(0)
#else
# define DERR(X) 
#endif

static int output_write_cb_off;
static struct program *nbio_program;

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
  THIS->args       = NULL;
  THIS->buf        = NULL;
  THIS->cb.type    = T_INT;
  THIS->buf_len    = 0;
  THIS->written    = 0;
}

/* Free an input */
static void free_input(input *inp) {
  DERR(fprintf(stderr, "Freeing input 0x%x\n", (unsigned int)inp));
  switch(inp->type) {
   case NBIO_STR: 
    free_string(inp->u.data);
    break;
#ifdef USE_MMAP
   case NBIO_MMAP:
    if(inp->u.mmap->data != MAP_FAILED) {
      munmap(inp->u.mmap->data, inp->u.mmap->m_len);
    }
    free_object(inp->u.mmap->file);
    free(inp->u.mmap);
    break;
#endif
   case NBIO_OBJ:
    free_object(inp->u.file);
    break;
  }
  if(THIS->last_input == inp)
    THIS->last_input = NULL;
  THIS->inputs = inp->next;
  free(inp);
}

/* Allocate new input object and add it to our list */
static INLINE void new_input(struct svalue inval, NBIO_INT_T len) {
  struct stat s;
  input *inp;

  inp = malloc(sizeof(input));
  if(inp == NULL) {
    Pike_error("Out of memory!\n");
    return;
  }

  inp->next = NULL;
  inp->pos  = 0;

  DERR(fprintf(stderr, "Allocated new input at 0x%x\n", (unsigned int)inp));
  if(inval.type == T_STRING) {
    inp->type   = NBIO_STR;
    add_ref(inp->u.data = inval.u.string);
    inp->len    = inval.u.string->len << inval.u.string->size_shift;
    DERR(fprintf(stderr, "string input added: %ld bytes\n", (long)inp->len));
  } else if(inval.type == T_OBJECT) {
    inp->fd     = fd_from_object(inval.u.object);
    inp->len    = len;
    inp->type   = NBIO_OBJ;
    if(inp->fd == -1) {
      inp->u.file = inval.u.object;
      DERR(fprintf(stderr, "input object not a real FD\n"));
      if (find_identifier("read", inp->u.file->prog) < 0) {
	free(inp);
	Pike_error("Caudium.nbio()->input: Illegal file object, "
		   "missing read()\n");
	return;
      }
      add_ref(inp->u.file);
    } else {
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
	  if( (inp->u.mmap = malloc(sizeof(mmap_data))) == NULL) {
	    Pike_error("Failed to allocate mmap structure. Out of memory?\n");
	  }
	  inp->type   = NBIO_MMAP;
	  inp->len    = s.st_size;
	  inp->pos    = filep;

	  inp->u.mmap->data    = mtmp;
	  inp->u.mmap->m_start = filep;
	  inp->u.mmap->m_len   = alloc_len;
	  inp->u.mmap->m_end   = filep + alloc_len;
	  add_ref(inp->u.mmap->file = inval.u.object);
	  
	  DERR(fprintf(stderr, "new mmap input (fd %d)\n", inp->fd));
#ifdef NB_DEBUG
	} else {
	  DERR(perror("mmap failed"));
#endif
	}
      }
#endif
      if(inp->type == NBIO_OBJ) {
	/* mmap failed or not a regular file */
	inp->u.file = inval.u.object;
	add_ref(inp->u.file);
	DERR(fprintf(stderr, "new input FD == %d\n", inp->fd));
      }
    }
  }

  if (THIS->last_input)
    THIS->last_input->next = inp;
  else
    THIS->inputs = inp;
  THIS->last_input = inp;
}


/* free output object */
static void free_output(output *outp) {
  free_object(outp->file);
  free(outp);
}

/* Free any allocated data in the struct */
static void free_nb_struct(struct object *obj) {
  if(THIS->args != NULL) {
    free_array(THIS->args);
    THIS->args = NULL;
  }
  while(THIS->inputs != NULL) {
    free_input(THIS->inputs);
  }

  if(THIS->outp != NULL) {
    free_output(THIS->outp);
    THIS->outp = NULL;
  }
  if(THIS->buf != NULL) {
    free(THIS->buf);
    THIS->buf = NULL;
  }
  free_svalue(&THIS->cb);
  THIS->cb.type = T_INT; 
}

/* Set the input file (file object, (max) bytes to read ) */
static void f_input(INT32 args) {
  NBIO_INT_T len = -1;
  switch(args) {
   case 2:
    if(ARG(1).type != T_INT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->input", 2, "integer");
    } else {
      len = ARG(1).u.integer;
    }
    /* FALL THROUGH */
   case 1:
    if(ARG(0).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->input", 1, "object");
    } else {
      /* Allocate a new input object and add it to our linked list */
      new_input(ARG(0), len);
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
    if(ARG(0).type != T_OBJECT) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->output", 1, "object");
    } else {
      output *outp;
      if(THIS->outp != NULL) {
	free_output(THIS->outp);
      }
      outp = malloc(sizeof(output));
      outp->file = ARG(0).u.object;
      outp->fd = fd_from_object(outp->file);

      if(outp->fd == -1) {
	Pike_error("Only real files are accepted as outputs.\n");
      }
	
      outp->set_nb_off = find_identifier("set_nonblocking", outp->file->prog);
      outp->set_b_off  = find_identifier("set_blocking", outp->file->prog);
      outp->write_off  = find_identifier("write", outp->file->prog);

      if (outp->write_off < 0 || outp->set_nb_off < 0 || outp->set_b_off < 0) 
      {
	Pike_error("Caudium.nbio()->output: illegal file object%s%s%s\n",
		   ((outp->write_off < 0)?"; no write":""),
		   ((outp->set_nb_off < 0)?"; no set_nonblocking":""),
		   ((outp->set_b_off < 0)?"; no set_blocking":""));
      }

      
      add_ref(outp->file);
      THIS->outp = outp;

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
    if(ARG(0).type != T_STRING) {
      SIMPLE_BAD_ARG_ERROR("Caudium.nbio()->write", 1, "string");
    } else {
      new_input(ARG(0), 0);
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
  DERR(fprintf(stderr, "Done writing (%d sent)\n", THIS->written));

  if(THIS->args != NULL) {
    free_array(THIS->args);
    THIS->args = NULL;
  }
  while(THIS->inputs != NULL) {
    free_input(THIS->inputs);
  }

  if(THIS->outp != NULL) {
    free_output(THIS->outp);
    THIS->outp = NULL;
  }

  if(THIS->cb.type != T_INT)
  {
    apply_svalue(&(THIS->cb),0);
    pop_stack();
  }
}



/* This function reads some data from the file cache..
 * Called when we want some data to send.
 */
static void read_data(void)
{
  int buf_size = READ_BUFFER_SIZE;
  NBIO_INT_T to_read  = 0;
  char *rd;
  input *inp;

  if(!THIS->buf) {
    /* Allocate the temporary read buffer */
    THIS->buf = malloc(READ_BUFFER_SIZE);
    if(THIS->buf == NULL) {
      Pike_error("Failed to allocate read buffer.\n");
    }
  }
  while((inp = THIS->inputs) && buf_size) {
    if(inp->type == NBIO_OBJ) {
      if(inp->len != -1) 
	to_read = MIN(buf_size, inp->len - inp->pos);
      else
	to_read = buf_size;
      if(inp->fd != -1) {
	char *ptr = THIS->buf+THIS->buf_len;
	THREADS_ALLOW();
	to_read = fd_read(inp->fd, ptr, to_read);
	THREADS_DISALLOW();
	DERR(fprintf(stderr, "read %ld from file (%d free)\n",
		     (long)to_read, buf_size));
      } else {
	push_int(to_read);
	push_int(1);
	apply_low(inp->u.file, inp->read_off, 2);
	if(Pike_sp[-1].type == T_INT) to_read = Pike_sp[-1].u.integer;
	else to_read = 0;
	pop_stack();
	DERR(fprintf(stderr, "read %ld from fake file (%d free)\n",
		     (long)to_read, buf_size));
      }
      switch(to_read) {
       case 0: /* EOF */
	free_input(inp);
	break;
       case -1:
	if(errno != EAGAIN) {
	  /* Got an error. Free input and continue */
	  free_input(inp); 
	}
	break;
       default:
	inp->pos += to_read;
	THIS->buf_len += to_read;
	buf_size -= to_read;
	if(inp->pos == inp->len)
	  free_input(inp);
	break;
      }
      break;
    } else {
      return; /* don't 'read' from string */
    }
  }
  if(!buf_size) {
    /* read buffer is full */
    return;
  }
  DERR(fprintf(stderr, "read all data (%d left)\n", buf_size));
}


/* Our write callback */
static void f__output_write_cb(INT32 args)
{
  NBIO_INT_T written=0, len;
  int fd;
  char *buf = NULL;
  input *inp;
  fd  = THIS->outp->fd;
  if(!THIS->buf_len && (inp = THIS->inputs) &&
     (inp->type == NBIO_STR
#ifdef USE_MMAP
     || inp->type == NBIO_MMAP
#endif
      )) {
    void *data;
#ifdef USE_MMAP
    if(inp->type == NBIO_STR) {
#endif
      data = inp->u.data->str + inp->pos;
      len = inp->len - inp->pos;
      DERR(fprintf(stderr, "Sending string data (%ld bytes left)\n", (long)len));
#ifdef USE_MMAP
    } else {

      len = inp->u.mmap->m_end - inp->pos;
      if(!len) {
	/* need to mmap more data. No need to check if there's more to allocate
	 * since the object would have been freed in that case
	 */
	DERR(fprintf(stderr, "mmapping more data from fd %d\n", inp->fd));
	len = MIN(inp->len - inp->pos, MAX_MMAP_SIZE);
	munmap(inp->u.mmap->data, inp->u.mmap->m_len);
	DERR(fprintf(stderr, "trying to mmap %ld bytes starting at pos %ld\n",
		     (long)len, (long)inp->pos));
	inp->u.mmap->data =
	  (char *)mmap(0, len, PROT_READ,
		       MAP_FILE | MAP_SHARED, inp->fd,
		       inp->pos);
	if(inp->u.mmap->data == MAP_FAILED) {
	  DERR(perror("additional mmap failed"));
	  free_input(inp);
	  /* FIXME: Better error handling here? */
	  f__output_write_cb(args);
	  return;
	} else {
	  inp->u.mmap->m_start = inp->pos;
	  inp->u.mmap->m_len   = len;
	  inp->u.mmap->m_end   = len + inp->pos;
	}
      }
      data = inp->u.mmap->data + (inp->pos - inp->u.mmap->m_start);
      DERR(fprintf(stderr, "Sending mmapped file (%ld to write, %ld total left)\n", (long)len, (long)(inp->len - inp->pos)));
    }
#endif
    THREADS_ALLOW();
    written = fd_write(fd, data, len);
    THREADS_DISALLOW();
    if(written != -1) {
      inp->pos += written;
      if(inp->pos == inp->len)
	free_input(inp);
    }
  } else {
    if(!THIS->buf_len) {
      read_data();
    }
    len = THIS->buf_len;
    buf = THIS->buf;
    DERR(fprintf(stderr, "Sending buffered data (%ld bytes left)\n", (long)len));
    THREADS_ALLOW();
    written = fd_write(fd, buf, len);
    THREADS_DISALLOW();
  }    
  if(written < 0)
  {
    DERR(fprintf(stderr, "write returned -1 (errno %d)\n", errno));
    switch(errno)
    {      
     default:
      DERR(perror("Error while writing"));
      finished();
      pop_n_elems(args-1);
      return;
     case EINTR:
     case EWOULDBLOCK:
      break;
    }
  } else {
    DERR(fprintf(stderr, "Wrote %ld bytes (%d in buf)\n",
		 (long)written, THIS->buf_len));
    THIS->written += written;
    if(THIS->buf_len) {
      THIS->buf_len -= written;
      if(THIS->buf_len)
	MEMCPY(THIS->buf, THIS->buf + written, THIS->buf_len);
    }
  }
  pop_n_elems(args-1);
  
  if(!THIS->buf_len && THIS->inputs == NULL) {
    finished();
#if 1
  } else {
    push_int(0);
    push_callback(output_write_cb_off);
    push_int(0);
    apply_low(THIS->outp->file, THIS->outp->set_nb_off, 3);
    pop_stack();
#endif
  }
}

/* Set the done callback */
static void f_set_done_callback(INT32 args)
{
  if(args == 0)
  {
    free_svalue(&THIS->cb);
    THIS->cb.type=T_INT;
    return;
  }
  if (Pike_sp[-args].type != T_FUNCTION)
    Pike_error("Illegal argument to set_done_callback()\n");

  assign_svalue(&(THIS->cb), Pike_sp-args); 
  pop_n_elems(args - 1); 
}

/* Number of bytes written */
static void f_bytes_sent(INT32 args)
{
  pop_n_elems(args);
#ifdef INT64
  push_int64(THIS->written);
#else
  push_int(THIS->written);
#endif
}


/* Initialized the sender */
void init_nbio(void) {
  start_new_program();
  ADD_STORAGE( nbio_storage );
  set_init_callback(alloc_nb_struct);
  set_exit_callback(free_nb_struct);
  ADD_FUNCTION("input",  f_input, tFunc(tObj tOr(tInt, tVoid), tVoid), 0);
  ADD_FUNCTION("write",  f_write, tFunc(tStr, tVoid), 0);
  ADD_FUNCTION("output", f_output, tFunc(tObj, tVoid), 0);
  ADD_FUNCTION("_output_write_cb", f__output_write_cb, tFunc(tInt, tVoid), 0);
  ADD_FUNCTION("set_done_callback", f_set_done_callback, tFunc(tOr(tVoid,tFunc(tMix, tMix)) tOr(tVoid,tMix),tVoid),0);
  ADD_FUNCTION("bytes_sent", f_bytes_sent, tFunc(tNone,tInt), 0);
  nbio_program = end_program();
  add_program_constant("nbio", nbio_program, 0);
  
  output_write_cb_off = find_identifier("_output_write_cb", nbio_program);
}

/* Module exit... */
void exit_nbio(void) {
  free_program(nbio_program);
}

