/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "ultraparse.h"

extern char char_class[1<<CHAR_BIT];
#if 0
void foo() { 
  if(s->type == T_INT && count->type == T_INT)
    s->u.integer+=count->u.integer;
  else {          
    push_svalue(s); push_svalue(count); f_add(2);                         
    mapping_string_insert(mappingen, key, Pike_sp-1); pop_stack();
  }
  if(s->type == T_INT && count->type == T_INT &&                
     !INT_TYPE_ADD_OVERFLOW(count->u.integer, s->u.integer))
  { /*fast      
      add*/} else { /*f_add*/ }   
}
#endif

INT32 lmu=0;
#define LML(x,y)  low_mapping_lookup(x,y); lmu++;

/* Decode %XX encoded strings.*/
INLINE struct pike_string *http_decode_string(unsigned char *foo, int len)
{
   int proc, nlen=0;
   unsigned char *bar,*end;
   struct pike_string *newstr;
   bar = foo;
   end = foo + len;

   /* count '%' characters */
   for (proc =0 ; foo < end; )
     if (*(foo++) == '%') {
       proc=1;
       break;
     } 
   if (!proc) { return make_shared_binary_string((char *)bar, len);  }
   foo = bar;
   for (proc=0; bar < end; proc++) {
     if (*bar=='%') 
     { 
       if (bar < end-2)
	 foo[proc]=(( (bar[1] < 'A') ? (bar[1] & 15) :(( bar[1] + 9) &15)) << 4)|
	   ((bar[2] < 'A') ? (bar[2] & 15) : ((bar[2] + 9)& 15));
       else
	 foo[proc]=0;
       bar+=3;
       nlen++;
     } 
     else { foo[proc]=*(bar++); nlen++; }
   }
   foo[proc] = '\0';
   return make_shared_binary_string((char *)foo, nlen);
}

INLINE int ultra_lowercase(unsigned char *str, INT32 len)
{
  int changed = 0;
  unsigned char *p, *end = str + len;  
  for(p = str; p < end; p++)
  {
    if(*p >= 'A' && *p <= 'Z') {
      *p = *p+32;
      if(!changed) changed = 1;
    }
  }
  return changed;
}

INLINE unsigned char *ultra_lowercase_host(unsigned char *ref, INT32 *trunc,
					   int *changed)
{
  void *slash = NULL;
  int len, sub_len;
  unsigned char *kss = NULL; /* Pointer for kolon slash slash  */
  unsigned char *work;
  len = strlen((char *)ref);
  work = malloc(len+1);
  strcpy(work, ref);
  *changed = 0;
  if(len < 8 || (kss = (unsigned char *)strstr((char *)ref, "://")) == NULL) {
    if(trunc) {
      free(work);
      return NULL;
    } else {
      return work;
    }
  }
  kss += 3;
  slash = (unsigned char *)MEMCHR ((char *)kss, '/', strlen((char *)kss));
  
  if(slash) {
    sub_len = ((unsigned char *)slash - ref) + 1;
    if(trunc) {   *trunc=sub_len; }
  } else {
    sub_len = len;
    if(trunc) { *trunc = len; }
  }
  *changed = ultra_lowercase(work, sub_len);
  /*  if(*changed)*/
  /*fprintf(stderr, "%s ->\n\t%s (%d,%d,%d)\n",*/
  /* ref, work, *changed, sub_len, len);*/
  return work;
}


/* Add 1 to an integer entry in a mapping */
struct svalue ett;                                           
struct svalue intie;                                           

INLINE void mapaddstr( struct mapping * mappingen, struct pike_string *key)
{
  struct svalue *s;
  struct svalue skey;
  skey.type = T_STRING;
  skey.u.string = key;
  s = LML( mappingen, &skey );
  if( !s ) {
    mapping_insert( mappingen, &skey, &ett);
  } else                                                                
    s->u.integer++;                                                  
}           

INLINE void mapaddintnum( struct mapping * mappingen, struct svalue *key, struct svalue *count)
{
  struct svalue *s;                                                   
  s = LML( mappingen, key );                 
  if( !s ) {
    mapping_insert( mappingen, key, count);
  } else                                                                
    s->u.integer += count->u.integer;                                                
}           

