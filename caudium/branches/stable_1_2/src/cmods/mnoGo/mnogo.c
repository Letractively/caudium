/*
 * Pike Extension Modules - A collection of modules for the Pike Language
 * Copyright © 2000, 2001, 2002 The Caudium Group
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
 * Glue for the mnoGo search engine
 *
 * $Id$
 */

#include "global.h"
RCSID("$Id$");

#include "caudium_util.h"
#include "mnogo_config.h"

#if HAVE_MNOGOSEARCH
#include "mnogo.h"

static struct program *mnogo_result_program;

static void free_mnogo_storage(struct object *o) { 
  if(AGENT != NULL) {
    UdmFreeEnv(AGENT->Conf);
    UdmFreeAgent(AGENT);
  }
}

static void free_mnogo_result_storage(struct object *o) {
  if(RESOBJ != NULL) {
    UdmFreeResult(RESOBJ);
  }
}

static void init_mnogo_storage(struct object *o) { 
  AGENT = NULL;
}

static void init_mnogo_result_storage(struct object *o) {
  RESOBJ = NULL;
  RES->current_row = 0;
}


MNOGO_API(create)
{
  UDM_ENV *Env;
  char *dbaddr, *dbmode;

  switch(args) {
  case 1: 
    Env = UdmAllocEnv();
    if(ARG(1).type != PIKE_T_STRING) {
      SIMPLE_BAD_ARG_ERROR("create", 1, "string");
    }
    UdmEnvSetDBAddr(Env, ARG(1).u.string->str);
    
    AGENT = UdmAllocAgent(Env, 0, UDM_OPEN_MODE_READ);
    break;
			
  default:
    Env = UdmAllocEnv();				
    if(ARG(1).type != PIKE_T_STRING) {
      SIMPLE_BAD_ARG_ERROR("create", 1, "string");
    }
    if(ARG(2).type != PIKE_T_STRING) {
      SIMPLE_BAD_ARG_ERROR("create", 2, "string");
    }
    UdmEnvSetDBAddr(Env, ARG(1).u.string->str);
    UdmEnvSetDBMode(Env, ARG(2).u.string->str);				
    AGENT = UdmAllocAgent(Env, 0, UDM_OPEN_MODE_READ);
    break;
			
  case 0:
    SIMPLE_TOO_FEW_ARGS_ERROR("create", 2);
    break;
  }
  RETURN_TRUE;
}

#define TYPE_ERROR(x) Pike_error("set_agent_param: Parameter value type invalid, expected %s.\n", x);
#define INT(var) if(valtype != PIKE_T_INT) { TYPE_ERROR("int"); } else { var = ARG(2).u.integer; }
#define STR() if(valtype != PIKE_T_STRING) { TYPE_ERROR("string"); } 

