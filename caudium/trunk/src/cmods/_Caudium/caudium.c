/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
/*
 * $Id$
 */

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "caudium_machine.h"
#include "entparse.h"
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <stdarg.h>
#include <stdlib.h>
#include <ctype.h>

#ifdef TIME_WITH_SYS_TIME_H
# include <sys/time.h>
# include <time.h>
#else
# ifdef HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif

#define THISOBJ (Pike_fp->current_object)

/*#define C_DEBUG 1 */
#ifdef C_DEBUG
# define DERR(X) do { fprintf(stderr, "** _Caudium.(%p):%d: ", THISOBJ, __LINE__); X; } while (0)
#else
# define DERR(X)
#endif

/* AIX requires this to be the first thing in the file.  */
#ifndef __GNUC__
# if HAVE_ALLOCA_H
#  include <alloca.h>
# else
#  ifdef _AIX
 #pragma alloca
#  else
#   ifndef alloca /* predefined by HP cc +Olibcalls */
char *alloca ();
#   endif
#  endif
# endif
#endif

#include "caudium.h"
#include "datetime.h"

typedef int (*safe_func)(char c);

static_strings strs;

/*
**! file: Caudium/caudium.c
**!  Caudium specific classes and functions.
**! cvs_version: $Id$
*/

/*
**! class: Caudium.ParseHTTP
**!  This class is used to parse a HTTP/1.0 or HTTP/1.1 request.
**!  scope: private
*/

static struct array    *mta_unsafe_chars;
static struct array    *mta_safe_entities;
static char            *_unsafechars[] = {"<",">","&"};
static char            *_safeentities[] = {"&lt;", "&gt;", "&amp;"};

#define UNSAFECHARS_SIZE sizeof(_unsafechars)/sizeof(char*)

/*
**! method: string _make_tag_attributes(mapping in)
**!  Convert a mapping with key-value pairs to tag attribute format escaping
**!  any unsafe characters.
**! arg: mapping in
**!  The mapping with the attributes
**! returns:
**!  The string of attributes.
*/
static void f_make_tag_attributes(INT32 args)
{
  struct mapping          *in;
  struct array            *indices, *values;
  unsigned                 i;
  struct string_builder    ret;
  struct pike_string      *retstr;
  int                      max_shift;
  char                    *tmp;
  int                      len, do_replace;
  
  get_all_args("make_tag_attributes", args, "%m", &in);

  /* Make sure there is no "/" that might be left from parsing <tag /> */
  map_delete(in, &strs.mta_slash);

  indices = mapping_indices(in);
  values = mapping_values(in);

  /* Find the widest string in the mapping, we need that for the string
   * builder
   */
  max_shift = 0;
  for (i = 0; i < (unsigned)indices->size; i++) {
    if (indices->real_item[i].type == T_STRING && indices->real_item[i].u.string->size_shift > max_shift)
      max_shift = indices->real_item[i].u.string->size_shift;
    else if (values->real_item[i].type == T_STRING && values->real_item[i].u.string->size_shift > max_shift)
      max_shift = values->real_item[i].u.string->size_shift;
  }

  init_string_builder(&ret, max_shift);  

  /* we don't check whether the string is "safe" or not. We will run replace
   * once over the entire resulting string in the end.
   */
  for (i = 0; i < (unsigned)indices->size; i++) {
    if (indices->real_item[i].type != T_STRING || values->real_item[i].type != T_STRING)
      continue;
    /* alloc enough space for name="value" */
    len = indices->real_item[i].u.string->len +
      values->real_item[i].u.string->len + 5;
    
#ifdef HAVE_ALLOCA
    tmp = (char*)alloca(len);
#else
    tmp = (char*)malloc(len);
    if (!tmp)
      Pike_error("Out of memory");
#endif
    /* ugly code, but fast */
    tmp[len] = 0;
    len = indices->real_item[i].u.string->len;
    memcpy(tmp, indices->real_item[i].u.string->str, indices->real_item[i].u.string->len);
    memcpy(tmp + len, "=\"", 2);
    len += 2;
    memcpy(tmp + len, values->real_item[i].u.string->str, values->real_item[i].u.string->len);
    len += values->real_item[i].u.string->len;
    memcpy(tmp + len, "\" ", 2);
    len += 2;
    
    string_builder_append(&ret, MKPCHARP(tmp, 0), (ptrdiff_t)len);
#ifndef HAVE_ALLOCA
    free(tmp);
#endif
  }

  retstr = finish_string_builder(&ret);
  pop_n_elems(args);

  /* let's see whether we have anything to encode */
  do_replace = 0;
  for (i = 0; i < UNSAFECHARS_SIZE; i++) {
    if (memchr(retstr->str, _unsafechars[i][0], retstr->len)) {
      do_replace = 1;
      break;
    }
  }

  if (do_replace) {
    push_string(retstr);
    push_array(copy_array(mta_unsafe_chars));
    push_array(copy_array(mta_safe_entities));
    f_replace(3);
  }
  else
    push_string(retstr);
}

#ifndef HAVE_SETPROCTITLE
static long   _maxargvlen = -1;
static char  *argv0 = NULL;
static char  *progname = "";
extern char **ARGV; /* in pike's main.c */

static void setproctitle_init(int argc, char **argv)
{
  int     i;
  char   *ch;
  
  argv0 = argv[0];

  if (_maxargvlen < 0) {
    _maxargvlen = 0;
    for (i = 0; i < argc; i++)
      _maxargvlen += strlen(argv[i]) + 1;
    _maxargvlen++;
  }

  ch = strchr(argv[0], ' ');
  if (ch) {
    int len = ch - argv[0];
    
    progname = (char*)malloc(len + 1);
    if (progname) {
       progname[len] = 0;
       memcpy(progname, argv[0], len);
    }
  } else
    progname = strdup(argv[0]);

  if (!progname)
    progname = "";
}

static void setproctitle(char *fmt, ...)
{
  va_list     ap;
#if defined(__GNUC__) || defined(HAVE_ALLOCA)
  char       *buf = alloca(_maxargvlen);
#else
  char       *buf = malloc(_maxargvlen);
#endif

  if (!argv0 || !_maxargvlen || !fmt || !strlen(fmt)) {
#if !defined(__GNUC__) && !defined(HAVE_ALLOCA)
    if (buf)
      free(buf);
#endif
    return;
  }

  if (!buf)
    return;

  memset(buf, 0, _maxargvlen);
  va_start(ap, fmt);
  if (fmt[0] == '-')
    (void)vsnprintf(buf, _maxargvlen - 1, fmt+1, ap);
  else {
    int  prlen = strlen(progname);
    
    (void)snprintf(buf, _maxargvlen - 1, "%s ", progname);
    (void)vsnprintf(buf + prlen, _maxargvlen - prlen - 1, fmt, ap);
  }
  va_end(ap);
  
  memset(argv0, 0, _maxargvlen);
  strncpy(argv0, buf, _maxargvlen - 1);

#if !defined(__GNUC__) && !defined(HAVE_ALLOCA)
  if (buf)
    free(buf);
#endif
}
#endif