INLINE void mapaddsval( struct mapping * mappingen, struct svalue *key)
{
  struct svalue *s;                                                   
  s = LML( mappingen, key );                 
  if( !s ) {
    mapping_insert( mappingen, key, &ett);
  } else                                                                
    s->u.integer++;
}           

INLINE void mapaddfloatnum( struct mapping * mappingen, struct svalue *key, struct svalue *count)
{
  struct svalue *s;                                                   
  s = LML( mappingen, key );                 
  if( !s ) {
    mapping_insert( mappingen, key, count);
  } else {
    s->u.float_number += count->u.float_number;
  }
}           



INLINE void mapaddstrnum(struct mapping * mappingen, struct pike_string *key,
			 struct svalue *count)
{
  struct svalue *s;                                                   
  struct svalue skey;
  skey.type = T_STRING;
  skey.u.string = key;
  s = LML( mappingen, &skey );                 
  if( !s ) {
    mapping_insert( mappingen, &skey, count);
  } else                                                                
    s->u.integer += count->u.integer;
}           

INLINE void mapaddstrmap(struct mapping * mappingen, struct pike_string *key,
			 struct mapping *map)
{
  struct svalue *s;                                                   
  struct svalue skey;
  skey.type = T_STRING;
  skey.u.string = key;
  s = LML( mappingen, &skey );                 
  if( !s ) {
    struct svalue mappie;                                           
    mappie.type = T_MAPPING;
    mappie.u.mapping = map;
    mapping_insert( mappingen, &skey, &mappie);
    free_mapping(map);
  } else                                                                
    do_map_addition(s->u.mapping, map);
}           


INLINE void mapaddint( struct mapping * mappingen, int key)
{
  struct svalue *s;
  intie.u.integer = key;                                                
  s = LML( mappingen, &intie );                 
  if( !s ) {
    mapping_insert( mappingen, &intie, &ett);
  } else                                                                
    s->u.integer++;                                                  
}           

INLINE void map2addint( struct mapping * mappingen, int subkey, struct pike_string *key)
{
  struct svalue *s;                                                   
  intie.u.integer = subkey;                                                
  s = LML( mappingen, &intie );                 
  if( !s ) {
    struct svalue mappie;                                           
    struct mapping *map = allocate_mapping(1);
    mappie.type = T_MAPPING;
    mappie.u.mapping = map;
    mapping_insert( mappingen, &intie, &mappie);
    mapaddstr(map, key);
    free_mapping(map);
  } else 
    mapaddstr(s->u.mapping, key);
}  

INLINE void mapaddstrint( struct mapping * mappingen,
			  struct pike_string *key,
			  int subkey)
{
  struct svalue *s;                                                   
  struct svalue skey;
  skey.type = T_STRING;
  skey.u.string = key;
  s = LML( mappingen, &skey );                 
  if( !s ) {
    struct svalue mappie;                                           
    struct mapping *map = allocate_mapping(1);
    mappie.type = T_MAPPING;
    mappie.u.mapping = map;
    mapping_insert( mappingen, &skey, &mappie);
    mapaddint(map, subkey);
    /*    mapaddint(map, 0);*/
    free_mapping(map);
  } else {
    mapaddint(s->u.mapping, subkey);
    /*    mapaddint(s->u.mapping, 0);*/
  }
}  

INLINE void map2addstrnum( struct mapping * mappingen,
			   struct pike_string *key,
			   struct pike_string *key2,
			   struct svalue *value)
{
  struct svalue *s;                                                   
  struct svalue mappie;                                           
  struct svalue skey;
  skey.type = T_STRING;
  skey.u.string = key;
  s = LML( mappingen, &skey );                 
  if( !s ) {
    struct mapping *map = allocate_mapping(1);
    mappie.type = T_MAPPING;
    mappie.u.mapping = map;
    mapping_insert( mappingen, &skey, &mappie);
    mapaddstrnum(map, key2, value);
    free_mapping(map);
  } else 
    mapaddstrnum(s->u.mapping, key2, value);
}
INLINE void map2addstr( struct mapping * mappingen,
			struct pike_string *key,
			struct pike_string *key2)
{
  struct svalue *s;                                                   
  struct svalue mappie;                                            
  struct svalue skey;
  skey.type = T_STRING;
  skey.u.string = key;
  s = LML( mappingen, &skey );                 
  if( !s ) {
    struct mapping *map = allocate_mapping(1);
    mappie.type = T_MAPPING;
    mappie.u.mapping = map;
    mapping_insert( mappingen, &skey, &mappie);
    mapaddstr(map, key2);
    free_mapping(map);
  } else 
    mapaddstr(s->u.mapping, key2);
}  