MNOGO_API(set_param)
{
  int valtype;
  int tmp;
  if(args >= 2) {
    if(ARG(1).type != PIKE_T_INT) {
      SIMPLE_BAD_ARG_ERROR("set_param", 1, "int");
    }
    valtype = ARG(2).type;
    if(valtype != PIKE_T_STRING && valtype != PIKE_T_INT)
      SIMPLE_BAD_ARG_ERROR("set_param", 2, "string|int");
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("set_param", 2);
  }
	
  switch(ARG(1).u.integer){
  case UDM_PARAM_PAGE_SIZE:
    INT(AGENT->page_size);
    if(AGENT->page_size < 1)  AGENT->page_size = 20;
    break;
    
  case UDM_PARAM_PAGE_NUM: 
    INT(AGENT->page_number);
    if(AGENT->page_number < 0) AGENT->page_number = 0;
    break;
			
  case UDM_PARAM_SEARCH_MODE:
    INT(tmp);
    switch (tmp) {
    case UDM_MODE_ALL:
      AGENT->search_mode = UDM_MODE_ALL;
      break;
						
    case UDM_MODE_ANY:
      AGENT->search_mode = UDM_MODE_ANY;
      break;
						
    case UDM_MODE_BOOL: 
      AGENT->search_mode = UDM_MODE_BOOL;
      break;

    case UDM_MODE_PHRASE: 
      AGENT->search_mode = UDM_MODE_PHRASE;
      break;
						
    default:
      Pike_error("set_param: Unknown search mode.\n");
    }
			
    break;

  case UDM_PARAM_WORD_MATCH:
    INT(tmp);
    switch (tmp){
    case UDM_MATCH_WORD:
      AGENT->word_match = UDM_MATCH_WORD;
      break; 

    case UDM_MATCH_BEGIN:
      AGENT->word_match = UDM_MATCH_BEGIN;
      break;

    case UDM_MATCH_END:
      AGENT->word_match = UDM_MATCH_END;
      break;

    case UDM_MATCH_SUBSTR:
      AGENT->word_match = UDM_MATCH_SUBSTR;
      break;
						
    default:
      Pike_error("set_param: Unknown word match mode.\n");
      break;
    }
			
    break;
			
  case UDM_PARAM_CACHE_MODE: 
    INT(tmp);
    if(tmp) {
      AGENT->cache_mode = UDM_CACHE_ENABLED;
    } else {
      AGENT->cache_mode = UDM_CACHE_DISABLED;
    }			
    break;
			
  case UDM_PARAM_TRACK_MODE:
    INT(tmp);

    if(tmp) {
      AGENT->track_mode |= UDM_TRACK_QUERIES;
    } else {
      AGENT->track_mode &= ~(UDM_TRACK_QUERIES);
    }
    break;
		
  case UDM_PARAM_PHRASE_MODE: 
    INT(tmp);
    if(tmp) { 
      AGENT->Conf->use_phrases = UDM_PHRASE_ENABLED;
    } else {
      AGENT->Conf->use_phrases = UDM_PHRASE_DISABLED;
    }			
    break;
			
  case UDM_PARAM_ISPELL_PREFIXES:
    INT(tmp);
    if(tmp) {
      AGENT->Conf->ispell_mode |= UDM_ISPELL_USE_PREFIXES;
    } else {					
      AGENT->Conf->ispell_mode &= ~UDM_ISPELL_USE_PREFIXES;
    }
    break;

  case UDM_PARAM_CHARSET:
    STR();
    AGENT->Conf->local_charset = UdmGetCharset(ARG(2).u.string->str);
    AGENT->charset = AGENT->Conf->local_charset;

    break;
			
  case UDM_PARAM_STOPTABLE:
    STR();
    strcat(AGENT->Conf->stop_tables, " ");
    strcat(AGENT->Conf->stop_tables, ARG(2).u.string->str);

    break;

  case UDM_PARAM_STOPFILE:
    STR();
    if (UdmFileLoadStopList(AGENT->Conf, ARG(2).u.string->str)) {
      Pike_error(AGENT->Conf->errstr);
    }
			    
    break;
			
  case UDM_PARAM_WEIGHT_FACTOR: 
    STR();
    AGENT->weight_factor = strdup(ARG(2).u.string->str);
			    
    break;
			
  case UDM_PARAM_MIN_WORD_LEN: 
    INT(AGENT->Conf->min_word_len);
    break;
			
  case UDM_PARAM_MAX_WORD_LEN: 
    INT(AGENT->Conf->max_word_len);
    break;
			
#if UDM_VERSION_ID > 30110

  case UDM_PARAM_CROSS_WORDS:
    INT(tmp);
    if(tmp) {
      AGENT->Conf->use_crossword = UDM_CROSS_WORDS_ENABLED;
    } else {
      AGENT->Conf->use_crossword = UDM_CROSS_WORDS_DISABLED;
    }
    break;
#endif
			
  default:
    Pike_error("set_param: Unknown agent session parameter.\n");
    break;
  }
  RETURN_TRUE;
}
#undef STR
#undef INT
#undef TYPE_ERROR

