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
#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"

#include <stdio.h>
#include <fcntl.h>

#include "sablot_config.h"
#include "pixsl.h"
#ifdef HAVE_SABLOT
#include <sablot.h>
struct program *xslt_program=NULL;
#endif

/** Functions implementing Pike functions **/
#ifdef HAVE_SABLOT

/* Sablot Message Handlers */
static MH_ERROR mh_makecode( void *ud, SablotHandle sproc,
	int severity, unsigned short f, unsigned short code){
  return code; /* use internal codes */
}

static MH_ERROR mh_log(void *ud, SablotHandle sproc,
		       MH_ERROR code, MH_LEVEL level, char **fields)
{
  /* No logging... */
  return code;
}

INLINE static MH_ERROR low_mh_error(void *ud, SablotHandle sproc,
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
}

MessageHandler sablot_mh = {
  mh_makecode,
  mh_log,
  mh_error
};


static void misc_documentinfo(void* ud, SablotHandle sproc_,
			      const char *content_type,
			      const char *charset)
{
  xslt_storage *this = (xslt_storage *)ud;
  if(this->charset)           free(this->charset);
  if(this->content_type)      free(this->content_type);
  this->content_type = strdup(content_type);
  this->charset = strdup(charset);
}

MiscHandler sablot_misc  = {
  misc_documentinfo
};

static void f_run( INT32 args )
{
  SablotHandle sproc;
  struct keypair *k;
  struct pike_string *xml, *xsl;
  struct svalue base;
  char *parsed = NULL;
  struct mapping *err = NULL;
  int success, count;
  char *xmlsrc, *xslsrc;
  char **vars = NULL;
  char *argums[] =
  {
    "/_output", NULL, 
    "/_xsl", NULL,
    "/_xml", NULL, 
    NULL
  };

  if(THIS->xml == NULL || THIS->xsl == NULL) {
    Pike_error("XML or XSL input not set correctly.\n");
  }

  SablotCreateProcessor(&sproc);
  
  if(THIS->base_uri != NULL)
  {
    /* Process the base URI */
    if(STRSTR(THIS->base_uri->str, "file:/") == NULL) {
      /* prepend with file: or file:/ since that's the only currently
       * supported method. We can use sprintf safely, since we have allocated
       * a string of enough length.
       */
      char *tmp = malloc(THIS->base_uri->len + 7);
      if(tmp == NULL)
	Pike_error("Sablotron.parse(): Failed to allocate string. Out of memory?\n");
      if(THIS->base_uri->len > 1 && *THIS->base_uri->str == '/')
	sprintf(tmp, "file:%s", THIS->base_uri->str);
      else
	sprintf(tmp, "file:/%s", THIS->base_uri->str);
      SablotSetBase(sproc, tmp);
      free(tmp);
    } else
      SablotSetBase(sproc, THIS->base_uri->str);
  }

  argums[3] = THIS->xsl->str;
  argums[5] = THIS->xml->str;

  if(THIS->xsl_type == SX_DATA) { 
    xslsrc = "arg:/_xsl";
  } else {
    xslsrc = THIS->xsl->str;    
  }
  
  if(THIS->xml_type == SX_DATA) { 
    xmlsrc = "arg:/_xml";
  } else {
    xmlsrc = THIS->xml->str;    
  }
  if(THIS->variables != NULL) {
    struct svalue sind, sval;
    int tmpint=0;
    vars = malloc( sizeof(char *) * ( 1 + ((m_sizeof(THIS->variables)) * 2 )));
    MY_MAPPING_LOOP(THIS->variables, count, k)  {
      sind = k->ind;
      sval = k->val;
      if(!(sind.type == T_STRING && sval.type == T_STRING)) {
	continue;
      }
      vars[tmpint++] = sind.u.string->str;
      vars[tmpint++] = sval.u.string->str;
    }
    vars[tmpint] = NULL;
  }
  SablotRegHandler(sproc, HLR_MESSAGE, &sablot_mh, (void *)(&THIS->err));
  SablotRegHandler(sproc, HLR_MISC, &sablot_misc, (void *)THIS);
  THREADS_ALLOW();
  success |= SablotRunProcessor(sproc, xslsrc, xmlsrc, "arg:/_output",
				vars, argums);  
  success |= SablotGetResultArg(sproc, "arg:/_output", &parsed);
  if(vars != NULL)
    free(vars);
  THREADS_DISALLOW();

  if(parsed != NULL) {
    pop_n_elems(args);
    push_text(parsed);    
  } else {
    Pike_error("Parsing failed.\n");
  }
  SablotDestroyProcessor(sproc);
}

static void free_xslt_storage(struct object *o)
{
  if(THIS->base_uri != NULL)  free_string(THIS->base_uri);
  if(THIS->variables != NULL) free_mapping(THIS->variables);
  if(THIS->xml != NULL)       free_string(THIS->xml);
  if(THIS->xsl != NULL)       free_string(THIS->xsl);
  if(THIS->charset)           free(THIS->charset);
  if(THIS->content_type)      free(THIS->content_type);
  MEMSET(THIS, 0, sizeof(xslt_storage));
}

static void init_xslt_storage(struct object *o)
{
  MEMSET(THIS, 0, sizeof(xslt_storage));
}
void f_create(INT32 args)
{
  pop_n_elems(args);
}