INLINE int multiset_string_lookup(struct multiset *multi, char *str)
{
  INT32 member;
  struct svalue sval;
  struct pike_string *pstr;
  pstr = make_shared_binary_string(str, strlen(str));
  sval.type = T_STRING;
  sval.u.string = pstr;
  member =  multiset_member(multi, &sval);
  free_string(pstr);
  return member;
}

  

INLINE int ispage(struct pike_string *url, struct multiset *pagexts)
{
  char *dot;
  int cnt;
  if(!url->len)
    return 0;
  if(*(url->str+url->len-1) == '/' || *(url->str) != '/') {
    return 1;
  }
    
  dot = STRRCHR(url->str, '.');
  if(dot && multiset_string_lookup(pagexts, dot+1)) {
    return 1;
  }
  return 0;
}

INT32 hourly_page_hits(struct mapping *urls,
		       struct mapping *pages,
		       struct mapping *hits,
		       struct multiset *pagexts,
		       INT32 code)	
{
  INT32 i, e, len;
  struct svalue *sind;
  struct svalue *sval;
  struct pike_string *decoded;
  unsigned char *decode_buf;
  unsigned char *qmark;
  unsigned INT32 numpages = 0;
  struct keypair *k;
  decode_buf = malloc(MAX_LINE_LEN+1);

  MY_MAPPING_LOOP(urls, e, k)
  {
    sind = &k->ind;
    sval = &k->val;
    qmark = (unsigned char *)STRCHR(sind->u.string->str, '?');
    if(qmark) {
      MEMCPY(decode_buf, sind->u.string->str,
	      len = MIN(MAX_LINE_LEN, ((INT32)qmark - (INT32)sind->u.string->str - 1)));
      
    } else {
      MEMCPY(decode_buf, sind->u.string->str, len = MIN(MAX_LINE_LEN, sind->u.string->len));
    }
    decoded = http_decode_string(decode_buf, len);

    if(ispage(decoded, pagexts)) {
      numpages += sval->u.integer;
      /*      printf("\tPAGE: %5d\t%s\n", sval->u.integer, decoded->str);*/
      mapaddstrnum(pages, decoded, sval);	
    } else {
      /*      printf("\tHIT:  %5d\t%s\n", sval->u.integer, decoded->str);*/
      mapaddstrnum(hits, decoded, sval);
    }
    free_string(decoded);
  }
  free(decode_buf);
  /*  printf("%-5d %-5d\t", pagecount, hitcount);*/
  return numpages;
}

void http_decode_mapping(struct mapping *source,
			 struct mapping *dest)
{
  INT32 e;
  struct svalue *sind;
  struct svalue *sval;
  struct pike_string *decoded;

  unsigned char *decode_buf;
  struct keypair *k;
  decode_buf = malloc(MAX_LINE_LEN+1);
  MY_MAPPING_LOOP(source, e, k)
  {
    sind = &k->ind;
    sval = &k->val;
    MEMCPY(decode_buf, sind->u.string->str, MIN(MAX_LINE_LEN, sind->u.string->len));
    decoded = http_decode_string(decode_buf, sind->u.string->len);
    mapaddstrnum(dest, decoded, sval);
    free_string(decoded);
  }
  free(decode_buf);
}

