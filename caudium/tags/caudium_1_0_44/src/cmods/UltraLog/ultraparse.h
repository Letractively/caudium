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

/* $Id$ */

#ifndef ULTRA_LOGDEF
#define ULTRA_LOGDEF

#ifndef MIN
#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#endif
#ifndef MAX
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#endif

/* states */

#define ST_DATE 	0
#define ST_MONTH 	1
#define ST_YEAR         2
#define ST_HOUR         3
#define ST_MIN 	        4
#define ST_SEC 	        5
#define ST_TZ 	        6 
#define ST_URL 	        7
#define ST_CODE         8
#define ST_SIZE         9
#define ST_SKIP_CHAR   10
#define ST_TEXT_FIELD  11
#define ST_SKIP_UNTIL  12
extern INT32 lmu;

/** Global tables **/
#ifndef CHAR_BIT
#define CHAR_BIT	9	/* Should be safe for most hardware */
#endif /* !CHAR_BIT */

/* How much to read each round in the loop. */
#define READ_BLOCK_SIZE 4096

/* Different log file tokens */
#define CLS_WSPACE 0
#define CLS_CRLF   1
#define CLS_TOKEN  2
#define CLS_DIGIT  3
#define CLS_QUOTE  4
#define CLS_LBRACK 5
#define CLS_RBRACK 6
#define CLS_SLASH  7
#define CLS_COLON  8
#define CLS_HYPHEN 9
#define CLS_MINUS  9
#define CLS_PLUS   10
#define CLS_QUESTION 11
#define CLS_OTHER  12

/* Parsed "location" in the string buffer */
#define ADDR	0
#define REFER	1
#define AGENT   2
#define TZ	3
#define METHOD  4 
#define URL     5 
#define RFC     6 
#define PROTO	7 

#define DATE    8
#define MONTH	9
#define YEAR	10
#define HOUR	11
#define MINUTE	12
#define UP_SEC	13
#define CODE	14
#define BYTES	15
 
#define BUFPOINT (buf_points[ save_field_num[state_pos] ])
#define SETPOINT() BUFPOINT = field_position
#define ADDLENGTH() buf_length[ save_field_num[state_pos] ] ++;

struct two_ints
{
  INT32 start;
  INT32 end;
};
              
#define TI(X) ((struct two_ints *)(X->storage))
              
/* Get new dual object */
#define get_two_new_ints(X) { struct svalue sval; sval.type = T_OBJECT; \
  sval.u.object = low_clone( two_integers ); TI(sval.u.object)->start = X;  \
  TI(sval.u.object)->end = X; session = &sval; }            


/* Session array */

/*#define SESS(X,Y) (session->item[X].u.Y)*/
/*#define G_ENDTIME	SESS(0,integer)*/
/*#define G_STARTTIME	SESS(1,integer)*/
#define SESS(X) (TI(session->u.object)->X)
#define G_ENDTIME	SESS(end)
#define G_STARTTIME	SESS(start)

/*
  #define SESS_SET(X,Y) 	array_set_index(session, X, Y)
  #define SSESS_SET(X,Y)  { strval.type = T_STRING; strval.u.string = Y; SESS_SET(X, &strval); }
  #define ISESS_SET(X,Y)  { intval.type = T_INT; intval.u.integer = Y; SESS_SET(X, &intval); }
  #define S_ENDTIME(X)	ISESS_SET(0, X)
  #define S_STARTTIME(X)	ISESS_SET(1, X)
*/
#define SESS_SET(X,Y)  (TI(session->u.object)->X=Y)
#define S_ENDTIME(X)	SESS_SET(end, X)
#define S_STARTTIME(X)	SESS_SET(start, X)

#define SESSION_IDLE	600 /* 20 minutes */

/* Define this and all lines that are considered broken will be printed to stdout */

/* #define BROKEN_LINE_DEBUG  */

/* Maximum length of an individual log entry. If the line is longer
 * than this, it's classified as broken and will be thrown away.
 * 2 KB should be plenty unless long query strings (or referrers) are
 * logged. If you get a lot of broken lines, try increasing this
 * value. Please note that only the following fields are put in this
 * buffer: Host, referrer, rcf (field #3), url, method and protocol.
 * The rest of the fields are integers.
 */

#define MAX_LINE_LEN 2048

/* Set a character in the line buffer */
#define RISKY_BUSINESS
#ifdef  RISKY_BUSINESS
/*#define BUFSET(X) if(save_field_num[state_pos]>-1){buf[bufpos] = X; if(bufpos == MAX_LINE_LEN)   goto skip;  bufpos++;}*/
#define BUFSET(X) buf[bufpos] = X; if(bufpos == MAX_LINE_LEN)   goto skip;  bufpos++
#else
#define BUFSET(X)  { \
  if(bufpos >= MAX_LINE_LEN) { \
/* state = ST_SKIP;  This means the line is too long */\
    goto skip;\
  } buf[bufpos++] = X; \
}
#endif

/* Limit tables to this size */
#define DEFAULT_MAX_TABLE_SIZE 50000

/* Exported utility functions */