MNOGO_API(load_ispell_data)
{
  char *val1, *val2;
  int var, flag;
  get_all_args("load_ispell_data", args, "%d%s%s%d",
	       &var, &val1, &val2, &flag);
	
  switch(var) {
  case UDM_ISPELL_TYPE_DB: 
    AGENT->Conf->ispell_mode |= UDM_ISPELL_MODE_DB;
    
    if (UdmDBImportAffixes(AGENT,AGENT->charset) || 
	UdmImportDictionaryFromDB(AGENT)) {
      RETURN_FALSE;
    } 
    
    break;
    
  case UDM_ISPELL_TYPE_AFFIX: 
    AGENT->Conf->ispell_mode &= ~UDM_ISPELL_MODE_DB;

#if UDM_VERSION_ID > 30111
    AGENT->Conf->ispell_mode &= ~UDM_ISPELL_MODE_SERVER;
#endif
			
    if (UdmImportAffixes(AGENT->Conf,val1,val2,NULL,0)) {
      Pike_error("load_ispell_data: Cannot load affix file %s",val2);
    }
    break;
			
  case UDM_ISPELL_TYPE_SPELL: 
    AGENT->Conf->ispell_mode &= ~UDM_ISPELL_MODE_DB;
			
#if UDM_VERSION_ID > 30111
    AGENT->Conf->ispell_mode &= ~UDM_ISPELL_MODE_SERVER;
#endif
			
    if (UdmImportDictionary(AGENT->Conf,val1,val2,1,"")) {
      Pike_error("load_ispell_data: Cannot load spell file %s",val2);
    }
    break;

#if UDM_VERSION_ID > 30111
  case UDM_ISPELL_TYPE_SERVER:
    AGENT->Conf->ispell_mode &= ~UDM_ISPELL_MODE_DB;
    AGENT->Conf->ispell_mode |=  UDM_ISPELL_MODE_SERVER;
			
    AGENT->Conf->spellhost = strdup(val1);
    break;
			
#endif

  default:
    Pike_error("load_ispell_data: Unknown ispell type parameter");
    break;
  }
	
  if (flag) {
    if(AGENT->Conf->nspell) {
      UdmSortDictionary(AGENT->Conf);
      UdmSortAffixes(AGENT->Conf);
    }
  }
  RETURN_TRUE;
}

MNOGO_API(free_ispell_data)
{
#if UDM_VERSION_ID > 30111
  UdmFreeIspell(AGENT->Conf);
#endif
  RETURN_TRUE;
}


MNOGO_API(add_search_limit)
{
  char *val;
  int var;

  if(args >= 2) {
    if(ARG(1).type != PIKE_T_INT) {
      SIMPLE_BAD_ARG_ERROR("add_search_limit", 1, "int");
    }
    if(ARG(2).type != PIKE_T_STRING) {
      SIMPLE_BAD_ARG_ERROR("add_search_limit", 2, "string");
    }
    var = ARG(1).u.integer;
    val = ARG(2).u.string->str;
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("add_search_limit", 2);
  }
  switch(var) {
  case UDM_LIMIT_URL: 
    UdmAddURLLimit(AGENT->Conf,val);
    break;
			
  case UDM_LIMIT_TAG: 
    UdmAddTagLimit(AGENT->Conf,val);
    break;

  case UDM_LIMIT_LANG: 
    UdmAddLangLimit(AGENT->Conf,val);
    break;

  case UDM_LIMIT_CAT: 
    UdmAddCatLimit(AGENT->Conf,val);
    break;
			
  case UDM_LIMIT_DATE: {
    struct udm_stl_info_t stl_info = { 0, 0, 0 };
			
    if (val[0] == '>') {
      stl_info.type=1;
    } else if (val[0] == '<') {
      stl_info.type=-1;
    } else {
      Pike_error("add_search_limit: Incorrect date limit format.\n");
    }			
			
    stl_info.t1 = (time_t)(atol(val+1));
    UdmAddTimeLimit(AGENT->Conf, &stl_info);
			
    break;
  }
  default:
    Pike_error("add_search_limit: Unknown search limit parameter.\n");
    break;
  }
  RETURN_TRUE;
}