void summarize_refsites(struct mapping *refsites,
			struct mapping *referrers,
			struct mapping *new_referrers)
{
  INT32  e, sidx, end;
  struct svalue *sind, *sval;
  struct pike_string *str, *str2;
  struct keypair *k;
  unsigned char *lowered;
  int len, changed, trunc=1;
  MY_MAPPING_LOOP(referrers, e, k)
  {
    sind = &k->ind;
    str = sind->u.string;
    lowered = ultra_lowercase_host((unsigned char *)str->str,
				   &trunc, &changed);
    if(lowered) {
      sval = &k->val;
      if(changed) {
	str2 = make_shared_binary_string((char *)lowered, str->len);
	mapaddstrnum(new_referrers, str2, sval);
	if(trunc != str->len) {
	  free_string(str2);
	  str2 = make_shared_binary_string((char *)lowered, trunc);
	}
	mapaddstrnum(refsites, str2, sval);
	free_string(str2);
      } else {
	mapaddstrnum(new_referrers, str, sval);
	if(trunc != str->len) {
	  str2 = make_shared_binary_string((char *)lowered, trunc);
	  mapaddstrnum(refsites, str2, sval);
	  free_string(str2);
	} else 
	  mapaddstrnum(refsites, str, sval);
      }
      free(lowered);
    }
  }
}

/* This function creates domain and top domain statistics */
void summarize_hosts(struct mapping *hosts,
		     struct mapping *domains,
		     struct mapping *topdomains,
		     struct mapping *newhosts)
{
  INT32 changed, i, e, sidx, end;
  struct svalue *sind, *sval;
  struct pike_string *str, *str2, *unknown;
  struct keypair *k;
  unsigned char *point = NULL; /* Pointer for dots.  */
  int top_done=0, done = 0;
  unsigned char tmpstr[MAX_LINE_LEN+1];
  unknown = make_shared_binary_string("Unresolved", 10);

  MY_MAPPING_LOOP(hosts, e, k)
  {
    sind = &k->ind;
    str = sind->u.string;
    sval = &k->val;
    if(str->len < MAX_LINE_LEN) {
      if(str->len > 1) {
	MEMCPY(tmpstr, str->str, str->len);
	changed = ultra_lowercase(tmpstr, str->len);
	tmpstr[str->len] = '\0';
	if(changed) {
	  str2 = make_shared_binary_string((char *)tmpstr, str->len);
	  mapaddstrnum(newhosts, str2, sval);	  
	  free_string(str2);
	} else {
	  mapaddstrnum(newhosts, sind->u.string, sval);
	} 
	point = (tmpstr + str->len-1);
	
	while(point != tmpstr)
	{
	  point--;
	  if(*point == '.')
	  {	
	    if(!top_done) {
	      if(char_class[*(point+1)] == CLS_DIGIT) {
		/* This is an ip */
		top_done = 2;
		break;
	      } else {
		/* This is a resolved ip */
		str2 = make_shared_string((char *)(point+1));
		mapaddstrnum(topdomains, str2, sval);
		free_string(str2);
		top_done = 1;
	      }
	    } else {
	      /* second level domain */
	      str2 = make_shared_string((char *)(point+1));
	      mapaddstrnum(domains, str2, sval);
	      free_string(str2);
	      top_done = 2;
	      break;
	    }
	  }
	}
      } else {
	mapaddstrnum(topdomains, unknown, sval);
	mapaddstrnum(domains, unknown, sval);
	top_done = 2;
      }
    }
    switch(top_done) {
     case 0:
      mapaddstrnum(topdomains, str, sval);
     case 1:
      mapaddstrnum(domains, str, sval);
    }
    top_done = 0;
  }

  free_string(unknown);
}


void summarize_directories(struct mapping *dirs, struct mapping *files)
{
  INT32 i, e, sidx, end;
  struct svalue *sind;
  struct keypair *k;
  struct pike_string *str, *str2;
  void *slash = NULL;

  MY_MAPPING_LOOP(files, e, k)
  {
    sind = &k->ind;
    str = sind->u.string;
    if(!str->len)
      continue;
    if(*str->str != '/')
    {
      str2 = make_shared_binary_string("Unknown", 8);
    } else { 
      if(str->len > 1) {
	slash = MEMCHR(str->str+1, '/', str->len-1);
	if(!slash || ((char *)slash - str->str) < 2)
	  str2 = make_shared_binary_string(str->str, 1);
	else
	  str2 = make_shared_binary_string(str->str,
					   ((char *)slash - str->str) + 1);
      } else {
	str2 = make_shared_binary_string(str->str, 1);
      }
    }
    mapaddstrnum(dirs, str2, &k->val);
    free_string(str2);
  }
}