static unsigned char *char_decode_url(unsigned char *str, int len) {
  unsigned char *ptr, *end, *endl2;
  int i, nlen;
  ptr = str;
  end = ptr + len;
  endl2 = end-2; /* to see if there's enough left to make a "hex" char */
  for (nlen = 0, i = 0; ptr < end; i++) {
    switch(*ptr) {
        case '%':
          if (ptr < endl2)
            str[i] = (((ptr[1] < 'A') ? (ptr[1] & 15) :(( ptr[1] + 9) &15)) << 4)|
              ((ptr[2] < 'A') ? (ptr[2] & 15) : ((ptr[2] + 9)& 15));
          else
            str[i] = '\0';
          ptr+=3;
          nlen++;
          break;
        case '?':
          /* Don't decode more, reached query string*/
          str[i] = '\0';
          return (ptr+1);
          break;
        default:
          str[i] = *(ptr++);
          nlen++;
    }
  }
  str[nlen] = '\0'; /* We will use make_shared_string since a file can't
                       contain \0 anyway. */
  return NULL; /* no query string */
}

/*
**! method: int append(string data)
**!  Append data to the decode buffer.
**! arg: string data
**!  The data to feed to the parser.
**! returns:
**!  1 if decoding is complete (whole header received), 0 if more data is
**!  needed, 413 if the headers are too large or 400 if the request is invalid.
**! name: Caudium.ParseHTTP->append - append data to parse buffer
*/
static void f_buf_append( INT32 args )
{
  struct pike_string *str;
  struct svalue skey, sval; /* header, value */
  int slash_n = 0;
  unsigned char *pp,*ep;
  struct svalue *tmp;
  int os=0, i, j=0, l;
  unsigned char *in, *query;

  get_all_args("_Caudium.ParseHTTP->append", args, "%S", &str);
  
  if( str->len >= BUF->free ) {
    pop_n_elems(args);
    push_int(413); /* Request Entity Too Large */
    return;
  }

  MEMCPY( BUF->pos, str->str, str->len );

  for( ep = (BUF->pos + str->len), pp = MAX(BUF->data, BUF->pos-3); 
       pp < ep && slash_n < 2; pp++ )
    if( *pp == '\n' )
      slash_n++;
    else if( *pp != '\r' )
      slash_n=0;
  
  BUF->free -= str->len;
  BUF->pos += str->len;
  BUF->pos[0] = 0;
  pop_n_elems( args );
  if( slash_n != 2 )
  {
    /* need more data */
    push_int( 0 );
    return;
  }

  skey.type = sval.type = T_STRING;

  sval.u.string = make_shared_binary_string( (char *)pp, BUF->pos - pp);
  low_mapping_insert(BUF->other, SVAL(data), &sval, 1); /* data */
/*   free_string(sval.u.string); */
  
  in = BUF->data;
  l = pp - BUF->data;

  /* find method */
  for( i = 0; i < l; i++ ) {
    if( in[i] == ' ' ) 
      break;
    else if(in[i] == '\n') {
      push_int( 400 ); /* Bad Request */
      return;
    }
  }
  sval.u.string = make_shared_binary_string((char *)in, i);
  low_mapping_insert(BUF->other, SVAL(method), &sval, 1);
/*   free_string(sval.u.string); */
  
  i++; in += i; l -= i;

  /* find file */
  for( i = 0; i < l; i++ ) {
    if(in[i] == ' ') {
      break;
    } else  if(in[i] == '\n') {
      push_int( 400 ); /* Bad Request */
      return;
    }
  }
  sval.u.string = make_shared_binary_string((char *)in, i);
  low_mapping_insert(BUF->other, SVAL(raw_url), &sval, 1);
/*   free_string(sval.u.string); */

  /* Decode file part and return pointer to query, if any */
  query = char_decode_url(in, i);

  /* Decoded, query-less file up to the first \0 */
  sval.u.string = make_shared_string((char *)in); 
  low_mapping_insert(BUF->other, SVAL(file), &sval, 1);
/*   free_string(sval.u.string); */
  
  if(query != NULL)  {
    /* Store the query string */
    sval.u.string = make_shared_binary_string((char *)query, i - (query-in)); /* Also up to first null */
    low_mapping_insert(BUF->other, SVAL(query), &sval, 1);
/*     free_string(sval.u.string); */
  }
  
  i++; in += i; l -= i;

  /* find protocol */
  for( i = 0; i < l; i++ ) {
    if( in[i] == '\n' ) break;
    else if(in[i] == ' ') {
      push_int( 400 ); /* Bad Request */
      return;
    }
  }
  if( in[i-1] != '\r' ) 
    i++;
  sval.u.string = make_shared_binary_string((char *)in, i-1);
  low_mapping_insert(BUF->other, SVAL(protocol), &sval, 1);
/*   free_string(sval.u.string); */

  in += i; l -= i;
  if( *in == '\n' ) (in++),(l--);

  for(i = 0; i < l; i++)
  {
    if(in[i] >= 'A' && in[i] <= 'Z') in[i] |= 32; /* Lowercasing the header */
    else if( in[i] == ':' )
    {
      /* in[os..i-1] == the header */
      
      skey.u.string = make_shared_binary_string((char*)in+os, i - os);
      os = i+1;
      while(in[os]==' ') os++; /* Remove initial spaces */
      for(j=os;j<l;j++)  if( in[j] == '\n' || in[j]=='\r')  break; 

      if((tmp = low_mapping_lookup(BUF->headers, &skey)) &&
         tmp->type == T_STRING)
      {
        int len = j - os + 1;
        int len2 = len +tmp->u.string->len;
        sval.u.string = begin_shared_string(len2);
        MEMCPY(sval.u.string->str,
               tmp->u.string->str, tmp->u.string->len);
        sval.u.string->str[tmp->u.string->len] = ',';
        MEMCPY(sval.u.string->str + tmp->u.string->len + 1,
               (char*)in + os, len);
        sval.u.string = end_shared_string(sval.u.string);
      } else {
        sval.u.string = make_shared_binary_string((char*)in + os, j - os);
      }
      
      low_mapping_insert(BUF->headers, &skey, &sval, 1);
      if( in[j+1] == '\n' ) j++;
      os = j+1;
      i = j;
/*       free_string(sval.u.string); */
/*       free_string(skey.u.string); */
    }
  }
  push_int(1);
}