void f_add_mapping(INT32 args); 
void f_summarize_directories(INT32 args);
void f_page_hits(INT32 args);
void f_compress_mapping(INT32 args);

/* utility function declarations */
 void do_map_addition(struct mapping *to, struct mapping *from);

 void mapaddstr( struct mapping * mappingen, struct pike_string *key);
 void mapaddint( struct mapping * mappingen, int key);
 void map2addint( struct mapping * mappingen, int subkey,
			struct pike_string *key);
 void map2addstr( struct mapping * mappingen,
			struct pike_string *skey,
			struct pike_string *key);
 void mapaddstrint( struct mapping * mappingen, struct pike_string *key,
			  int subkey);
void summarize_hosts(struct mapping *hosts, struct mapping *domains,
		     struct mapping *topdomains, struct mapping *newhosts);
void summarize_directories(struct mapping *dirs, struct mapping *files);
void summarize_refsites(struct mapping *refsites, struct mapping *referrers,
			struct mapping *new_referrers);
INLINE struct pike_string *http_decode_string(unsigned char *foo, int len);
INLINE int ultra_lowercase(unsigned char *str, INT32 len);
INLINE unsigned char *ultra_lowercase_host(unsigned char *ref, INT32 *trunc,
					   int *changed);
INLINE void mapaddintnum( struct mapping * mappingen, struct svalue *key, struct svalue *count);
INLINE void mapaddsval( struct mapping * mappingen, struct svalue *key);
INLINE void mapaddfloatnum( struct mapping * mappingen, struct svalue *key, struct svalue *count);
INLINE void mapaddstrnum(struct mapping * mappingen, struct pike_string *key,
			 struct svalue *count);
INLINE void mapaddstrmap(struct mapping * mappingen, struct pike_string *key,
			 struct mapping *map);
INLINE void map2addint( struct mapping * mappingen, int subkey, struct pike_string *key);
INLINE int multiset_string_lookup(struct multiset *multi, char *str);
INLINE int ispage(struct pike_string *url, struct multiset *pagexts);
void pike_module_init( void );
void pike_module_exit( void );
INT32 parse_log_format(struct pike_string *log_format, INT32 *state_list,
		       INT32 *field_endings, INT32 *save_field_num);
INLINE void map2addstrnum( struct mapping * mappingen,
			   struct pike_string *key,
			   struct pike_string *key2,
			   struct svalue *value);
#define GETMAP(X,Y)  \
    intie.u.integer = code; \
    sval = my_low_mapping_lookup(Y,&intie); if(!sval) { \
    struct mapping *map = allocate_mapping(1); \
    static struct svalue mappie;                                            \
    mappie.type = T_MAPPING; \
    mappie.u.mapping = map; \
    mapping_insert(Y, &intie, &mappie); \
    X=map; free_mapping(map); } else X=sval->u.mapping; 

INT32 hourly_page_hits(struct mapping *urls,
		     struct mapping *pages,
		     struct mapping *hits,
		     struct multiset *pagexts,
		     INT32 code);



#define DO_REFERRER()  \
 if((tmpinteger = strlen(field_buf = (char *)(buf + buf_points[REFER]))) > 1 &&  \
    (!notref || !strstr(field_buf, notref))) { \
    ref_str = make_shared_binary_string(field_buf, tmpinteger); \
    map2addstr(referredto, url_str, ref_str); \
    mapaddstr(referrers, ref_str); \
    free_string(ref_str); \
    ref_str = 0; \
  } 

#define DO_ERREF()  \
 if(strlen(field_buf = (char *)(buf + buf_points[REFER])) > 1) { \
    ref_str = make_shared_binary_string(field_buf, \
					strlen(field_buf)); \
    map2addstr(error_refs, url_str, ref_str);\
    free_string(ref_str); \
    ref_str = 0; \
  } 


extern struct program *two_integers;
extern struct svalue intie;                                           
extern struct svalue ett;

struct mapping *compress_mapping(struct mapping *map, INT32 maxsize);
INLINE void clean_refto(struct mapping *refto, struct mapping *refdest, struct multiset *pagexts);
INLINE void summarize_sessions(INT32 hour,
			       unsigned INT32 *sessions_per_hour,
			       unsigned INT32 *time_per_session,
			       struct mapping *session_start,
			       struct mapping *session_end);

 void process_session(unsigned char *host, INT32 t, INT32 hour, 
			    unsigned INT32 *sessions_per_hour,
			    unsigned INT32 *time_per_session,
			    struct mapping *session_start,
			    struct mapping *session_end,
			    struct mapping *sites);
void http_decode_mapping(struct mapping *source,
			 struct mapping *dest);

#ifdef NEW_MAPPING_LOOP
/* Pike 7.x and newer */
#define ULTRA_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->data->hashsize; COUNT++ ) \
	for(KEY=md->data->hash[COUNT];KEY;KEY=KEY->next)
#else
/* Pike 0.6 */
#define ULTRA_MAPPING_LOOP(md, COUNT, KEY) \
  for(COUNT=0;COUNT < md->hashsize; COUNT++ ) \
	for(KEY=md->hash[COUNT];KEY;KEY=KEY->next)
#endif
#endif



 
 