/* Remove referrers pointing to non-pages */
INLINE void clean_refto(struct mapping *refto, struct mapping *refdest, struct multiset *pagexts)
{
  INT32 i, len, e;
  struct svalue *sind, *sind2;
  struct svalue *sval, *sval2;
  struct keypair *k, *k2;
  struct pike_string *decoded, *plowered;
  unsigned char *decode_buf, *lowered;
  unsigned char *qmark;
  int changed;
  decode_buf = malloc(MAX_LINE_LEN+1);
  
  MY_MAPPING_LOOP(refto, e, k)
  {
    sind = &k->ind;
    qmark = (unsigned char *)STRCHR(sind->u.string->str, '?');
    if(qmark) {
      MEMCPY(decode_buf, sind->u.string->str,
	     len = MIN(MAX_LINE_LEN, ((INT32)qmark - (INT32)sind->u.string->str - 1)));
      
    } else {
      MEMCPY(decode_buf, sind->u.string->str, len = MIN(sind->u.string->len, MAX_LINE_LEN));
    }
    decoded = http_decode_string(decode_buf, len);
    if(ispage(decoded, pagexts)) {
      sval = &k->val;

      MY_MAPPING_LOOP(sval->u.mapping, i, k2)
      {
	sind2 = &k2->ind;
	sval2 = &k2->val;
	MEMCPY(decode_buf, sind2->u.string->str,
	       len = MIN(sind2->u.string->len, MAX_LINE_LEN));
	decode_buf[len] = 0;
	lowered = ultra_lowercase_host(decode_buf, 0, &changed);
	if(lowered) {
	  plowered = make_shared_binary_string((char *)lowered, len);
	  map2addstrnum(refdest, decoded, plowered, sval2);
	  /*	  printf("%s -> %s : %d\n",  plowered->str, decoded->str,*/
	  /*		 sval2->u.integer);*/
	  free_string(plowered);
	  free(lowered);
	} else {
	  map2addstrnum(refdest, decoded, sind2->u.string, sval2);
	  /*	  printf("%s -> %s : %d\n",  sind2->u.string->str, decoded->str,*/
	  /*		 sval2->u.integer);*/
	}
	/*      mapaddstrmap(refdest, decoded, sval->u.mapping);*/
      }
    }
    free_string(decoded);
  }
  free(decode_buf);
  /*  printf("%-5d %-5d\t", pagecount, hitcount);*/
}



void f_add_mapping(INT32 args)
{
  struct mapping *to, *from;  

  get_all_args("Ultraparse.add_mapping", args, "%m%m", &to, &from);
  do_map_addition(to, from);
  pop_n_elems(args);
}

void f_summarize_directories(INT32 args)
{
  struct mapping *dir, *file;  

  get_all_args("Ultraparse.summarize_directories", args, "%m%m", &dir, &file);
  summarize_directories(dir, file);
  pop_n_elems(args);
}

void f_page_hits(INT32 args)
{
  struct mapping *urls, *hits, *pages;
  struct multiset *exts;
  INT32 p;
  get_all_args("Ultraparse.page_hits", args, "%m%m%m%M", &urls, &pages, &hits, &exts);
  p = hourly_page_hits(urls, pages, hits, exts, 0);
  pop_n_elems(args);
  push_int(p);
}


void do_map_addition(struct mapping *to, struct mapping *from) {
  struct svalue *sval, *sind;
  INT32 e;
  struct keypair *k;

  MY_MAPPING_LOOP(from, e, k)
  {
    sind = &k->ind;
    sval = &k->val;
    if(sval->type == T_INT) {
      /* printf("%s: %d\n", sind->u.string->str, sval->u.integer);*/
      mapaddintnum(to, sind, sval);
    } else if(sval->type == T_FLOAT) {
      mapaddfloatnum(to, sind, sval);
    } else if(sval->type == T_MAPPING) {
      struct svalue *s;                                                   
      struct svalue mappie;                                           
      s = LML( to, sind);                 
      if( !s ) {
	struct mapping *map;
	map = allocate_mapping(1);
	mappie.type = T_MAPPING;
	mappie.u.mapping = map;
	mapping_insert(to, sind, &mappie);
	do_map_addition(map, sval->u.mapping);
	free_mapping(map);
      } else {
	do_map_addition(s->u.mapping, sval->u.mapping);
      }
    }
  }
}