static void f_buf_create( INT32 args )
{
  if(BUF->data != NULL)
    Pike_error("Create already called!\n");
  switch(args) {
   default:
    Pike_error("Wrong number of arguments to create. Expected 2 or 3.\n");
    break;
	  
   case 3:
     get_all_args("_Caudium.ParseHTTP.create", args, "%m%m%d",
                  &BUF->other, &BUF->headers, &BUF->free);
     
     if(BUF->free < BUFSIZE_MIN || BUF->free > BUFSIZE_MAX)
       Pike_error("Specified buffer size not within the <%d,%d>.\n",
                  BUFSIZE_MIN, BUFSIZE_MAX);
     break;
     
   case 2:
     get_all_args("_Caudium.ParseHTTP.create", args, "%m%m",
                  &BUF->other, &BUF->headers);
     break;
  }

  if(BUF->free) {
    BUF->data = (char*)malloc(BUF->free * sizeof(char));
    if(!BUF->data)
      Pike_error("Cannot allocate the request buffer. Out of memory.\n");
  }
  
  BUF->pos = BUF->data;
  add_ref(BUF->headers);
  add_ref(BUF->other);
  pop_n_elems(args);
}

static void free_buf_struct(struct object *o)
{
  if(BUF->headers != NULL ) {
    free_mapping(BUF->headers);
    BUF->headers = NULL;
  }
  if(BUF->other != NULL) {
    free_mapping(BUF->other);
    BUF->other = NULL;
  }
  if(BUF->data) {
    free(BUF->data);
    BUF->data = NULL; /* just in case */
  }
}

static void alloc_buf_struct(struct object *o)
{
  /* This is just the initial buffer of default
   * size. If the size passed to create differs
   * then the buffer will be reallocated.
   */
  BUF->headers = NULL;
  BUF->other = NULL;
  BUF->data = NULL;
  BUF->free = BUFSIZE;
}


/* helper functions */
#ifndef HAVE_ALLOCA
INLINE
#endif
static struct pike_string *lowercase(unsigned char *str, INT32 len)
{
  unsigned char *p, *end;
  unsigned char *mystr;
  struct pike_string *pstr;
#ifdef HAVE_ALLOCA
  mystr = (unsigned char *)alloca((len + 1) * sizeof(char));
#else
  mystr = (unsigned char *)malloc((len + 1) * sizeof(char));
#endif
  if (mystr == NULL)
    return (struct pike_string *)NULL;
  MEMCPY(mystr, str, len);
  end = mystr + len;
  mystr[len] = '\0';
  for(p = mystr; p < end; p++)
  {
    if(*p >= 'A' && *p <= 'Z') {
      *p |= 32; /* OR is faster than addition and we just need
                 * to set one bit :-). */
    }
  }
  pstr = make_shared_binary_string((char *)mystr, len);
#ifndef HAVE_ALLOCA
  free(mystr);
#endif
  return pstr;
}

/* Decode QUERY encoded strings.
   Simple decodes %XX and + in the string. If exist is true, add a null char
   first in the string. 
   If simple = 1 then decode only %XX inside the string. If simple > 1, then
   the "+" will be decodes as " " and "%" will still be decoded as "%".
   If simple = 0, then "%" -> "\0" and "+" -> " ".
 */
#ifndef HAVE_ALLOCA
INLINE
#endif
static struct pike_string *url_decode(unsigned char *str, int len, int exist,
                                      int simple)
{
  int nlen = 0, i;
  unsigned char *mystr; /* Work string */ 
  unsigned char *ptr, *end; /* beginning and end pointers */
  unsigned char *endl2; /* == end-2 - to speed up a bit */
  struct pike_string *newstr;
#ifdef HAVE_ALLOCA
  mystr = (unsigned char *)alloca((len + 2) * sizeof(char));
#else
  mystr = (unsigned char *)malloc((len + 2) * sizeof(char));
#endif
  if (mystr == NULL)
    return (struct pike_string *)NULL;
  if(exist) {
    ptr = mystr+1;
    *mystr = '\0';
    exist = 1;
  } else
    ptr = mystr;
  MEMCPY(ptr, str, len);
  endl2 = end = ptr + len;
  endl2 -= 2;
  ptr[len] = '\0';

  for (i = exist; ptr < end; i++) {
    switch(*ptr) {
        case '%':
          if (ptr < endl2)
            mystr[i] =
              (((ptr[1] < 'A') ? (ptr[1] & 15) :(( ptr[1] + 9) &15)) << 4)|
              ((ptr[2] < 'A') ? (ptr[2] & 15) : ((ptr[2] + 9)& 15));
          else
            if(simple >= 1) { 
              mystr[i] = (*ptr++);
              nlen++;
              break;
            } else 
              mystr[i] = '\0';
          ptr+=3;
          nlen++;
          break;
        case '+':
          if(simple == 1) {
            mystr[i] = *(ptr++);
          } else { 
            ptr++;
            mystr[i] = ' ';
          }
          nlen++;
          break;
        default:
          mystr[i] = *(ptr++);
          nlen++;
    }
  }

  newstr = make_shared_binary_string((char *)mystr, nlen+exist);
#ifndef HAVE_ALLOCA
  free(mystr);
#endif
  return newstr;
}


#if 0
/* Code to add a string to a string */
value = begin_shared_string(count2 - data + exist->u.string->len+1);
MEMCPY(value->str, exist->u.string->str, exist->u.string->len+1);
MEMCPY(value->str + exist->u.string->len + 1,
       heads + data, count2 - data + 1);
value->str[count2 - data + 1 + exist->u.string->len] = '\0';
value = end_shared_string(value);
sval.u.string = value;
mapping_insert(headermap, &skey, &sval);
#endif

static int get_next_header(unsigned char *heads, int len,
                                  struct mapping *headermap)
{
  int data, count, colon, count2=0;
  struct svalue skey, sval;

  skey.type = T_STRING;
  sval.type = T_STRING;
  
  for(count=0, colon=0; count < len; count++) {
    switch(heads[count]) {
        case ':':
          colon = count;
          data = colon + 1;
          for(count2 = data; count2 < len; count2++)
            /* find end of header data */
            if(heads[count2] == '\r') break;
          while(heads[data] == ' ') data++;
      
          skey.u.string = lowercase(heads, colon);      
          if (skey.u.string == NULL) return -1;
          sval.u.string = make_shared_binary_string((char *)(heads+data),
                                                    count2 - data);
          low_mapping_insert(headermap, &skey, &sval, 1);
          count = count2;
/*           free_string(skey.u.string); */
/*           free_string(sval.u.string); */
          break;
        case '\n':
          /*printf("Returning %d read\n", count);*/
          return count+1;
    }
  }
  return count;
}

/*
  entity parser callback

   userdata is a mapping consisting of scopename:scope() entries.
*/
void entity_callback(char *entname, char params[], ENT_CBACK_RESULT *res, 
  void *userdata)
{
  struct svalue *tmp;

  tmp = simple_mapping_string_lookup((struct mapping *)userdata, entname);

  if(tmp)
  {
    int i;
    if(tmp->type != T_OBJECT)
      Pike_error("_Caudium.parse_entities(): expected object.\n");

   i=find_identifier("get", tmp->u.object->prog);
   if(!i)
      Pike_error("_Caudium.parse_entities(): no get() method present in scope.\n");
   push_text(params);
   apply_low(tmp->u.object, i, 1);
   
  }
  else
  {
    res->buf = NULL;
  }

  printf("Got entity: %s\n", entname); 
}