MNOGO_API(clear_search_limits)
{
  UdmClearLimits(AGENT->Conf);
  RETURN_TRUE;
}

static inline void push_result_field(UDM_DOCUMENT * Doc) {
  push_text("url");
  push_text(Doc->url);
    
  push_text("content_type"); 	
  push_text(Doc->content_type);
    
  push_text("title");
  push_text(Doc->title);

  push_text("keywords");
  push_text(Doc->keywords);
				
  push_text("description");
  push_text(Doc->description);

  push_text("text");
  push_text(Doc->text);
				
  push_text("size");		
  push_int(Doc->size);
				
  push_text("urlid");		
  push_int(Doc->url_id);
				
  push_text("rating");		
  push_int(Doc->rating);
				
  push_text("modified");	
  push_int(Doc->last_mod_time);

  push_text("order");	
  push_int(Doc->order);
				
  push_text("crc");	
  push_int64(Doc->crc32);
				
  push_text("category");		
  push_text(Doc->category);

  f_aggregate_mapping(26);
}

MNOGO_API(fetch_row) {
  unsigned int row;
  
  if(args >= 1) {
    if(ARG(1).type != PIKE_T_INT) {
      SIMPLE_BAD_ARG_ERROR("fetch_row", 1, "int");
    }      
    row = ARG(1).u.integer;
  } else {
    row = RES->current_row;
  }
  pop_n_elems(args);
  if(row < RESOBJ->num_rows) {
    push_result_field(&RESOBJ->Doc[row]);
    RES->current_row = row+1;
  } else {
    push_int(0);
  }
}

MNOGO_API(fetch_rows) {
  unsigned int row;
  pop_n_elems(args);
  for(row = 0; row < RESOBJ->num_rows; row++) {
    push_result_field(&RESOBJ->Doc[row]);
  }
  f_aggregate(RESOBJ->num_rows);
}