INLINE void summarize_sessions(INT32 hour,
			       unsigned INT32 *sessions_per_hour,
			       unsigned INT32 *time_per_session,
			       struct mapping *session_start,
			       struct mapping *session_end)
{
  struct svalue *sind;
  struct array *ind;
  struct keypair *k;
  INT32 e, len;
  /*  printf("\nSummarizining (%2d)...\n", hour);*/
  MY_MAPPING_LOOP(session_start, e, k)
  {
    sind = &k->ind;
    sessions_per_hour[hour] ++;
    time_per_session[hour] +=
      (low_mapping_lookup(session_end, sind)->u.integer -
       k->val.u.integer);
    /*    if(!session || session->type != T_OBJECT)
          continue;  Should never happen but just to be safe... 
	  len = G_ENDTIME - G_STARTTIME;
	  time_per_session[hour] += (float)len / 60.0;
    */
  }
  /*  printf("\nok: %ld\n", time_per_session[hour]);*/
}

struct mapping *compress_mapping(struct mapping *map, INT32 maxsize) {
  INT32 i, count = 0, todelete;
  struct array *indices, *values;
  struct svalue *ind, *val;
  struct pike_string *str;
  struct mapping *new = NULL;
  indices = mapping_indices(map);
  values = mapping_values(map);
  ref_push_array(values);
  ref_push_array(indices);
  f_sort(2);
  pop_stack();
  todelete = (indices->size - maxsize);
  /* Allocate a new mapping */
  new = allocate_mapping(indices->size - todelete);
  /* Get the count for the values we don't want */
  for(i = 0; i < todelete; i ++)
    count += (&ITEM(values)[i])->u.integer;
  /* Build the new mappings with the rest */
  for(; i < indices->size; i ++)
    mapping_insert(new, &ITEM(indices)[i], &ITEM(values)[i]);

  /* Add to the "Other" value in the new mapping */
  str = make_shared_binary_string("Other", 5);
  intie.u.integer = count;
  mapaddstrnum(new, str, &intie);  

  free_string(str);
  free_array(indices);
  free_array(values);
  return new;
}

void f_compress_mapping(INT32 args)
{
  struct mapping *map;
  struct mapping *new;
  INT32 maxsize;
  get_all_args("Ultraparse.compress_mapping", args, "%m%d", &map, &maxsize);
  if(maxsize <= 0) maxsize = DEFAULT_MAX_TABLE_SIZE;
  if(m_sizeof(map) < maxsize) {
    add_ref(map);
    pop_n_elems(args);
    push_mapping(map);
    return;
  }
  new = compress_mapping(map, maxsize);
  pop_n_elems(args);
  push_mapping(new);
}


INLINE void process_session(unsigned char *host, INT32 t, INT32 hour, 
			    unsigned INT32 *sessions_per_hour,
			    unsigned INT32 *time_per_session,
			    struct mapping *session_start,
			    struct mapping *session_end,
			    struct mapping *sites)
{
  struct svalue *end, *start;
  struct svalue key;
  INT32 len;
  key.type = T_STRING;
  key.u.string = make_shared_binary_string((char *)host, strlen((char *)host));
  end = LML( session_end, &key );                 
  mapaddsval(sites, &key);
  if(end) {
    /*    if(session->type != T_OBJECT)*/
    /*      return;*/
    if((end->u.integer + SESSION_IDLE) < t)
    {
      start = LML( session_start, &key ); 
      time_per_session[hour] += (end->u.integer - start->u.integer);
      sessions_per_hour[hour]++;
      start->u.integer = t;
    }
    end->u.integer = t;
  } else  {
    /*    get_two_new_ints(t);*/
    intie.u.integer = t;                                                
    mapping_insert(session_start, &key, &intie);
    mapping_insert(session_end, &key, &intie);
    /*    free_svalue(session);*/
  }
  free_string(key.u.string);
}
