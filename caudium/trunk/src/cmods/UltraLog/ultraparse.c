/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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
#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"

#include <stdio.h>
#include <fcntl.h>

#include "ultraparse.h"

/** Forward declarations of functions implementing Pike functions **/

static void f_ultraparse( INT32 args );
extern int fd_from_object(struct object *o);


/* Array to store character types in */
char char_class[1<<CHAR_BIT];

/** Externally available functions **/

/* Initialize and start module */

void pike_module_init( void )
{
  int i;
  MEMSET(char_class, CLS_TOKEN, sizeof(char_class));
  char_class[' '] = CLS_WSPACE;
  char_class['\t'] = CLS_WSPACE;
  for(i='0'; i<='9'; i++)
    char_class[i] = CLS_DIGIT;
  char_class['\n'] = CLS_CRLF;
  char_class['\r'] = CLS_CRLF;
  char_class['\f'] = CLS_CRLF;
  char_class['"'] = CLS_QUOTE;
  char_class['['] = CLS_LBRACK;
  char_class[']'] = CLS_RBRACK;
  char_class['/'] = CLS_SLASH;
  char_class[':'] = CLS_COLON;
  char_class['-'] = CLS_HYPHEN;
  char_class['+'] = CLS_PLUS;
  char_class['?'] = CLS_QUESTION;

  add_function_constant( "ultraparse", f_ultraparse,
			 "function(string,function(int|void,int|void:void),"
			 "function(int,int,int,mapping,mapping,mapping,mapping,"
			 "mapping,mapping,mapping,mapping,mapping,mapping,"
			 "mapping,mapping,mapping,mapping,"
			 "array(int),array(int),array(int),"
			 "array(float),array(float),array(int):void),"
			 "string|object,multiset(string),"
			 "string|void,int|void:int)", OPT_SIDE_EFFECT);
  add_function_constant("addmappings", f_add_mapping,
			"function(mapping,mapping:void)", OPT_SIDE_EFFECT);
  add_function_constant("compress_mapping", f_compress_mapping,
			"function(mapping,int:mapping)", 0);
  add_function_constant("summarize_directories", f_summarize_directories,
			"function(mapping,mapping:void)", 0);
  add_function_constant("page_hits", f_page_hits,
			"function(mapping,mapping,mapping,multiset:int)",
			OPT_SIDE_EFFECT);
  intie.type = T_INT;
  ett.type = T_INT;                                             
  ett.u.integer = 1;                                                
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

#define SKIPP_STATE(x) if(!got_state) { state_list[state_pos] = ST_SKIP_CHAR; save_field_num[state_pos]=-1;} else got_state = 0; state_pos++; field_endings[fieldnum++] = x; 


/* Parse the log format */
INT32 parse_log_format(struct pike_string *log_format, INT32 *state_list,
		       INT32 *field_endings, INT32 *save_field_num)
{
  int i=0,state_pos = 0,  got_state = 0;
  int fieldnum = 0, required_fields=0;
  unsigned char *bufpointer = log_format->str;
  unsigned char *end = log_format->str + log_format->len;
  if(!log_format->len) {
    fprintf(stderr, "Log format null length.\n");
    fflush(stderr);
    return 0;
  }
  MEMSET(state_list, 0, sizeof(state_list));
  MEMSET(field_endings, 0, sizeof(field_endings));
  MEMSET(save_field_num, 0, sizeof(save_field_num));
  while(bufpointer < end) {
    switch(*bufpointer) {
    case '%':
      if(bufpointer >= end - 1) {
	/* No more characters following a %. Invalid. */
	fprintf(stderr, "Short %% spec.\n");
	fflush(stderr);
	return 0;
      } else  if(got_state) {
	/* Currently need some kind of divider after a content state. Invalid to have
	   another state directly trailing */
	fprintf(stderr, "Need separator between fields.\n");
	fflush(stderr);
	return 0;
      }
      got_state = 1;
      switch(*(++bufpointer)) {
      case 'H': /* 	Host/IP */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = ADDR;
	break;
      case 'R': /*	Referrer */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = REFER;
	break;
      case 'U': /*	User Agent */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = AGENT;
	break;
      case 'D': /*	Day of month */
	state_list[state_pos] = ST_DATE;
	save_field_num[state_pos] = DATE;
	break;
      case 'M': /*	Month, as two digit number (01) or three letter english abbr. (Jan etc) */
	state_list[state_pos] = ST_MONTH;
	save_field_num[state_pos] = MONTH;
	break;
      case 'Y': /*	Year, 4 digits (if you use 2 - get Y2K-safe right now!) */
	state_list[state_pos] = ST_YEAR;
	save_field_num[state_pos] = YEAR;
	break;
      case 'h': /*	Hour */
	state_list[state_pos] = ST_HOUR;
	save_field_num[state_pos] = HOUR;
	break;
      case 'm': /*	Minute */
	state_list[state_pos] = ST_MIN;
	save_field_num[state_pos] = MINUTE;
	break;
      case 's': /*	Second */
	state_list[state_pos] = ST_SEC;
	save_field_num[state_pos] = UP_SEC;
	break;
      case 'z': /*	Time zone, [-/+]HHMM, for example -0700 */
	state_list[state_pos] = ST_TZ;
	save_field_num[state_pos] = -3;
	break;
      case 'e': /*	Method (GET, POST etc) */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = METHOD;
	break;
      case 'f': /*	Requested file */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = URL;
	/*	state_list[state_pos] = ST_URL; */
	break;
      case 'u': /*	Auth User (or maybe a unique user cookie) */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = RFC;
	break;
      case 'P': /*	Protocol (HTTP/1.0 etc) */
	state_list[state_pos] = ST_TEXT_FIELD;
	save_field_num[state_pos] = PROTO;
	break;
      case 'c': /*	Return code */
	state_list[state_pos] = ST_CODE;
	save_field_num[state_pos] = CODE;
	break;
      case 'b': /*	Bytes transferred (sent data) */
	state_list[state_pos] = ST_SIZE;
	save_field_num[state_pos] = BYTES;
	break;
      case 'j': /*	Junk. Skipp till end character */
	state_list[state_pos] = ST_SKIP_UNTIL;
	save_field_num[state_pos] = -1;
	break;
      default:
	/* invalid field */
	fprintf(stderr, "Invalid %% field.\n");
	fflush(stderr);
	return 0;
      }
      break;
      
    case '\\':
      if(bufpointer >= end - 1) {
	/* No more characters following a \. Invalid. */
	fprintf(stderr, "Missing code for \\X code.\n");
	fflush(stderr);
	return 0;
      }

      switch(*(++bufpointer)) {
       case 'w':
	SKIPP_STATE(CLS_WSPACE);
	break;
       case 'o': /* All following fields are optional */
	required_fields = state_pos;
	break;
       default:
	fprintf(stderr, "Invalid \\ code.\n");
	fflush(stderr);
	return 0;
      }
      break;
      
    case '"': SKIPP_STATE(CLS_QUOTE);  	break;
    case '[': SKIPP_STATE(CLS_LBRACK);  	break;
    case ']': SKIPP_STATE(CLS_RBRACK);  	break;
    case '/': SKIPP_STATE(CLS_SLASH);  	break;
    case ':': SKIPP_STATE(CLS_COLON);  	break;
    case '-': SKIPP_STATE(CLS_HYPHEN);  	break;
    case '+': SKIPP_STATE(CLS_PLUS);  		break;
    case '?': SKIPP_STATE(CLS_QUESTION);  	break;
    case ' ': SKIPP_STATE(CLS_WSPACE); 	break;
    default:
      fprintf(stderr, "Invalid char [%c:%d].\n", *bufpointer, *bufpointer);
      fflush(stderr);
      return 0;
    }
    bufpointer++;
  }
  SKIPP_STATE(CLS_CRLF);
  /* field_endings[fieldnum++] = CLS_CRLF;  */
#if 0
  for(i = 0; i < state_pos; i ++)
  {
    printf("** state (%d) = %d   %d   %d\n", i, state_list[i], field_endings[i], save_field_num[i]);
  }
  
#endif
  return required_fields || state_pos;
}

/** Functions implementing Pike functions **/

/* CommonLog.read() */

static void f_ultraparse( INT32 args )
{
  FD f = -1;
  int lines=0, cls, c=0, my_fd=1, tzs=0, state=0, next;
  unsigned char *char_pointer=0;
  /* array with offsets for fields in the string buffer */
  int buf_points[16];
  INT32 v=0, offs0=0, len=0, bytes=0, gotdate=0;
  INT32 last_hour=0, last_date=0, last_year=0, last_month=0,
    this_date=0, broken_lines=0, tmpinteger=0, field_position=0;
  time_t start;
  unsigned char *read_buf;
  struct svalue *statfun, *daily, *pagexts=0, *file,  *refsval, *log_format;
  unsigned char *buf, *field_buf;
#ifdef BROKEN_LINE_DEBUG
  INT32 broken_line_pos=0;
  unsigned char *broken_line;
#endif
  INT32 *state_list, *save_field_num, *field_endings, num_states;

  char *notref = 0;
  INT32 state_pos=0, bufpos=0, i, fieldnum=0;
  struct pike_string *url_str = 0,  *ref_str = 0, *rfc_str = 0, *hst_str = 0, *tmpagent = 0;
  struct svalue *url_sval;
  ONERROR unwind_protect;
  unsigned INT32 hits_per_hour[24];
  unsigned INT32 hosts_per_hour[24];
  unsigned INT32 pages_per_hour[24];
  unsigned INT32 sessions_per_hour[24];
  double kb_per_hour[24];
  unsigned INT32 session_length[24];
  /*  struct mapping *unique_per_hour  = allocate_mapping(1);*/
  struct mapping *hits_per_error  = allocate_mapping(10);
  struct mapping *error_urls      = allocate_mapping(10);
  struct mapping *error_refs      = allocate_mapping(10);
  struct mapping *user_agents     = allocate_mapping(10);
  struct mapping *directories     = allocate_mapping(20);
  struct mapping *referrers       = allocate_mapping(1);
  struct mapping *refsites        = allocate_mapping(1);
  struct mapping *referredto      = allocate_mapping(1);
  struct mapping *pages           = allocate_mapping(1);
  struct mapping *hosts           = allocate_mapping(1);
  struct mapping *hits            = allocate_mapping(1);
  struct mapping *session_start   = allocate_mapping(1);
  struct mapping *session_end     = allocate_mapping(1);
  struct mapping *hits20x    	  = allocate_mapping(300);
  struct mapping *hits302    	  = allocate_mapping(2);
  struct mapping *sites    	  = allocate_mapping(1);
  struct mapping *domains    	  = allocate_mapping(1);
  struct mapping *topdomains   	  = allocate_mapping(1);
  struct mapping *tmpdest = NULL;
  /*  struct mapping *hits30x     = allocate_mapping(2);*/
  
  if(args>6 && sp[-1].type == T_INT) {
    offs0 = sp[-1].u.integer;
    pop_n_elems(1);
    --args;
  }
  if(args>5 && sp[-1].type == T_STRING) {
    notref = sp[-1].u.string->str;
    pop_n_elems(1);
    --args;
  }
  lmu = 0;
  get_all_args("UltraLog.ultraparse", args, "%*%*%*%*%*", &log_format, &statfun, &daily, &file,
	       &pagexts);
  if(log_format->type != T_STRING) 
    Pike_error("Bad argument 1 to Ultraparse.ultraparse, expected string.\n");
  if(statfun->type != T_FUNCTION)  
    Pike_error("Bad argument 2 to Ultraparse.ultraparse, expected function.\n");
  if(daily->type != T_FUNCTION)    
    Pike_error("Bad argument 3 to Ultraparse.ultraparse, expected function.\n");
  if(pagexts->type != T_MULTISET)  
    Pike_error("Bad argument 5 to Ultraparse.ultraparse, expected multiset.\n");
  
  if(file->type == T_OBJECT)
  {
    f = fd_from_object(file->u.object);
    
    if(f == -1)
      Pike_error("UltraLog.ultraparse: File is not open.\n");
    my_fd = 0;
  } else if(file->type == T_STRING &&
	    file->u.string->size_shift == 0) {
    do {
      f=fd_open(STR0(file->u.string), fd_RDONLY, 0);
    } while(f < 0 && errno == EINTR);
    
    if(errno < 0)
      Pike_error("UltraLog.ultraparse(): Failed to open file for reading (errno=%d).\n",
	    errno);
  } else 
    Pike_error("Bad argument 4 to UltraLog.ultraparse, expected string or object .\n");

  state_list = malloc((log_format->u.string->len +3) * sizeof(INT32));
  save_field_num = malloc((log_format->u.string->len +3) * sizeof(INT32));
  field_endings = malloc((log_format->u.string->len +3) * sizeof(INT32));

  num_states = parse_log_format(log_format->u.string, state_list, field_endings, save_field_num);
  if(num_states < 1)
  {
    free(state_list);
    free(save_field_num);
    free(field_endings);
    Pike_error("UltraLog.ultraparse(): Failed to parse log format.\n");
  }
  
  fd_lseek(f, offs0, SEEK_SET);
  read_buf = malloc(READ_BLOCK_SIZE+1);
  buf = malloc(MAX_LINE_LEN+2);
#ifdef BROKEN_LINE_DEBUG
  broken_line = malloc(MAX_LINE_LEN*10);
#endif
  MEMSET(hits_per_hour, 0, sizeof(hits_per_hour));
  MEMSET(hosts_per_hour, 0, sizeof(hosts_per_hour));
  MEMSET(session_length, 0, sizeof(session_length));
  MEMSET(pages_per_hour, 0, sizeof(pages_per_hour));
  MEMSET(sessions_per_hour, 0, sizeof(sessions_per_hour));
  MEMSET(kb_per_hour, 0, sizeof(kb_per_hour));

  /*url_sval.u.type = TYPE_STRING;*/
  BUFSET(0);
  field_position = bufpos;
  buf_points[0] = buf_points[1] = buf_points[2] = buf_points[3] = 
    buf_points[4] = buf_points[5] = buf_points[6] = buf_points[7] = 
    buf_points[8] = buf_points[9] = buf_points[10] = buf_points[11] = 
    buf_points[12] = buf_points[13] = buf_points[14] = buf_points[15] = 0;
  while(1) {
    /*    THREADS_ALLOW();*/
    do {
      len = fd_read(f, read_buf, READ_BLOCK_SIZE);
    } while(len < 0 && errno == EINTR);
    /*    THREADS_DISALLOW();*/
    if(len <= 0)  break; /* nothing more to read or error. */
    offs0 += len;
    char_pointer = read_buf+len - 1;
    while(len--) {
      c = char_pointer[-len]; 
      cls = char_class[c];
#if 0
      fprintf(stdout, "DFA(%d:%d): '%c' (%d) ", state, state_pos, c, (int)c);
      switch(cls) {
       case CLS_WSPACE: fprintf(stdout, "CLS_WSPACE\n"); break;
       case CLS_CRLF: fprintf(stdout, "CLS_CRLF\n"); break;
       case CLS_TOKEN: fprintf(stdout, "CLS_TOKEN\n"); break;
       case CLS_DIGIT: fprintf(stdout, "CLS_DIGIT\n"); break;
       case CLS_QUOTE: fprintf(stdout, "CLS_QUOTE\n"); break;
       case CLS_LBRACK: fprintf(stdout, "CLS_LBRACK\n"); break;
       case CLS_RBRACK: fprintf(stdout, "CLS_RBRACK\n"); break;
       case CLS_SLASH: fprintf(stdout, "CLS_SLASH\n"); break;
       case CLS_COLON: fprintf(stdout, "CLS_COLON\n"); break;
       case CLS_HYPHEN: fprintf(stdout, "CLS_HYPHEN/CLS_MINUS\n"); break;
       case CLS_PLUS: fprintf(stdout, "CLS_PLUS\n"); break;
       default: fprintf(stdout, "??? %d ???\n", cls);
      }
#endif
#ifdef BROKEN_LINE_DEBUG
      broken_line[broken_line_pos++] = c;
#endif
      if(cls == field_endings[state_pos]) {
	/* Field is done. Nullify. */
      process_field:
	/*	printf("Processing field %d of %d\n", state_pos, num_states);*/
	switch(save_field_num[state_pos]) {
	 case DATE:
	 case HOUR:
	 case MINUTE:
	 case UP_SEC:
	 case CODE:
	   /*	  BUFSET(0);*/
	  tmpinteger = 0;
	  for(v = field_position; v < bufpos; v++) {
	    if(char_class[buf[v]] == CLS_DIGIT)
	      tmpinteger = tmpinteger*10 + (buf[v]&0xf);
	    else {
	      goto skip;
	      
	    }
	  }
	  BUFPOINT = tmpinteger;
	  break;
	  
	 case YEAR:
	  tmpinteger = 0;
	  for(v = field_position; v < bufpos; v++) {
	    if(char_class[buf[v]] == CLS_DIGIT)
	      tmpinteger = tmpinteger*10 + (buf[v]&0xf);
	    else {
	      goto skip;
	    }
	  }
	  if(tmpinteger < 100) {
	    if(tmpinteger < 60)
	      tmpinteger += 2000;
	    else
	      tmpinteger += 1900;
	  }
	  BUFPOINT = tmpinteger;	  
	  break;

	 case BYTES:
	  v = field_position;
	  switch(char_class[buf[v++]]) {
	   case CLS_QUESTION:
	   case CLS_HYPHEN:
	    if(v == bufpos)
	      tmpinteger = 0;
	    else {
	      goto skip;
	    }
	    break;
	   case CLS_DIGIT:
	    tmpinteger = (buf[field_position]&0xf);
	    for(; v < bufpos; v++) {
	      if(char_class[buf[v]] == CLS_DIGIT)
		tmpinteger = tmpinteger*10 + (buf[v]&0xf);
	      else {
		goto skip;
	      }		
	    }
	    /*	    printf("Digit: %d\n", tmpinteger);*/
	    break;
	   default:
	    goto skip;
	  }
	  BUFPOINT = tmpinteger;
	  /*	  bufpos++;*/
	  break;	  
	 case MONTH:
	  /* Month */
	  /*	  BUFSET(0);*/
	  /*	  field_buf = buf + field_positions[state_pos];*/
	  switch(bufpos - field_position)
	  {
	   case 2:
	    tmpinteger = 0;
	    for(v = field_position; v < bufpos; v++) {
	      if(char_class[buf[v]] == CLS_DIGIT)
		tmpinteger = tmpinteger*10 + (buf[v]&0xf);
	      else {
		goto skip;
	      }
	    }
	    break;

	   case 3:
	    switch(((buf[field_position]|0x20)<<16)|((buf[field_position+1]|0x20)<<8)|
		   (buf[field_position+2]|0x20))
	    {
	     case ('j'<<16)|('a'<<8)|'n': tmpinteger = 1;   break;
	     case ('f'<<16)|('e'<<8)|'b': tmpinteger = 2;   break;
	     case ('m'<<16)|('a'<<8)|'r': tmpinteger = 3;   break;
	     case ('a'<<16)|('p'<<8)|'r': tmpinteger = 4;   break;
	     case ('m'<<16)|('a'<<8)|'y': tmpinteger = 5;   break;
	     case ('j'<<16)|('u'<<8)|'n': tmpinteger = 6;   break;
	     case ('j'<<16)|('u'<<8)|'l': tmpinteger = 7;   break;
	     case ('a'<<16)|('u'<<8)|'g': tmpinteger = 8;   break;
	     case ('s'<<16)|('e'<<8)|'p': tmpinteger = 9;   break;
	     case ('o'<<16)|('c'<<8)|'t': tmpinteger = 10;  break;
	     case ('n'<<16)|('o'<<8)|'v': tmpinteger = 11;  break;
	     case ('d'<<16)|('e'<<8)|'c': tmpinteger = 12;  break;
	    }
	    break;

	   default:
	    goto skip;
	  }
	  /*printf("Month: %0d\n", mm);*/

	  if(tmpinteger < 1 || tmpinteger > 12)
	    goto skip; /* Broken Month */
	  BUFPOINT = tmpinteger;
	  /*	  bufpos++;*/
	  break;
	  
	 case ADDR:
	 case REFER:
	 case AGENT:
	 case TZ:
	 case METHOD:
	 case URL:
	 case RFC:
	 case PROTO:
	  BUFSET(0);
	  SETPOINT();
	  /*	  printf("Field %d, pos %d, %s\n", save_field_num[state_pos],BUFPOINT,*/
	  /*		 buf + BUFPOINT);	 */
	  break;
	  
	}	  
	state_pos++;
	field_position = bufpos;
	if(cls != CLS_CRLF)		  
	  continue;
      } else if(cls != CLS_CRLF) {
	BUFSET(c);
	continue;
      } else {
	/*	printf("Processing last field (%d).\n", state_pos);*/
	goto process_field; /* End of line - process what we got */
      }
      /*	printf("%d %d\n", state_pos, num_states);*/
      /*      buf_points[8] = buf_points[9] = buf_points[10] = buf_points[11] = buf;*/
      /*      buf_points[12] = buf_points[13] = buf_points[14] = buf_points[15] = buf;*/
#if 0
      if(!((lines+broken_lines)%100000)) {
	push_int(lines+broken_lines);
	push_int((int)((float)offs0/1024.0/1024.0));
	apply_svalue(statfun, 2);
	pop_stack();
	/*printf("%5dk lines, %5d MB\n", lines/1000, (int)((float)offs0/1024.0/1024.0));*/
      }
#endif
      if(state_pos < num_states)
      {
#ifdef BROKEN_LINE_DEBUG
	broken_line[broken_line_pos] = 0;
	printf("too few states (pos=%d): %s\n", state_pos, broken_line);
#endif
	broken_lines++;
	goto ok;
      }
      
#define yy 	buf_points[YEAR] 
#define mm 	buf_points[MONTH] 
#define dd 	buf_points[DATE] 
#define h  	buf_points[HOUR] 
#define m  	buf_points[MINUTE] 
#define s  	buf_points[UP_SEC] 
#define v  	buf_points[CODE] 
#define bytes	buf_points[BYTES] 

      this_date = (yy*10000) + (mm*100) + dd;
      if(!this_date) {
	broken_lines++;
	goto ok;
      }
#if 1
      if(!last_date) { /* First loop w/o a value.*/
	last_date = this_date;
	last_hour = h;
      } else {
	if(last_hour != h ||
	   last_date != this_date)
	{
	  pages_per_hour[last_hour] +=
	    hourly_page_hits(hits20x, pages, hits, pagexts->u.multiset, 200);
	  /*	    pages_per_hour[last_hour] +=*/
	  /*	      hourly_page_hits(hits304, pages, hits, pagexts->u.multiset, 300);*/
	  
	  /*	    printf("%5d %5d for %d %02d:00\n",*/
	  /*		   pages_per_hour[last_hour], hits_per_hour[last_hour],*/
	  /*last_date, last_hour);*/
	  if(m_sizeof(session_start)) {
	    summarize_sessions(last_hour, sessions_per_hour,
			       session_length, session_start, session_end);
	    free_mapping(session_start); 
	    free_mapping(session_end); 
	    session_start = allocate_mapping(1);
	    session_end   = allocate_mapping(1);
	  }
	  hosts_per_hour[last_hour] += m_sizeof(sites);
	  do_map_addition(hosts, sites);
	  free_mapping(sites);
	  sites = allocate_mapping(100);
	  last_hour = h;
	  free_mapping(hits20x); /* Reset this one */
	  /*	    free_mapping(hits304);  Reset this one */
	  /*	    hits304   = allocate_mapping(2);*/
	  hits20x   = allocate_mapping(2);
	}
#if 1
	if(last_date != this_date) {
	  /*	  printf("%d   %d\n", last_date, this_date);*/
	  tmpdest = allocate_mapping(1);
	  summarize_refsites(refsites, referrers, tmpdest);
	  free_mapping(referrers);
	  referrers = tmpdest;

	  tmpdest = allocate_mapping(1);
	  clean_refto(referredto, tmpdest, pagexts->u.multiset);
	  free_mapping(referredto);
	  referredto = tmpdest;
	  
	  summarize_directories(directories, pages);
	  summarize_directories(directories, hits);

	  tmpdest = allocate_mapping(1);
	  http_decode_mapping(user_agents, tmpdest);
	  free_mapping(user_agents);
	  user_agents = tmpdest;

	  tmpdest = allocate_mapping(1);
	  summarize_hosts(hosts, domains, topdomains, tmpdest);
	  free_mapping(hosts);
	  hosts = tmpdest;
#if 1
	  push_int(last_date / 10000);
	  push_int((last_date % 10000)/100);
	  push_int((last_date % 10000)%100);
	  push_mapping(pages);
	  push_mapping(hits);
	  push_mapping(hits302);
	  push_mapping(hits_per_error);
	  push_mapping(error_urls);
	  push_mapping(error_refs);
	  push_mapping(referredto);
	  push_mapping(refsites); 
	  push_mapping(referrers); 
	  push_mapping(directories); 
	  push_mapping(user_agents); 
	  push_mapping(hosts); 
	  push_mapping(domains); 
	  push_mapping(topdomains); 
	  for(i = 0; i < 24; i++) {
	    push_int(sessions_per_hour[i]);
	  }
	  f_aggregate(24);
	  for(i = 0; i < 24; i++) {
	    push_int(hits_per_hour[i]);
	    hits_per_hour[i] = 0;
	  }
	  f_aggregate(24);
	  for(i = 0; i < 24; i++) {
	    push_int(pages_per_hour[i]);
	    pages_per_hour[i] = 0;
	  }
	  f_aggregate(24);
	  for(i = 0; i < 24; i++) {
	    /* KB per hour.*/
	    push_float(kb_per_hour[i]);
	    kb_per_hour[i] = 0.0;
	  }
	  f_aggregate(24);
	  for(i = 0; i < 24; i++) {
	    push_float(sessions_per_hour[i] ?
		       ((float)session_length[i] /
			(float)sessions_per_hour[i]) / 60.0 : 0.0);
	    sessions_per_hour[i] = 0;
	    session_length[i] = 0;
	  }
	  f_aggregate(24);
	  for(i = 0; i < 24; i++) {
	    push_int(hosts_per_hour[i]);
	    hosts_per_hour[i] = 0;
	  }
	  f_aggregate(24);
	  apply_svalue(daily, 23);
	  pop_stack();
#else
	  free_mapping(error_refs);
	  free_mapping(referredto); 
	  free_mapping(refsites); 
	  free_mapping(directories); 
	  free_mapping(error_urls);
	  free_mapping(hits);
	  free_mapping(hits_per_error);
	  free_mapping(pages);
	  free_mapping(hosts);
	  free_mapping(domains);
	  free_mapping(topdomains);
	  free_mapping(referrers); 
	  free_mapping(hits302);
#endif
	  user_agents 	 = allocate_mapping(10);
	  hits302 	 = allocate_mapping(1);
	  hits_per_error = allocate_mapping(10);
	  error_urls     = allocate_mapping(10);
	  error_refs     = allocate_mapping(10);
	  directories    = allocate_mapping(20);
	  referrers      = allocate_mapping(1);
	  referredto     = allocate_mapping(1);
	  refsites       = allocate_mapping(1);
	  pages  	 = allocate_mapping(1);
	  hits 	         = allocate_mapping(1);
	  sites	         = allocate_mapping(1);
	  hosts	         = allocate_mapping(1);
	  domains	 = allocate_mapping(1);
	  topdomains     = allocate_mapping(1);
	  last_date = this_date;
	}
#endif
      }
#endif
#if 1
      process_session(buf+buf_points[ADDR], h*3600+m*60+s, h, 
		      sessions_per_hour, session_length, session_start,
		      session_end, sites);
      url_str = make_shared_binary_string(buf + buf_points[URL], strlen(buf + buf_points[URL]));
#if 1
      switch(v) {
      /* Do error-code specific logging. Error urls that are
	   specially treated do not include auth required, service
	   unavailable etc. They are only included in the return
	   code summary.
	*/
       case 200: case 201: case 202: case 203: 
       case 204: case 205: case 206: case 207:
       case 304:
	mapaddstr(hits20x, url_str);
	DO_REFERRER();
	break;

       case 300: case 301: case 302:
       case 303: case 305:
	mapaddstr(hits302, url_str);
	DO_REFERRER();
	break;

       case 400: case 404: case 405: case 406: case 408:
       case 409: case 410: case 411: case 412: case 413:
       case 414: case 415: case 416: case 500: case 501:
	DO_ERREF();
	map2addint(error_urls, v, url_str);
	break;
      }
      /*rfc_str = http_decode_string(buf + buf_points[RFC]);*/
      /*hst_str = make_shared_binary_string(buf, strlen(buf));*/
#endif	
      free_string(url_str);
      mapaddint(hits_per_error, v);
      kb_per_hour[h] += (float)bytes / 1024.0;
      hits_per_hour[h]++;
      /*#endif*/
      if(strlen(buf + buf_points[AGENT])>1) {
	/* Got User Agent */
	tmpagent = make_shared_string(buf + buf_points[AGENT]);
	mapaddstr(user_agents, tmpagent);
	free_string(tmpagent);
      }
#endif
      lines++;
#if 0
      printf("%s  %s  %s\n%s  %s  %s\n%04d-%02d-%02d  %02d:%02d:%02d  \n%d   %d\n",
	     buf + buf_points[ADDR], buf + buf_points[REFER], buf + buf_points[ RFC ],
	     buf + buf_points[METHOD], buf + buf_points[ URL ], buf + buf_points[PROTO],
	     yy, mm, dd, h, m, s, v, bytes);
      /*      if(lines > 10)
	      exit(0);*/
#endif
    ok:
      gotdate = /* v = bytes =h = m = s = tz = tzs = dd = mm = yy =  */
	buf_points[0] = buf_points[1] = buf_points[2] = buf_points[3] = 
	buf_points[4] = buf_points[5] = buf_points[6] = buf_points[7] = 
	/*buf_points[8] = buf_points[9] = buf_points[10] =*/
	buf_points[11] = 
	buf_points[12] = buf_points[13] = buf_points[14] = buf_points[15] = 
	bufpos = state_pos = 0;
      field_position = 1;
#ifdef BROKEN_LINE_DEBUG
      broken_line_pos = 0;
#endif
      BUFSET(0);
      
    }    
  }  
 cleanup:
  free(save_field_num);
  free(state_list);
  free(field_endings);
  free(buf);
  push_int(lines);
  push_int((int)((float)offs0 / 1024.0/1024.0));
  push_int(1);
  apply_svalue(statfun, 3);
  pop_stack();
  free(read_buf);
#ifdef BROKEN_LINE_DEBUG
  free(broken_line);
#endif
  if(my_fd)
    /* If my_fd == 0, the second argument was an object and thus we don't
     * want to free it.
     */
    fd_close(f);
  /*  push_int(offs0);  */
  /*  printf("Done: %d %d %d ", yy, mm, dd);*/
  if(yy && mm && dd) { 
    /*    printf("\nLast Summary for %d-%02d-%02d %02d:%02d\n", yy, mm, dd, h, m);*/
    pages_per_hour[last_hour] += 
      hourly_page_hits(hits20x, pages, hits, pagexts->u.multiset, 200);
    if(m_sizeof(session_start)) {
      summarize_sessions(last_hour, sessions_per_hour,
			 session_length, session_start, session_end);
    }
    hosts_per_hour[last_hour] += m_sizeof(sites);
    do_map_addition(hosts, sites);
    free_mapping(sites);
	  
    tmpdest = allocate_mapping(1);
    summarize_refsites(refsites, referrers, tmpdest);
    free_mapping(referrers);
    referrers = tmpdest;
    summarize_directories(directories, pages);
    summarize_directories(directories, hits);
    tmpdest = allocate_mapping(1);
    clean_refto(referredto, tmpdest, pagexts->u.multiset);
    free_mapping(referredto);
    referredto = tmpdest;

    tmpdest = allocate_mapping(1);
    http_decode_mapping(user_agents, tmpdest);
    free_mapping(user_agents);
    user_agents = tmpdest;

    tmpdest = allocate_mapping(1);
    summarize_hosts(hosts, domains, topdomains, tmpdest);
    free_mapping(hosts);
    hosts = tmpdest;

    push_int(yy);
    push_int(mm);
    push_int(dd);
    push_mapping(pages);
    push_mapping(hits);
    push_mapping(hits302);
    push_mapping(hits_per_error);
    push_mapping(error_urls);
    push_mapping(error_refs);
    push_mapping(referredto); 
    push_mapping(refsites); 
    push_mapping(referrers); 
    push_mapping(directories); 
    push_mapping(user_agents); 
    push_mapping(hosts); 
    push_mapping(domains); 
    push_mapping(topdomains); 

    for(i = 0; i < 24; i++) {  push_int(sessions_per_hour[i]);  }
    f_aggregate(24);

    for(i = 0; i < 24; i++) {  push_int(hits_per_hour[i]);      }
    f_aggregate(24);

    for(i = 0; i < 24; i++) {  push_int(pages_per_hour[i]);     }
    f_aggregate(24);
    
    for(i = 0; i < 24; i++) {  push_float(kb_per_hour[i]);      }
    f_aggregate(24);

    for(i = 0; i < 24; i++) {
      push_float(sessions_per_hour[i] ?
		 ((float)session_length[i] /
		  (float)sessions_per_hour[i]) / 60.0 : 0.0);
    }
    f_aggregate(24);

    for(i = 0; i < 24; i++) {
      push_int(hosts_per_hour[i]);
      hosts_per_hour[i] = 0;
    }
    f_aggregate(24);

    apply_svalue(daily, 23);
    pop_stack();
  } else {
    free_mapping(error_refs);
    free_mapping(referredto); 
    free_mapping(refsites); 
    free_mapping(directories); 
    free_mapping(error_urls);
    free_mapping(hits);
    free_mapping(hits_per_error);
    free_mapping(pages);
    free_mapping(referrers); 
    free_mapping(hits302); 
    free_mapping(user_agents); 
    free_mapping(hosts);
    free_mapping(domains);
    free_mapping(topdomains);
  }
  free_mapping(hits20x); 
  free_mapping(session_start); 
  free_mapping(session_end); 
  /*  free_mapping(hits30x); */
  printf("\nTotal lines: %d, broken lines: %d, mapping lookups: %d\n\n", lines,
	 broken_lines, lmu);
  fflush(stdout);
  pop_n_elems(args);  
  push_int(offs0);
  return; 
      
 skip:
  broken_lines++;
  while(1) 
  {
    while(len--) {
#ifdef BROKEN_LINE_DEBUG
      broken_line[broken_line_pos] = char_pointer[-len];
#endif
      if(char_class[char_pointer[-len]] == CLS_CRLF) {
#ifdef BROKEN_LINE_DEBUG
	broken_line[broken_line_pos] = 0;
	printf("Broken Line (pos=%d): %s\n", state_pos, broken_line);
#endif
	goto ok;
      }
    }
    do {
      len = fd_read(f, read_buf, READ_BLOCK_SIZE);
    } while(len < 0 && errno == EINTR);
    if(len <= 0)
      break; /* nothing more to read. */
    offs0 += len;
    char_pointer = read_buf+len - 1;
  }
  goto cleanup;
}

  
