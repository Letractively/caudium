/* $Id$ */
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

static void f_parse_headers( INT32 args );

/* Initialize and start module */
void pike_module_init( void )
{
  add_function_constant( "parse_headers", f_parse_headers,
			 "function(string:mapping)", OPT_SIDE_EFFECT);
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

/* helper functions */
INLINE static unsigned char *lowercase(unsigned char *str, INT32 len)
{
  int changed = 0;
  unsigned char *p, *end;
  unsigned char *mystr;
  mystr = malloc((len + 1));
  MEMCPY(mystr, str, len);
  end = mystr + len;
  mystr[len] = '\0';
  for(p = mystr; p < end; p++)
  {
    if(*p >= 'A' && *p <= 'Z') {
      *p = *p+32;
    }
  }
  return mystr;
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

INLINE static unsigned int get_next_header(unsigned char *heads, int len,
					   struct mapping *headermap)
{
  struct pike_string *name, *value;
  int data, count, colon, count2=0;
  struct svalue skey, sval;
  unsigned char *lowered;

  /* FIXME: error checking would be nice */
  for(count=0, colon=0; count < len; count++) {
    switch(heads[count]) {
     case ':':
      colon = count;
      data = colon + 1;
      for(count2 = data; count2 < len; count2++)
	/* find end of header data */
	if(heads[count2] == '\r') break;
      while(heads[data] == ' ') data++;
      lowered = lowercase(heads, colon);
      name = make_shared_binary_string(lowered, colon);
      free(lowered);
      skey.type = T_STRING;
      sval.type = T_STRING;
      skey.u.string = name;
      value = make_shared_binary_string(heads+data, count2 - data);
      sval.u.string = value;
      mapping_insert(headermap, &skey, &sval);
      count = count2;
      /* printf("Got [%s] = [%s(%d)]\n", name->str, value->str, value->len);*/
      free_string(value);
      free_string(name);
      break;
     case '\n':
      /*printf("Returning %d read\n", count);*/
      return count+1;
    }
  }
  return 0;
}

/** Functions implementing Pike functions **/
static void f_parse_headers( INT32 args )
{
  struct mapping *headermap;
  struct pike_string *headers;
  unsigned char *ptr;
  int len = 0, parsed;
  get_all_args("Caudium.parse_headers", args, "%S", &headers);
  headermap = allocate_mapping(1);
  ptr = headers->str;
  len = headers->len;
  while(len > 0 &&
	(parsed = get_next_header(ptr, len, headermap))) {
    ptr += parsed;
    len -= parsed;
  }  
  pop_n_elems(args);
  push_mapping(headermap);
}