static void f_parse_entities( INT32 args )
{
  struct mapping *scopemap;
  struct pike_string *input;
  struct pike_string *result;
  ENT_RESULT *eres;

  get_all_args("_Caudium.parse_entities", args, "%S%m",
      &input, &scopemap);

  eres = ent_parser(input->str, input->len, entity_callback, scopemap);

  if (!eres) {
    Pike_error("Out of memory in the entity parser\n");
  }

 if (eres->errcode != ENT_ERR_OK)
    switch (eres->errcode) {
        case ENT_ERR_OOM:
          Pike_error("_Caudium.parse_entities(): Out of memory.\n");
          break;

        case ENT_ERR_INVPARM:
          Pike_error("_Caudium.parse_entities(): Invalid parameter.\n");
          break;

        case ENT_ERR_BUFTOOLONG:
          Pike_error("_Caudium.parse_entities(): Buffer too long.\n");
          break;

        case ENT_ERR_INVALIDNAME:
          Pike_error("_Caudium.parse_entities(): Invalid entity name.\n");
          break;
    }

   /* we've gotten this far, so we were probably successful. */

  result = make_shared_binary_string(eres->buf, eres->buflen);

  free(eres->buf);
  free(eres);

  push_string(result);
}

static void f_parse_headers( INT32 args )
{
  struct mapping *headermap;
  struct pike_string *headers;
  unsigned char *ptr;
  int len = 0, parsed = 0;
  
  get_all_args("_Caudium.parse_headers", args, "%S", &headers);
  headermap = allocate_mapping(1);
  ptr = (unsigned char *)headers->str;
  len = headers->len;
  /*
   * FIXME:
   * What do we do if memory allocation fails halfway through
   * allocating a new mapping? Should we return that half-finished
   * mapping or rather return NULL? For now it's the former case.
   * /Grendel
   *
   * If memory allocation fails, just bail out with error()
   */
  while(len > 0 &&
        (parsed = get_next_header(ptr, len, headermap)) >= 0 ) {
    ptr += parsed;
    len -= parsed;
  }
  if(parsed == -1) {
    Pike_error("_Caudium.parse_headers(): Out of memory while parsing.\n");
  }
  pop_n_elems(args);
  push_mapping(headermap);
}

/* This function parses the query string */
static void f_parse_query_string( INT32 args )     
{
  struct pike_string *query; /* Query string to parse */
  struct svalue *exist, skey, sval; /* svalues used */
  struct mapping *variables; /* Mapping to store vars in */
  unsigned char *ptr;   /* Pointer to current char in loop */
  unsigned char *name;  /* Pointer to beginning of name */
  unsigned char *equal; /* Pointer to the equal sign */
  unsigned char *end;   /* Pointer to the ending null char */
  int namelen, valulen; /* Length of the current name and value */
  
  get_all_args("_Caudium.parse_query_string", args, "%S%m", &query, &variables);
  skey.type = sval.type = T_STRING;
  /* end of query string */
  end = (unsigned char *)(query->str + query->len);
  name = ptr = (unsigned char *)query->str;
  equal = NULL;
  for(; ptr <= end; ptr++) {
    switch(*ptr)
    {
        case '=':
          /* Allow an unencoded '=' in the value. It's invalid but... */
          if(equal == NULL)
            equal=ptr;
          break;
        case '\0':
          if(ptr != end)
            continue;
        case ';': /* It's recommended to support ';'
                     instead of '&' in query strings... */
        case '&':
          if(equal == NULL) { /* value less variable, we can ignore this */
            name = ptr+1;     /* Can we really? What if an app relies
                               * upon the presence of a variable but
                               * doesn't give a damn about its
                               * value?
                               * /grendel
                               */
            break;
          }
          namelen = equal - name;
          valulen = ptr - ++equal;
          skey.u.string = url_decode(name, namelen, 0, 0);
          if (skey.u.string == NULL) { /* OOM. Bail out */
            Pike_error("_Caudium.parse_query_string(): Out of memory in url_decode().\n");
          }
          exist = low_mapping_lookup(variables, &skey);
          if(exist == NULL || exist->type != T_STRING) {
            sval.u.string = url_decode(equal, valulen, 0, 0);
            if (sval.u.string == NULL) { /* OOM. Bail out */
              Pike_error("_Caudium.parse_query_string(): Out of memory in url_decode().\n");
            }
          } else {
            /* Add strings separed with '\0'... */
            struct pike_string *tmp;
            tmp = url_decode(equal, valulen, 1, 0);
            if (tmp == NULL) {
              Pike_error("_Caudium.parse_query_string(): "
                         "Out of memory in url_decode().\n");
            }
            sval.u.string = add_shared_strings(exist->u.string, tmp);
            free_string(tmp);
          }
          low_mapping_insert(variables, &skey, &sval, 1);
/*           free_string(skey.u.string); */
/*           free_string(sval.u.string); */

          /* Reset pointers */
          equal = NULL;
          name = ptr+1;
    }
  }
  pop_n_elems(args);
}

/*
 * Parse the given string and fill the passed multisets with,
 * respectively, "normal" and "internal" prestates. Note that the
 * latter is filled only if the FIRST prestate is "internal" and in
 * such case the former has just one member - "internal".
 * Returns the passed url without the prestate part.
 */
static void f_parse_prestates( INT32 args ) 
{
  struct pike_string    *url;
  struct multiset       *prestate;
  struct multiset       *internal;
  struct svalue          ind;
  char                  *tmp;
  int                    prestate_end = -1;
  int                    done_first = 0, i;
  int                    last_start;
  
  get_all_args("_Caudium.parse_prestates", args, "%S%M%M",
               &url, &prestate, &internal);
  if (url->len < 5 || url->str[1] != '(') { /* must have at least '/(#)/ */
    pop_n_elems(args-1);  /* Leave URL on the stack == return it */
    return;
  }
 
  tmp = &url->str[3];
  while (tmp && *tmp) {
    if (*tmp == '/' && *(tmp - 1) == ')') {
      prestate_end = tmp - url->str;
      break;
    }
    tmp++;
  }

  if (prestate_end < 0) {
    pop_n_elems(args-1);  /* Leave URL on the stack == return it */
    return; /* not a prestate */
  }
  
  /*
   * Determine which prestate we should fill.
   */
  last_start = 2;
  for(i = 2; i <= prestate_end; i++) {
    if (url->str[i] == ',' || url->str[i] == ')') {
      int len = i - last_start;
      ind.type = T_STRING;
      
      switch(done_first) {
          case 0:
            if (!MEMCMP(&url->str[last_start], "internal", len)) {
              done_first = -1;
              ind.u.string = make_shared_string("internal");
            } else {
              done_first = 1;
              ind.u.string = make_shared_binary_string(&url->str[last_start], len);
            }
            
            multiset_insert(prestate, &ind);
            break;
            
          case -1:
            /* internal */
            ind.u.string = make_shared_binary_string(&url->str[last_start], len);
            multiset_insert(internal, &ind);
            break;
            
          default:
            /* prestate */
            ind.u.string = make_shared_binary_string(&url->str[last_start], len);
            multiset_insert(prestate, &ind);
            break;
      }
      free_svalue(&ind);
      last_start = i + 1;
    }
  }

  pop_n_elems(args);
  push_string(make_shared_string(url->str + prestate_end));
}