MNOGO_API(big_query)
{
  UDM_RESULT * result;
  UDM_AGENT * agent;
  char *query;
  if(args >= 1) {
    if(ARG(1).type == PIKE_T_STRING) {
      query = ARG(1).u.string->str;
    } else {
      SIMPLE_BAD_ARG_ERROR("big_query", 1, "string");
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("big_query", 1);
  }
  agent = AGENT;
  THREADS_ALLOW();
  result = UdmFind(agent, UdmTolower(query, agent->charset));
  THREADS_DISALLOW();
  if(result) {
    pop_n_elems(args);
    struct object *resobj = clone_object(mnogo_result_program, 0);
    ((mnogo_result_storage *)PIKE_OBJ_STORAGE(resobj))->mnogo_result = result;
    push_object(resobj);
  } else {
    RETURN_FALSE;
  }	
}

MNOGO_API(query)
{
  unsigned int row;
  UDM_RESULT *result;
  UDM_AGENT *agent;
  char *query;
  if(args >= 1) {
    if(ARG(1).type == PIKE_T_STRING) {
      query = ARG(1).u.string->str;
    } else {
      SIMPLE_BAD_ARG_ERROR("query", 1, "string");
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("query", 1);
  }
  agent = AGENT;
  THREADS_ALLOW();
  result = UdmFind(agent, UdmTolower(query, agent->charset));
  THREADS_DISALLOW();
  if(result) {
    pop_n_elems(args);
    for(row = 0; row < result->num_rows; row++) {
      push_result_field(&result->Doc[row]);
    }
    f_aggregate(result->num_rows);
    UdmFreeResult(result);
  } else {
    RETURN_FALSE;
  }	
}

MNOGO_API(num_rows) 	{ RETURN_INT(RESOBJ->num_rows); }
MNOGO_API(total_found) 	{ RETURN_INT(RESOBJ->total_found); }
MNOGO_API(wordinfo) 	{ RETURN_STRING(RESOBJ->wordinfo); }
MNOGO_API(search_time) 	{ RETURN_FLOAT(((double)RESOBJ->work_time)/1000); }
MNOGO_API(first_doc) 	{ RETURN_INT(RESOBJ->first); }
MNOGO_API(last_doc) 	{ RETURN_INT(RESOBJ->last); }

MNOGO_API(errno)	{ RETURN_INT(UdmDBErrorCode(AGENT->db)); }
MNOGO_API(error)	{ RETURN_STRING(UdmDBErrorMsg(AGENT->db)); }
MNOGO_API(api_version)	{ RETURN_INT(UDM_VERSION_ID); }

MNOGO_API(cat_list)
{
  char *cat;
  UDM_CATEGORY *c = NULL;
  char *buf = NULL;
  int cats = 0;
  if(args >= 1) {
    if(ARG(1).type == PIKE_T_STRING) {
      cat = ARG(1).u.string->str;
    } else {
      SIMPLE_BAD_ARG_ERROR("cat_list", 1, "string");
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("cat_list", 1);
  }
  if((c = UdmCatList(AGENT, cat))){
    if (!(buf = calloc(1, UDMSTRSIZ+1))) {
      SIMPLE_OUT_OF_MEMORY_ERROR("cat_list", UDMSTRSIZ+1);
    }

    pop_n_elems(args);

    while(c->rec_id) {			
      snprintf(buf, UDMSTRSIZ, "%s%s", c->link[0] ? "@ ":"", c->name);
      push_text(buf);
      c++;
      cats++;
    }
    free(buf);
    f_aggregate(cats);
  } else {
    RETURN_FALSE;
  }
}

MNOGO_API(cat_path)
{
  char *cat;
  UDM_CATEGORY *c = NULL;
  char *buf = NULL;
  int cats = 0;
  
  if(args >= 1) {
    if(ARG(1).type == PIKE_T_STRING) {
      cat = ARG(1).u.string->str;
    } else {
      SIMPLE_BAD_ARG_ERROR("cat_path", 1, "string");
    }
  } else {
    SIMPLE_TOO_FEW_ARGS_ERROR("cat_path", 1);
  }

  if((c = UdmCatPath(AGENT,cat))){
    if (!(buf=calloc(1,UDMSTRSIZ+1))) {
      SIMPLE_OUT_OF_MEMORY_ERROR("cat_path", UDMSTRSIZ+1);
    }
    
    pop_n_elems(args);
    while(c->rec_id){			
      snprintf(buf, UDMSTRSIZ, "%s%s", c->link[0] ? "@ ":"", c->name);
      push_text(buf);
      c++;
      cats++;
    }
    free(buf);
    f_aggregate(cats);
  } else {
    RETURN_FALSE;
  }
}

#if UDM_VERSION_ID > 30110
MNOGO_API(doc_count)
{
  pop_n_elems(args);
  push_int(UdmGetDocCount(AGENT));
}
#endif

void pike_module_exit() {
  if(mnogo_result_program) {
    free_program(mnogo_result_program);
    mnogo_result_program = NULL;
  }
}

void pike_module_init() 
{
  UdmInit();

#define INTCONST(X,Y)   add_integer_constant(X,	Y, 0)
  /* set_param constants */
  INTCONST("PARAM_PAGE_SIZE", UDM_PARAM_PAGE_SIZE);
  INTCONST("PARAM_PAGE_NUM", UDM_PARAM_PAGE_NUM);
  INTCONST("PARAM_SEARCH_MODE", UDM_PARAM_SEARCH_MODE);
  INTCONST("PARAM_CACHE_MODE", UDM_PARAM_CACHE_MODE);
  INTCONST("PARAM_TRACK_MODE", UDM_PARAM_TRACK_MODE);
  INTCONST("PARAM_PHRASE_MODE", UDM_PARAM_PHRASE_MODE);
  INTCONST("PARAM_CHARSET", UDM_PARAM_CHARSET);
  INTCONST("PARAM_STOPTABLE", UDM_PARAM_STOPTABLE);
  INTCONST("PARAM_STOP_TABLE", UDM_PARAM_STOPTABLE);
  INTCONST("PARAM_STOPFILE", UDM_PARAM_STOPFILE);
  INTCONST("PARAM_STOP_FILE", UDM_PARAM_STOPFILE);
  INTCONST("PARAM_WEIGHT_FACTOR", UDM_PARAM_WEIGHT_FACTOR);
  INTCONST("PARAM_WORD_MATCH", UDM_PARAM_WORD_MATCH);
  INTCONST("PARAM_MAX_WORD_LEN", UDM_PARAM_MAX_WORD_LEN);
  INTCONST("PARAM_MAX_WORDLEN", UDM_PARAM_MAX_WORD_LEN);
  INTCONST("PARAM_MIN_WORD_LEN", UDM_PARAM_MIN_WORD_LEN);
  INTCONST("PARAM_MIN_WORDLEN", UDM_PARAM_MIN_WORD_LEN);
  INTCONST("PARAM_ISPELL_PREFIXES", UDM_PARAM_ISPELL_PREFIXES);
  INTCONST("PARAM_ISPELL_PREFIX", UDM_PARAM_ISPELL_PREFIXES);
  INTCONST("PARAM_PREFIXES", UDM_PARAM_ISPELL_PREFIXES);
  INTCONST("PARAM_PREFIX", UDM_PARAM_ISPELL_PREFIXES);
  INTCONST("PARAM_CROSS_WORDS", UDM_PARAM_CROSS_WORDS);
  INTCONST("PARAM_CROSSWORDS", UDM_PARAM_CROSS_WORDS);
  INTCONST("PARAM_NUM_ROWS", UDM_PARAM_NUM_ROWS);
  INTCONST("PARAM_WORDINFO", UDM_PARAM_WORDINFO);
  INTCONST("PARAM_WORD_INFO", UDM_PARAM_WORDINFO);
  INTCONST("PARAM_SEARCHTIME", UDM_PARAM_SEARCHTIME);
  INTCONST("PARAM_SEARCH_TIME", UDM_PARAM_SEARCHTIME);
  INTCONST("PARAM_FIRST_DOC", UDM_PARAM_FIRST_DOC);
  INTCONST("PARAM_LAST_DOC", UDM_PARAM_LAST_DOC);

  INTCONST("LIMIT_URL", UDM_LIMIT_URL);
  INTCONST("LIMIT_TAG", UDM_LIMIT_TAG);
  INTCONST("LIMIT_LANG", UDM_LIMIT_LANG);
  INTCONST("LIMIT_CAT", UDM_LIMIT_CAT);
  INTCONST("LIMIT_DATE", UDM_LIMIT_DATE);
  
  /* search modes */
  INTCONST("MODE_ALL", UDM_MODE_ALL);
  INTCONST("MODE_ANY", UDM_MODE_ANY);
  INTCONST("MODE_BOOL", UDM_MODE_BOOL);
  INTCONST("MODE_PHRASE", UDM_MODE_PHRASE);

  /* ispell type params */
  INTCONST("ISPELL_TYPE_AFFIX", UDM_ISPELL_TYPE_AFFIX);
  INTCONST("ISPELL_TYPE_SPELL", UDM_ISPELL_TYPE_SPELL);
  INTCONST("ISPELL_TYPE_DB", UDM_ISPELL_TYPE_DB);
  INTCONST("ISPELL_TYPE_SERVER", UDM_ISPELL_TYPE_SERVER);
	
  /* word match mode params */
  INTCONST("MATCH_WORD", UDM_MATCH_WORD);
  INTCONST("MATCH_BEGIN", UDM_MATCH_BEGIN);
  INTCONST("MATCH_SUBSTR", UDM_MATCH_SUBSTR);
  INTCONST("MATCH_END", UDM_MATCH_END);

#undef INTCONST

  start_new_program();
  ADD_STORAGE(mnogo_storage);
  set_exit_callback(free_mnogo_storage);
  set_init_callback(init_mnogo_storage);
  ADD_FUNCTION("create", f_mnogo_create,
	       tFunc(tString tOr(tVoid, tString), tVoid), 0);
  ADD_FUNCTION("set_param", f_mnogo_set_param,
	       tFunc(tInt tOr(tString, tInt), tVoid), 0);
  ADD_FUNCTION("load_ispell_data", f_mnogo_load_ispell_data,
	       tFunc(tInt tString tString tInt, tInt), OPT_SIDE_EFFECT);
  ADD_FUNCTION("free_ispell_data", f_mnogo_free_ispell_data,
	       tFunc(tVoid, tVoid), 0);
  ADD_FUNCTION("add_search_limit", f_mnogo_add_search_limit,
	       tFunc(tInt tString, tVoid), 0);
  ADD_FUNCTION("clear_search_limits", f_mnogo_clear_search_limits,
	       tFunc(tVoid, tVoid), 0);
  ADD_FUNCTION("big_query", f_mnogo_big_query,
	       tFunc(tString, tObj), 0);
  ADD_FUNCTION("query", f_mnogo_query,
	       tFunc(tString, tArray), 0);
  ADD_FUNCTION("errno", f_mnogo_errno,
	       tFunc(tVoid, tInt), 0);
  ADD_FUNCTION("error", f_mnogo_error,
	       tFunc(tVoid, tString), 0);
  ADD_FUNCTION("api_version", f_mnogo_api_version,
	       tFunc(tVoid, tInt), 0);
  ADD_FUNCTION("doc_count", f_mnogo_doc_count,
	       tFunc(tVoid, tInt), 0);
  ADD_FUNCTION("cat_list", f_mnogo_cat_list,
	       tFunc(tString, tArray), 0);
  ADD_FUNCTION("cat_path", f_mnogo_cat_path,
	       tFunc(tString, tArray), 0);
  end_class("Query", 0);

  start_new_program();
  ADD_STORAGE(mnogo_result_storage);
  set_exit_callback(free_mnogo_result_storage);
  set_init_callback(init_mnogo_result_storage);

  ADD_FUNCTION("fetch_row", f_mnogo_fetch_row,
	       tFunc(tOr(tInt, tVoid), tOr(tMapping,tZero)), 0);
  ADD_FUNCTION("fetch_rows", f_mnogo_fetch_rows,
	       tFunc(tInt, tOr(tArray,tZero)), 0);
  ADD_FUNCTION("num_rows", f_mnogo_num_rows,
	       tFunc(tVoid, tInt), 0);
  ADD_FUNCTION("total_found", f_mnogo_total_found,
	       tFunc(tVoid, tInt), 0);
  ADD_FUNCTION("wordinfo", f_mnogo_wordinfo,
	       tFunc(tVoid, tString), 0);
  ADD_FUNCTION("search_time", f_mnogo_search_time,
	       tFunc(tVoid, tFloat), 0);
  ADD_FUNCTION("first_doc", f_mnogo_first_doc,
	       tFunc(tVoid, tInt), 0);
  ADD_FUNCTION("last_doc", f_mnogo_last_doc,
	       tFunc(tVoid, tInt), 0);

  mnogo_result_program = end_program();
  add_program_constant("Result", mnogo_result_program, 0);
}
#else /* HAVE_MNOGOSEARCH */
void pike_module_init(void) { }
void pike_module_exit(void) { }
#endif