void f_error(INT32 args)
{
  pop_n_elems(args);
  if(THIS->err != NULL)
    ref_push_mapping(THIS->err);
  else
    push_int(0);
}

void f_content_type(INT32 args)
{
  pop_n_elems(args);
  if(THIS->content_type != NULL)
    push_text(THIS->content_type);
  else
    push_int(0);
}

void f_charset(INT32 args)
{
  pop_n_elems(args);
  if(THIS->charset != NULL)
    push_text(THIS->charset);
  else
    push_int(0);
}

void f_set_xml_data(INT32 args)
{
  if(args != 1)
    Pike_error("XSLT.Parser()->set_xml_data: Expected one argument.\n");
  if(sp[-args].type != T_STRING)
    Pike_error("XSLT.Parser()->set_xml_data: Invalid argument 1, expected string.\n");
  if(THIS->xml != NULL) free_string(THIS->xml);
  THIS->xml = sp[-args].u.string;
  add_ref(THIS->xml);
  THIS->xml_type = SX_DATA;
  pop_n_elems(args);
}

void f_set_xml_file(INT32 args)
{
  if(args != 1)
    Pike_error("XSLT.Parser()->set_xml_file: Expected one argument.\n");
  if(sp[-args].type != T_STRING)
    Pike_error("XSLT.Parser()->set_xml_file: Invalid argument 1, expected string.\n");
  if(THIS->xml != NULL)
    free_string(THIS->xml);
  THIS->xml = sp[-args].u.string;
  add_ref(THIS->xml);
  THIS->xml_type = SX_FILE;
  pop_n_elems(args);
}

void f_set_xsl_data(INT32 args)
{
  if(args != 1)
    Pike_error("XSLT.Parser()->set_xsl_data: Expected one argument.\n");
  if(sp[-args].type != T_STRING)
    Pike_error("XSLT.Parser()->set_xsl_data: Invalid argument 1, expected string.\n");
  if(THIS->xsl != NULL)
    free_string(THIS->xsl);
  THIS->xsl = sp[-args].u.string;
  add_ref(THIS->xsl);
  THIS->xsl_type = SX_DATA;
  pop_n_elems(args);
}

void f_set_base_uri(INT32 args)
{
  if(args != 1)
    Pike_error("XSLT.Parser()->set_base_uri: Expected one argument.\n");
  if(sp[-args].type != T_STRING)
    Pike_error("XSLT.Parser()->set_base_uri: Invalid argument 1, expected string.\n");
  if(THIS->base_uri != NULL)
    free_string(THIS->base_uri);
  THIS->base_uri = sp[-args].u.string;
  add_ref(THIS->base_uri);
  pop_n_elems(args);
}

void f_set_xsl_file(INT32 args)
{
  if(args != 1)
    Pike_error("XSLT.Parser()->set_xsl_file: Expected one argument.\n");
  if(sp[-args].type != T_STRING)
    Pike_error("XSLT.Parser()->set_xsl_file: Invalid argument 1, expected string.\n");
  if(THIS->xsl != NULL)
    free_string(THIS->xsl);
  THIS->xsl = sp[-args].u.string;
  add_ref(THIS->xsl);
  THIS->xsl_type = SX_FILE;
  pop_n_elems(args);
}

void f_set_variables(INT32 args)
{
  if(args != 1)
    Pike_error("XSLT.Parser()->set_xml_data: Expected one argument.\n");
  if(sp[-args].type != T_MAPPING)
    Pike_error("XSLT.Parser()->set_xml_data: Invalid argument 1, expected mapping.\n");
  if(THIS->variables != NULL)
    free_mapping(THIS->variables);
  THIS->variables = sp[-args].u.mapping;
  add_ref(THIS->variables);
  pop_n_elems(args);
}


#endif  

/* Initialize and start module */
void pike_module_init( void )
{
#ifdef HAVE_SABLOT
  start_new_program();
  ADD_STORAGE(xslt_storage);
  set_init_callback(init_xslt_storage);
  set_exit_callback(free_xslt_storage);
  add_function("create", f_create, "function(void:void)", 0);
  add_function("error", f_error, "function(void:mapping)", 0);
  add_function("content_type", f_content_type, "function(void:string)", 0);
  add_function("charset", f_charset, "function(void:string)", 0);
  add_function("set_xml_data", f_set_xml_data, "function(string:void)",
	       OPT_SIDE_EFFECT);
  add_function("set_xml_file", f_set_xml_file, "function(string:void)",
	       OPT_SIDE_EFFECT);
  add_function("set_xsl_data", f_set_xsl_data, "function(string:void)",
	       OPT_SIDE_EFFECT);
  add_function("set_xsl_file", f_set_xsl_file, "function(string:void)",
	       OPT_SIDE_EFFECT);
  add_function("set_base_uri", f_set_base_uri, "function(string:void)",
	       OPT_SIDE_EFFECT);
  add_function("set_variables", f_set_variables, "function(mapping:void)",
	       OPT_SIDE_EFFECT);
  add_function( "run", f_run, "function(void:string)", 0);
  xslt_program = end_program();
  add_program_constant("Parser", xslt_program, 0);
#endif
}

/* Restore and exit module */
void pike_module_exit( void )
{
#ifdef HAVE_SABLOT
  if(xslt_program)
    free_program(xslt_program);
#endif
}

 