/*
** method: get_address(string addr)
**  Get the IP Address from Pike query_address string.
** arg: string addr
**  The address + port given from Pike with the following
**  format "ip.ad.dr.ess port" like this example "127.0.0.1 49505".
**  This function is low level and thus _very_ dumb - it will accept
**  strings _only_ in the format given above.
** returns:
**  The IP Address string.
** fixme:
**  This function works only with IPv4
*/
static void f_get_address(INT32 args) {
  int                  i = -1;
  struct pike_string  *res, *src;
  char                *orig = NULL;

  get_all_args("_Caudium.get_address", args, "%S", &src);
  
  if(src->len >= 7) {
    orig = src->str;

    /* We have at most 5 digits for the port (16 bit integer) */
    i = src->len-6;

    /* Unrolled loop to find the space separating the IP address and the port
     * number. We start looking at position 6 from the end and work backwards.
     * This is because we assume there are more 5 digits ports than 4 digit
     * ports etc.
     */
    if (!(orig[i] & 0xDF)) /* char 6 */
      goto doit;
    if (!(orig[++i] & 0xDF)) /* char 5 */
      goto doit;
    if (!(orig[++i] & 0xDF)) /* char 4 */
      goto doit;
    if (!(orig[++i] & 0xDF)) /* char 3 */
      goto doit;
    if (!(orig[++i] & 0xDF)) /* char 2 */
      goto doit;
    i = -1;
  }

  /* Don't frown, it's a good use of a label */
  doit:
  if (i < 0 || !orig)
    res = make_shared_binary_string("unknown", 7);
  else
    res = make_shared_binary_string(orig, i);
  
  pop_n_elems(args);
  push_string(res);
}

/*
** method: string get_port(string addr)
**  Get the IPv4 port from Pike query_address string
** string: string addr
**  The address + port given from Pike with the following
**  format "ip.ad.dr.ess port" like this example "127.0.0.1 5601"
** returns:
**  The port string
*/
static void f_get_port(INT32 args) {
  int i, found=0;
  struct pike_string *src;
  char *orig = NULL;

  get_all_args("_Caudium.get_port", args, "%S", &src);
  
  if(src->len < 7) {
    pop_n_elems(args);
    push_text("0"); 
  } else {
#ifdef HAVE_STRNDUPA
    orig = strndupa(src->str, src->len);
    if (!orig)
      Pike_error("Out of stack space");
#else
#ifdef HAVE_ALLOCA
    orig = alloca(src->len + 1);
#else
    orig = malloc(src->len + 1);
#endif
    if (!orig)
      Pike_error("Out of memory.");
    MEMCPY(orig, src->str, src->len);
    orig[src->len] = 0;
#endif
    
    for(i = src->len-1; i >=0; i--) {
      if(orig[i] == 0x20) { /* " " */
        found = 1;
        i++;
        break;
      }
    }
    
    if (found) {
      int len = src->len - i;
      pop_n_elems(args);
      push_string(make_shared_binary_string(orig+i, len));
    } else {
      pop_n_elems(args);
      push_text("0");
    }

#if !defined(HAVE_STRNDUPA) && !defined(HAVE_ALLOCA)
    if (orig)
      free(orig);
#endif
  }
}

/*
** method: string extension(string file)
**  Returns the extension name from the file. Eg foo.c will return c
**  checks also that file is not a known backup file.
** arg: string file
**  The file to get the extension
** returns:
**  The extension file
*/
static void f_extension( INT32 args ) {
  int i, found=0;
  struct pike_string *src;
  char *orig;

  get_all_args("_Caudium.extension", args, "%S", &src);  

#ifdef HAVE_STRNDUPA
  orig = strndupa(src->str, src->len);
  if (!orig)
    Pike_error("Out of stack space");
#else
#ifdef HAVE_ALLOCA
  orig = alloca(src->len + 1);
#else
  orig = malloc(src->len + 1);
#endif
  if (!orig)
    Pike_error("Out of memory.");
  MEMCPY(orig, src->str, src->len);
  orig[src->len] = 0;
#endif
  
  for(i = src->len-1; i >= 0; i--) {
    if(orig[i] == 0x2E) {
      found = 1;
      i++;
      break;
    }
  }
  
  if(found) {
    int len = src->len - i;    
    switch(orig[src->len-1]) {
        case '#': case '~':
          /* Remove unix backup extension */
          len--;
    }
    pop_n_elems(args);
    push_string(make_shared_binary_string(orig+i, len));
  } else {
    pop_n_elems(args);
    push_text("");
  }

#if !defined(HAVE_STRNDUPA) && !defined(HAVE_ALLOCA)
  if (orig)
    free(orig);
#endif
}

/*
** Some function like http_decode_url
** Since there is some calls inside this code, it should be good to use it.
*/
static void f_http_decode_url(INT32 args) {
  struct pike_string *tmp;
  struct pike_string *src;

  get_all_args("_Caudium.http_decode_url", args, "%S", &src);
  
  tmp = url_decode(src->str, src->len, 0, 2);
  if(tmp==NULL) {
    Pike_error("Out of memory.\n");
  }
  pop_n_elems(args);
  push_string(tmp);
}

/* Some basic http function to speedup caudium (and gets more free from Pike 
   changing things... */

/* convert bin to hex character */
#define BIN(c)  ((c) > '9' ? ((c) - 7) & 0xf : (c) & 0xf)

/* The following will convert char to hex */
static char *hex_chars = "0123456789ABCDEF";

/* routine used by all the *_encode_* functions below */
INLINE static struct pike_string *do_encode_stuff(struct pike_string *in, safe_func fun)
{
  int                 unsafe = 0;
  int                 out_len, in_len;
  unsigned char      *i, *out, *o;
    
  in_len = in->len - 1;

  if (!fun)
    Pike_error("BUG in Caudium.\n");
  
  /* check for unsafe characters */
  for(i=in->str; *i; i++)
    if (!fun(*i))
      unsafe++;

  if (!unsafe)
    return NULL;

  out_len = in_len + (unsafe << 1) + 1;

  out = malloc(out_len);
  if (!out)
    Pike_error("Out of memory.");

  for(o=out, i=in->str; *i; i++) {
    if (!fun(*i)) {
      *o++ = '%';
      *o++ = hex_chars[*i >> 4];
      *o++ = hex_chars[*i & 15];
    } else
      *o++ = *i;
  }

  *o++ = 0;
  
  if (out)
    free(out);
  
  return make_shared_string(out);
}

