;/* $Id$ */
#include "global.h"
RCSID("$Id$");
#include "stralloc.h"
#include "mapping.h"
#include "pike_macros.h"
#include "module_support.h"
#include "error.h"

#include "threads.h"
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>

#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif

static void f_parse_headers( INT32 args );
static void f_parse_query_string( INT32 args );

/* Initialize and start module */
void pike_module_init( void )
{
  add_function_constant( "parse_headers", f_parse_headers,
			 "function(string:mapping)", 0);
  add_function_constant( "parse_query_string", f_parse_query_string,
			 "function(string,mapping:string)",
			 OPT_SIDE_EFFECT);
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

/* helper functions */
INLINE static struct pike_string *lowercase(unsigned char *str, INT32 len)
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
      *p = *p | 32; /* OR is faster than addition and we just need
                     * to set one bit :-). */
    }
  }
  pstr = make_shared_binary_string(mystr, len);
#ifndef HAVE_ALLOCA
  free(mystr);
#endif
  return pstr;
}

/* Decode QUERY encoded strings.
   Simple decodes %XX and + in the string. If exist is true, add a null char
   first in the string. 
 */
INLINE static struct pike_string *url_decode(unsigned char *str,
						      int len, int exist)
{
  int nlen = 0, i;
  unsigned char *mystr; /* Work string */ 
  unsigned char *ptr, *end, *prc; /* beginning and end pointers */
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
	mystr[i] = '\0';
      ptr+=3;
      nlen++;
      break;
     case '+':
      ptr++;
      mystr[i] = ' ';
      nlen++;
      break;
     default:
      mystr[i] = *(ptr++);
      nlen++;
    }
  }

  newstr = make_shared_binary_string(mystr, nlen+exist);
#ifndef HAVE_ALLOCA
  free(mystr);
#endif
  return newstr;
}


#if 0
// Code to add a string to a string 
value = begin_shared_string(count2 - data + exist->u.string->len+1);
MEMCPY(value->str, exist->u.string->str, exist->u.string->len+1);
MEMCPY(value->str + exist->u.string->len + 1,
       heads + data, count2 - data + 1);
value->str[count2 - data + 1 + exist->u.string->len] = '\0';
value = end_shared_string(value);
sval.u.string = value;
mapping_insert(headermap, &skey, &sval);
#endif

INLINE static int get_next_header(unsigned char *heads, int len,
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
      sval.u.string = make_shared_binary_string(heads+data, count2 - data);
      mapping_insert(headermap, &skey, &sval);
      count = count2;
      free_string(skey.u.string);
      free_string(sval.u.string);
      break;
     case '\n':
      /*printf("Returning %d read\n", count);*/
      return count+1;
    }
  }
  return count;
}

/** Functions implementing Pike functions **/

static void f_parse_headers( INT32 args )
{
  struct mapping *headermap;
  struct pike_string *headers;
  unsigned char *ptr;
  int len = 0, parsed = 0;
  get_all_args("Caudium.parse_headers", args, "%S", &headers);
  headermap = allocate_mapping(1);
  ptr = headers->str;
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
    error("Caudium.parse_headers(): Out of memory while parsing.\n");
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
  
  get_all_args("Caudium.parse_query_string", args, "%S%m", &query, &variables);
  skey.type = T_STRING;
  sval.type = T_STRING;

  /* end of query string */
  end = query->str + query->len;
  name = ptr = query->str;
  equal = NULL;
  for(; ptr <= end; ptr++) {
    switch(*ptr)
    {
     case '=':
      equal=ptr;
      break;
     case '\0':
      if(ptr != end)
	continue;
     case ';': /* It's recommended to support ; instead of & in query strings */
     case '&':
      if(equal == NULL) { /* value less variable, we can ignore this */
	name = ptr+1;
	break;
      }
      namelen = equal - name;
      valulen = ptr - ++equal;
      skey.u.string = url_decode(name, namelen, 0);
      if (skey.u.string == NULL) { /* OOM. Bail out */
	error("Caudium.parse_query_string(): Out of memory in url_decode().\n");
      }
      exist = low_mapping_lookup(variables, &skey);
      if(exist == NULL || exist->type != T_STRING) {
	sval.u.string = url_decode(equal, valulen, 0);
	if (sval.u.string == NULL) { /* OOM. Bail out */
	  error("Caudium.parse_query_string(): "
		"Out of memory in url_decode().\n");
	}
      } else {
	/* Add strings separed with '\0'... */
	struct pike_string *tmp;
	tmp = url_decode(equal, valulen, 1);
	if (tmp == NULL) {
	  error("Caudium.parse_query_string(): "
		"Out of memory in url_decode().\n");
	}
	sval.u.string = add_shared_strings(exist->u.string, tmp);
	free_string(tmp);
      }
     
      mapping_insert(variables, &skey, &sval);
      free_string(skey.u.string);
      free_string(sval.u.string);

      /* Reset pointers */
      equal = NULL;
      name = ptr+1;
    }
  }
  pop_n_elems(args);
  push_int(0);
}
