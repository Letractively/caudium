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
#include "interpret.h"
#include "stralloc.h"
#include "pike_macros.h"
#include "module_support.h"
#include "error.h"
#include "mapping.h"
#include "threads.h"

#include <stdio.h>
#include <fcntl.h>

#include "sablot_config.h"

#ifdef HAVE_SABLOT
#include <sablot.h>
#endif
/* This allows execution of c-code that requires the Pike interpreter to 
 * be locked from the Sablotron callback functions.
 */
#if defined(PIKE_THREADS) && defined(_REENTRANT)
#define THREAD_SAFE_RUN(COMMAND)  do {\
  struct thread_state *state;\
 if((state = thread_state_for_id(th_self()))!=NULL) {\
    if(!state->swapped) {\
      COMMAND;\
    } else {\
      mt_lock(&interpreter_lock);\
      SWAP_IN_THREAD(state);\
      COMMAND;\
      SWAP_OUT_THREAD(state);\
      mt_unlock(&interpreter_lock);\
    }\
  }\
} while(0)
#else
#define THREAD_SAFE_RUN(COMMAND) COMMAND
#endif

/* Initialize and start module */
void pike_module_init( void )
{
#ifdef HAVE_SABLOT
  add_function_constant( "parse", f_parse,
			 "function(string,string,void|string:string|mapping)",
			 0);
  add_function_constant( "parse_files", f_parse_files,
			 "function(string,string:string|mapping)", 0);
#endif
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

/** Functions implementing Pike functions **/
#ifdef HAVE_SABLOT

/* Sablot Message Handlers */
static MH_ERROR mh_makecode( void *ud, SablotHandle sproc,
	int severity, unsigned short f, unsigned short code){
  return code; /* use internal codes */
};

static MH_ERROR mh_log(void *ud, SablotHandle sproc,
		       MH_ERROR code, MH_LEVEL level, char **fields)
{
  /* No logging... */
  return code;
};

inline static MH_ERROR low_mh_error(void *ud, SablotHandle sproc,
			 MH_ERROR code, MH_LEVEL level, char **fields)
{
  struct mapping *map = *(struct mapping **)ud;
  int len=500;
  char *c;
  char ** cc;
  struct svalue skey, sval;
  struct pike_string *key, *val;
  if(map == NULL) {
    map = allocate_mapping(7);
    *(struct mapping **)ud = map;
  }
  skey.type = sval.type = T_STRING;
  key = make_shared_binary_string("level", 5);
  switch(level)
  {
  case 0:  val = make_shared_binary_string("DEBUG", 5); break;
  case 1:  val = make_shared_binary_string("INFO", 4); break;
  case 2:  val = make_shared_binary_string("WARNING", 7); break;
  case 3:  val = make_shared_binary_string("ERROR", 5); break;
  case 4:  val = make_shared_binary_string("FATAL", 5); break;
  default: val = make_shared_binary_string("UNKNOWN", 7); break;
  }
  skey.u.string = key;
  sval.u.string = val;
  mapping_insert(map, &skey, &sval);
  free_string(key);
  free_string(val);
  for (cc = fields; *cc != NULL; cc++) {
    c = STRCHR(*cc, ':');
    if(c == NULL) continue;
    *c = '\0';
    c++;
    key = make_shared_string(*cc);
    val = make_shared_string(c);
    skey.u.string = key;
    sval.u.string = val;
    mapping_insert(map, &skey, &sval);
    free_string(key);
    free_string(val);
  }
  return 1; 
}
static MH_ERROR mh_error(void *ud, SablotHandle sproc,
			 MH_ERROR code, MH_LEVEL level, char **fields)
{
  THREAD_SAFE_RUN(low_mh_error(ud, sproc, code, level, fields));
  return 1;
};

MessageHandler sablot_mh = {
  mh_makecode,
  mh_log,
  mh_error
};


static int really_do_parse(SablotHandle sproc, char *xsl, char *xml,
			   char **argums, char **res,
			   struct mapping **err)
{
  int ret;
  ret = SablotRegHandler(sproc, HLR_MESSAGE, &sablot_mh, (void *)err);
  ret |= SablotRunProcessor(sproc, xsl, xml, "arg:/_output",
			   NULL, argums);  
  ret |= SablotGetResultArg(sproc, "arg:/_output", res);
  return ret;
}

static void f_parse( INT32 args )
{
  SablotHandle sproc;
  struct pike_string *xml, *xsl;
  struct svalue base;
  char *parsed = NULL;
  struct mapping *err = NULL;
  int success;
  char *argums[] =
  {
    "/_xsl", NULL,
    "/_xml", NULL, 
    "/_output", NULL, 
    NULL
  };
  SablotCreateProcessor(&sproc);
  if(args == 3) {
    /* Use a base URI */ 
    base = sp[-1]; 
    if(base.type == T_STRING) {
      if(STRSTR(base.u.string->str, "file:/") == NULL) {
	/* prepend with file: or file:/ since that's the only currently
	 * supported method. We can use sprintf safely, since we have allocated
	 * a string of enough length.
	 */
	char *tmp = malloc(base.u.string->len + 7);
	if(tmp == NULL)
	  error("Sablotron.parse(): Failed to allocate string. Out of memory?\n");
	if(base.u.string->len > 1 && *base.u.string->str == '/')
	  sprintf(tmp, "file:%s", base.u.string->str);
	else
	  sprintf(tmp, "file:/%s", base.u.string->str);
	SablotSetBase(sproc, tmp);
	free(tmp);
      } else
	SablotSetBase(sproc, base.u.string->str);
    } else if(base.type != T_VOID) {
      error("Sablotron.parse(): Invalid argument 3, expected string.\n");
    }
  }
  get_all_args("Sablotron.parse", args, "%S%S", &xsl, &xml);
  argums[1] = xsl->str;
  argums[3] = xml->str;
  THREADS_ALLOW();
  success = really_do_parse(sproc, "arg:/_xsl", "arg:/_xml", argums, &parsed,
			    &err);
  THREADS_DISALLOW();
  pop_n_elems(args);
  if(err != NULL) {
    push_mapping(err);
  } else if(parsed != NULL) {
    push_text(parsed);    
  } else {
    push_int(0);
  }
  SablotDestroyProcessor(sproc);
}

static void f_parse_files( INT32 args )
{
  SablotHandle sproc;
  struct pike_string *xml, *xsl;
  char *parsed = NULL;
  struct mapping *err = NULL;
  int success;
  char *argums[] =
  {
    "/_output", NULL, 
    NULL
  };
  get_all_args("Sablotron.parse_lines", args, "%S%S", &xsl, &xml);
  /*   SablotRegHandler(p, HLR_MESSAGE,  */
  THREADS_ALLOW();
  SablotCreateProcessor(&sproc);
  success = really_do_parse(sproc, xsl->str, xml->str, argums, &parsed,
			    &err);
  THREADS_DISALLOW();
  pop_n_elems(args);
  if(err != NULL) {
    push_mapping(err);
  } else if(parsed != NULL) {
    push_text(parsed);
  } else
    push_int(0);
  SablotDestroyProcessor(sproc);
}
#endif  