/* check if character given is safe */
/* maybe we'll probably need more safe char's here ? */

static INLINE int is_safe (char c) 
{
   if((c >= '0' && c <= 'g' ) ||
      (c >= 'A' && c <= 'Z' ) ||
      (c >= 'a' && c <= 'z' )
     ) return 1;
   return 0;
}

/*
** method: string http_encode(string m)
**   Encode with HTTP specification the given string
** arg: string m
**   The string to encode.
** returns:
**   The encoded string
*/
static void f_http_encode(INT32 args) 
{
  struct pike_string *src;
  struct pike_string *ret;
  
  get_all_args("_Caudium.http_encode", args, "%S", &src);

  ret = do_encode_stuff(src, is_safe);
  
  /* no need to convert	*/
  if(!ret) {
    pop_n_elems(args-1);
    return;
  }	

  pop_n_elems(args);
  push_string(ret);
}

/*
** method: string http_decode(string m)
**  Decode the string according to to the HTTP specifications
** arg: string m
**  The string to decode
** returns:
**  Decoded string
*/
static void f_http_decode(INT32 args) 
{
  struct pike_string *tmp;
  struct pike_string *src;

  get_all_args("_Caudium.http_decode", args, "%S", &src);
  
  tmp = url_decode(src->str, src->len, 0, 1);
  if(tmp==NULL) {
    Pike_error("_Caudium.http_decode(): Out of memory in url_decode().\n");
  }
  pop_n_elems(args);
  push_string(tmp);
}

/* Roxen 1.3 compat call */

/* Check if the char given is safe or not */
static INLINE int is_http_safe (char c)
{
   switch(c)
   {
     case 0:
     case ' ':
     case '\t':
     case '\n':
     case '\r':
     case '%':
     case '\'':
     case '\"':
     case '<':
     case '>':
     case '@':
          return 0; break;
     default:
          return 1; break;
   }
   return 1;  /* Never used, but added to keep some compilers happy */
}

/*
** method: string http_encode_string(string m)
**   HTTP encode the specified string and return it. This means replacing
**   the following characters to the %XX format: null (char 0), space, tab,
**   carriage return, newline, percent and single and double quotes.
** arg: string m
**   The string to encode.
** returns:
**   The HTTP encode string.
*/
static void f_http_encode_string(INT32 args)
{
  struct pike_string *src;
  struct pike_string *ret;
  
  get_all_args("_Caudium.http_encode_string", args, "%S", &src);

  ret = do_encode_stuff(src, is_http_safe);

  /* no need to convert	*/
  if(!ret) {
    pop_n_elems(args-1);
    return;
  }
  
  pop_n_elems(args);
  push_string(ret);
}

/* Check if the char given is safe or not */
static INLINE int is_cookie_safe (char c)
{
   switch(c)
   {
     case '=':
     case ',':
     case ';':
     case '%':
     case ':':
          return 0; break;
     default:
          return 1; break;
   }
   return 1;  /* Never used, but added to keep some compilers happy */
}

/*
** method: string http_encode_cookie(string m)
**   Encode the specified string in as to the HTTP cookie standard.
**   The following characters will be replaced: = , ; % :
** arg: string m
**   The string to encode.
** returns:
**   The HTTP cookie encoded string.
*/
static void f_http_encode_cookie(INT32 args)
{
  struct pike_string *ret;
  struct pike_string *src;

  get_all_args("_Caudium.http_encode_cookie", args, "%S", &src);

  ret = do_encode_stuff(src, is_cookie_safe);
  
  /* no need to convert	*/
  if(!ret) {
    pop_n_elems(args-1);
    return;
  }

  pop_n_elems(args);
  push_string(ret);
}

/* Check if the char given is safe or not */
static INLINE int is_url_safe (char c)
{
   switch(c)
   {
     case 0:
     case ' ':
     case '\t':
     case '\n':
     case '\r':
     case '%':
     case '\'':
     case '\"':
     case '#':
     case '&':
     case '?':
     case '=':
     case '/':
     case ':':
     case '+':
     case '<':
     case '>':
     case '@':
          return 0; break;
     default:
          return 1; break;
   }
   return 1;  /* Never used, but added to keep some compilers happy */
}

/*
** method: string http_encode_url(string m)
**   URL encode the specified string and return it. This means replacing
**   the following characters to the %XX format: null (char 0), space, tab,
**   carriage return, newline, and % ' " # & ? = / : +
** arg: string m
**   The string to encode.
** returns:
**   The URL encoded string.
*/
static void f_http_encode_url(INT32 args)
{
  struct pike_string *ret;
  struct pike_string *src;

  DERR(fprintf(stderr,"Calling http_encode_url\n"));
  get_all_args("_Caudium.http_encode_url", args, "%S", &src);

  DERR(fprintf(stderr,"Calling http_encode_url, encode the stuff\n"));
  ret = do_encode_stuff(src, is_url_safe);

  /* no need to convert	*/
  if(!ret) {
    pop_n_elems(args-1);
    return;
  }	

  DERR(fprintf(stderr,"Calling http_encode_url, send result\n"));
  pop_n_elems(args);
  push_string(ret);
}

/* Used for cern_http_date and for http_date */
const char *months[12]= { "Jan", "Feb", "Mar", "Apr", "May", "Jun", \
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/* Used for http_date */
const char *days[7]= { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };

/*
** method: string cern_http_date(int|void t)
**  Return the specified date (as returned by time()) formated in the
**  common log file format, which is "DD/MM/YYYY:HH:MM:SS [+/-]TZTZ".
** @param t
**  The time in seconds since the 00:00:00 UTC, January 1, 1970
**  If this argument is void, then the function returns the current 
**  date in common log format.
** @returns
**  The date in the common log file format
**  Example: 02/Aug/2000:22:36:27 -0700
*/
static void f_cern_http_date(INT32 args)
{
  time_t now;
  long diff;
  int sign;
  struct tm *tm;
  char date[sizeof "01/Dec/2002:16:22:43 +0100"];
  struct pike_string *ret;
  INT_TYPE timestamp;

  switch(args) {
   default:
     Pike_error("Wrong number of arguments _Caudium.cern_http_date(). Expected at most 1 argument.\n");
     break;

     case 1:
       get_all_args("_Caudium.cern_http_date", args, "%d", &timestamp);
       break;

     case 0:
       timestamp = 0;
       break;
   }
  
#ifdef HAVE_LOCALTIME_R
#ifdef HAVE_ALLOCA
   tm = (struct tm *)alloca(sizeof(struct tm));
#else /* HAVE_ALLOCA */
   tm = (struct tm *)malloc(sizeof(struct tm));
#endif /* HAVE_ALLOCA */
   if (tm == NULL) {
     Pike_error("_Caudium.cern_http_date(): Out of memory!\n");
     return;
   }
#endif /* HAVE_LOCALTIME_R */

  if(args == 0) {
    now = time(NULL);
#ifdef HAVE_LOCALTIME_R
    THREADS_ALLOW();
    tm = localtime_r(&now, tm);
    THREADS_DISALLOW();
#else /* HAVE_LOCALTIME_R */
    tm = localtime(&now);
#endif /* HAVE_LOCALTIME_R */

    if (now == (time_t) -1 ||
        tm == NULL ||
        tm->tm_mon > 11 || tm->tm_mon < 0) {
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
         free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
        return;
    }
   } else {
     now = (time_t)timestamp;
#ifdef HAVE_LOCALTIME_R
     if ((tm = localtime_r(&now, tm)) == NULL ||
#else /* HAVE_LOCALTIME_R */
     if ((tm = localtime(&now)) == NULL ||
#endif /* HAVE_LOCALTIME_R */
         tm->tm_mon > 11 || tm->tm_mon < 0) {
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
         free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
         return;
     }
   }
#ifdef HAVE_STRUCT_TM_TM_GMTOFF
  diff = -(tm->tm_gmtoff) / 60L;
#elif defined(HAVE_SCALAR_TIMEZONE)
  diff = -(timezone) / 60L;
#else
  {
    struct tm *gmt;
    struct tm *t;
    int days, hours, minutes;

#ifdef HAVE_GMTIME_R
#ifdef HAVE_ALLOCA
    gmt = (struct tm *)alloca(sizeof(struct tm));
#else /* HAVE_ALLOCA */
    gmt = (struct tm *)malloc(sizeof(struct tm));
#endif /* HAVE_ALLOCA */
    if (gmt==NULL) {
      Pike_error("_Caudium.cern_http_date(): Out of memory!\n");
      return;
    }
    THREADS_ALLOW();
    gmt = gmtime_r(&now, gmt);
    THREADS_DISALLOW();
#else /* HAVE_GMTIME_R */
    gmt = gmtime(&now);
#endif /* HAVE_GMTIME_R */

#ifdef HAVE_LOCALTIME_R
#ifdef HAVE_ALLOCA
    t = (struct tm *)alloca(sizeof(struct tm));
#else /* HAVE_ALLOCA */
    t = (struct tm *)malloc(sizeof(struct tm));
#endif /* HAVE_ALLOCA */
    if (t==NULL) {
      Pike_error("_Caudium.cern_http_date(): Out of memory!\n");
      return;
    }
    THREADS_ALLOW();
    t = localtime_r(&now, t);
    THREADS_DISALLOW();
#else /* HAVE_LOCALTIME_R */
    t = localtime(&now);
#endif /* HAVE_LOCALTIME_R */
    days = t->tm_yday - gmt->tm_yday;
    hours = ((days < -1 ? 24 : 1 < days ? -24 : days * 24)
             + t->tm_hour - gmt->tm_hour);
    minutes = hours * 60 + t->tm_min - gmt->tm_min;
    diff = -minutes;
#ifndef HAVE_ALLOCA
#ifdef HAVE_LOCALTIME_R
    free(t);
#endif /* HAVE_LOCALTIME_R */
#ifdef HAVE_GMTIME_R
    free(gmt);
#endif /* HAVE_GMTIME_R */
#endif /* HAVE_ALLOCA */
  }
#endif
  if (diff > 0L) {
    sign = '-';
  } else {
    sign = '+';
    diff = -diff;
  }
  if(snprintf(date, sizeof date, "%02d/%s/%d:%02d:%02d:%02d %c%02ld%02ld",
              tm->tm_mday, months[tm->tm_mon], tm->tm_year + 1900,
              tm->tm_hour, tm->tm_min, tm->tm_sec, sign, diff / 60L,
              diff % 60L) == sizeof date) {
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
     free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
     return;
  }
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
  free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
  ret = (make_shared_string(date));
  if(args == 1)
    pop_stack();
  push_string(ret);
}

/*
** method: string http_date(int|void t)
**  Return the specified date (as returned by time()) formatted in the
**  HTTP-protocol standart date format, which is "Day, DD MMM YYYY HH:MM:SS GMT".
**  Used in for example the Last-Modified header.
** @param t
**  The time in seconds since the 00:00:00 UTC, January 1, 1970
**  If this argument is void, then the function returns the current 
**  date in HTTP-protocol date format.
** @returns
**  The date in the HTTP standard date format.
**  Example: Wed, 11 Dec 2002 17:13:15 GMT
*/
static void f_http_date(INT32 args)
{
  time_t now;
  long diff;
  struct tm *tm;
  char date[sizeof "Wed, 11 Dec 2002 17:13:15 GMT"];
  struct pike_string *ret;
  INT_TYPE timestamp;
  int hour;

  switch(args) {
   default:
     Pike_error("Wrong number of arguments _Caudium.http_date(). Expected at most 1 argument..\n");
     break;

     case 1:
       get_all_args("_Caudium.http_date", args, "%d", &timestamp);
       break;

     case 0:
       timestamp = 0;
       break;
   }

#ifdef HAVE_LOCALTIME_R
#ifdef HAVE_ALLOCA
    tm = (struct tm *)alloca(sizeof(struct tm));
#else /* HAVE_ALLOCA */
    tm = (struct tm *)malloc(sizeof(struct tm));
#endif /* HAVE_ALLOCA */
    if (tm==NULL) {
       Pike_error("_Caudium.http_date(): Out of Memory!\n");
       return;
    }
#endif /* HAVE_LOCALTIME_R */

  if(args == 0) { 
    now = time(NULL);

#ifdef HAVE_LOCALTIME_R
    THREADS_ALLOW();
    tm = localtime_r(&now, tm);
    THREADS_DISALLOW();
#else /* HAVE_LOCALTIME_R */
    tm = localtime(&now);
#endif /* HAVE_LOCALTIME_R */

    if (now == (time_t) -1 ||
        tm == NULL ||
        tm->tm_mon > 11 || tm->tm_mon < 0) {
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
         free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
        return;
    }
   } else {
     now = (time_t)timestamp;
#ifdef HAVE_LOCALTIME_R
     if ((tm = localtime_r(&now,tm)) == NULL ||
#else /* HAVE_LOCALTIME_R */
     if ((tm = localtime(&now)) == NULL ||
#endif /* HAVE_LOCALTIME_R */
         tm->tm_mon > 11 || tm->tm_mon < 0) {
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
         free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
         return;
     }
   }
#ifdef HAVE_STRUCT_TM_TM_GMTOFF
  diff = -(tm->tm_gmtoff) / 60L;
#elif defined(HAVE_SCALAR_TIMEZONE)
  diff = -(timezone) / 60L;
#else
  {
    struct tm *gmt;
    struct tm *t;
    int days, hours, minutes;

#ifdef HAVE_GMTIME_R
#ifdef HAVE_ALLOCA
    gmt = (struct tm *)alloca(sizeof(struct tm));
#else /* HAVE_ALLOCA */
    gmt = (struct tm *)malloc(sizeof(struct tm));
#endif /* HAVE_ALLOCA */
    if (gmt==NULL) {
       Pike_error("_Caudium.http_date(): Out of Memory!\n");
       return;
    }
    THREADS_ALLOW();
    gmt = gmtime_r(&now, gmt);
    THREADS_DISALLOW();
#else /* HAVE_GMTIME_R */
    gmt = gmtime(&now);
#endif /* HAVE_GMTIME_R */

#ifdef HAVE_LOCALTIME_R
#ifdef HAVE_ALLOCA
    t = (struct tm *)alloca(sizeof(struct tm));
#else /* HAVE_ALLOCA */
    t = (struct tm *)malloc(sizeof(struct tm));
#endif /* HAVE_ALLOCA */
    if (gmt==NULL) {
       Pike_error("_Caudium.http_date(): Out of Memory!\n");
       return;
    }
    THREADS_ALLOW();
    t = localtime_r(&now, t);
    THREADS_DISALLOW();
#else /* HAVE_LOCALTIME_R */
    t = localtime(&now);
#endif /* HAVE_LOCALTIME_R */
    days = t->tm_yday - gmt->tm_yday;
    hours = ((days < -1 ? 24 : 1 < days ? -24 : days * 24)
             + t->tm_hour - gmt->tm_hour);
    minutes = hours * 60 + t->tm_min - gmt->tm_min;
    diff = -minutes;
#ifndef HAVE_ALLOCA
#ifdef HAVE_LOCALTIME_R
    free(t);
#endif /* HAVE_LOCALTIME_R */
#ifdef HAVE_GMTIME_R
    free(gmt);
#endif /* HAVE_GMTIME_R */
#endif /* HAVE_ALLOCA */

  }
#endif
  if (diff <= 0L) {
    diff = -diff;
  }
  hour = tm->tm_hour;
  hour = hour - (int)(diff / 60L);
  if (hour < 0)
    hour = 24 + hour;
  if(snprintf(date, sizeof date, "%s, %02d %s %d %02d:%02d:%02d GMT",
              days[tm->tm_wday], tm->tm_mday, months[tm->tm_mon], tm->tm_year + 1900,
              hour, (tm->tm_min) - (int)(diff % 60L), 
              tm->tm_sec ) == sizeof date) {
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
     free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
     return;
  }
#ifdef HAVE_LOCALTIME_R
#ifndef HAVE_ALLOCA
  free(tm);
#endif /* HAVE_ALLOCA */
#endif /* HAVE_LOCALTIME_R */
  ret = (make_shared_string(date));
  if(args == 1)
    pop_stack();
  push_string(ret);
}

  
/* Initialize and start module */
void pike_module_init( void )
{
  unsigned   i;
  
  STRS(data)       = make_shared_string("data");
  STRS(file)       = make_shared_string("file");
  STRS(method)     = make_shared_string("method");
  STRS(protocol)   = make_shared_string("protocol");
  STRS(query)      = make_shared_string("query");
  STRS(raw_url)    = make_shared_string("raw_url");
  STRS(mta_slash)  = make_shared_string("/");
  STRS(mta_equals) = make_shared_string("=");
  
  strs.mta_equals_p = MKPCHARP_STR(strs.mta_equals.u.string);
  
  SVAL(data)->type       = T_STRING;
  SVAL(file)->type       = T_STRING;
  SVAL(method)->type     = T_STRING;
  SVAL(protocol)->type   = T_STRING;
  SVAL(query)->type      = T_STRING;
  SVAL(raw_url)->type    = T_STRING;
  SVAL(mta_slash)->type  = T_STRING;
  SVAL(mta_equals)->type = T_STRING;

  for (i = 0; i < UNSAFECHARS_SIZE; i++)
    push_text(_unsafechars[i]);
  mta_unsafe_chars = aggregate_array(UNSAFECHARS_SIZE);

  for (i = 0; i < UNSAFECHARS_SIZE; i++)
    push_text(_safeentities[i]);
  mta_safe_entities = aggregate_array(UNSAFECHARS_SIZE);
  
  add_function_constant( "parse_entities", f_parse_entities,
                         "function(string,mapping:string)", 0);
  add_function_constant( "parse_headers", f_parse_headers,
                         "function(string:mapping)", 0);
  add_function_constant( "parse_query_string", f_parse_query_string,
                         "function(string,mapping:void)",
                         OPT_SIDE_EFFECT);
  add_function_constant( "parse_prestates", f_parse_prestates,
                         "function(string,multiset,multiset:string)",
                         OPT_SIDE_EFFECT);
  add_function_constant( "get_address", f_get_address,
                         "function(string:string)", 0);
  add_function_constant( "get_port", f_get_port,
                         "function(string:string)", 0);
  add_function_constant( "extension", f_extension,
                         "function(string:string)", 0);
  /* Functions to replace base_server/http.pike calls */
  add_function_constant( "http_encode", f_http_encode,
                         "function(string:string)", 0);
  add_function_constant( "http_decode", f_http_decode,
                         "function(string:string)", 0);
  add_function_constant( "cern_http_date", f_cern_http_date,
                         "function(int|void:string)", 0);
  add_function_constant( "http_date", f_http_date,
                         "function(int|void:string)", 0);
  /* Roxen 1.X compat functions */
  add_function_constant( "http_encode_string", f_http_encode_string,
                         "function(string:string)", 0);
  add_function_constant( "http_encode_cookie", f_http_encode_cookie,
                         "function(string:string)", 0);
  add_function_constant( "http_encode_url", f_http_encode_url,
                         "function(string:string)", 0);
  add_function_constant( "http_decode_url", f_http_decode_url,
                         "function(string:string)", 0);

  /* temporary, don't use */
  add_function_constant( "_make_tag_attributes", f_make_tag_attributes,
                         "function(mapping:string)", 0);
  
  init_datetime();
  
  start_new_program();
  ADD_STORAGE( buffer );
  add_function( "append", f_buf_append,
                "function(string:int)", OPT_SIDE_EFFECT );
  add_function( "create", f_buf_create, "function(mapping,mapping,int|void:void)", 0 );
  set_init_callback(alloc_buf_struct);
  set_exit_callback(free_buf_struct);
  end_class("ParseHTTP", 0);
  init_nbio();
}

/* Restore and exit module */
void pike_module_exit( void )
{
  free_string(STRS(data));
  free_string(STRS(file));
  free_string(STRS(method));
  free_string(STRS(protocol));
  free_string(STRS(query));
  free_string(STRS(raw_url));
  free_string(STRS(mta_slash));
  free_string(STRS(mta_equals));
  
  free_array(mta_unsafe_chars);
  free_array(mta_safe_entities);
  
  exit_nbio();
  exit_datetime();
}

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2 
 */
