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

/* $Id$ */
#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"

#include <stdio.h>
#include <fcntl.h>

#include "sablot_config.h"
#ifdef HAVE_SABLOT
#include <sablot.h>
#include <shandler.h>
struct program *xslt_program=NULL;

/** Functions implementing Pike functions **/
#include "pixsl.h"

/* Sablot Message Handlers */
static MH_ERROR mh_makecode(void *ud, SablotHandle sproc,
                            int severity, unsigned short f,
                            unsigned short code){
  return code; /* use internal codes */
}

static MH_ERROR mh_log(void *ud, SablotHandle sproc,
                       MH_ERROR code, MH_LEVEL level, char **fields)
{
  /* No logging... */
  return code;
}

INLINE static MH_ERROR low_mh_error(void *ud, SablotHandle sproc,
                                    MH_ERROR code, MH_LEVEL level,
                                    char **fields)
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
  switch(level) {
      case 0:
        val = make_shared_binary_string("DEBUG", 5);
        break;
      case 1:
        val = make_shared_binary_string("INFO", 4);
        break;
      case 2:
        val = make_shared_binary_string("WARNING", 7);
        break;
      case 3:
        val = make_shared_binary_string("ERROR", 5);
        break;
      case 4:
        val = make_shared_binary_string("FATAL", 5);
        break;
      default:
        val = make_shared_binary_string("UNKNOWN", 7);
        break;
  }
  skey.u.string = key;
  sval.u.string = val;
  mapping_insert(map, &skey, &sval);
  free_string(key);
  free_string(val);
  for (cc = fields; *cc != NULL; cc++) {
    c = STRCHR(*cc, ':');
    if (c == NULL)
      continue;
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
                         MH_ERROR code, MH_LEVEL level,
                         char **fields)
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
  if(this->charset)
    free(this->charset);
  if(this->content_type)
    free(this->content_type);
  this->content_type = strdup(content_type);
  this->charset = strdup(charset);
}

MiscHandler sablot_misc  = {
  misc_documentinfo
};

static void f_run(INT32 args)
{
  void               *sproc = NULL;
  void               *situation = NULL;
  struct keypair     *k;
  struct pike_string *xml, *xsl;
  struct svalue       base;
  char               *parsed = NULL;
  struct mapping     *err = NULL;
  int                 success, count;
  char               *xmlsrc, *xslsrc;
  char              **vars = NULL;
  int                 errcode, i;
  char               *argums[] = {
    "/_output", NULL, 
    "/_xsl", NULL,
    "/_xml", NULL, 
    NULL, NULL
  };

  if (THIS->xml == NULL || THIS->xsl == NULL) {
    Pike_error("XML or XSL input not set correctly.\n");
  }

  if ((errcode = SablotCreateSituation(&situation)))
    Pike_error("Error creating the Sablotron Situation object (err=%d)\n",
               errcode);
  if ((errcode = SablotCreateProcessorForSituation(situation, &sproc)))
    Pike_error("Error creating the Sablotron Processor object (err=%d)\n",
               errcode);
  
  if (THIS->base_uri != NULL) {
    /* Process the base URI */
    if (STRSTR(THIS->base_uri->str, "file:/") == NULL) {
      /* prepend with file: or file:/ since that's the only currently
       * supported method. We can use sprintf safely, since we have allocated
       * a string of enough length.
       */
      char *tmp = malloc(THIS->base_uri->len + 7);
      if (tmp == NULL) {
        SablotDestroyProcessor(sproc);
        SablotDestroySituation(situation);
        Pike_error("Sablotron.parse(): Failed to allocate string. Out of memory?\n");
      }
      
      if (THIS->base_uri->len > 1 && *THIS->base_uri->str == '/')
        sprintf(tmp, "file:%s", THIS->base_uri->str);
      else
        sprintf(tmp, "file:/%s", THIS->base_uri->str);
      SablotSetBase(sproc, tmp);
      free(tmp);
    } else
      SablotSetBase(sproc, THIS->base_uri->str);
  }

  /* set the arguments */
  argums[3] = THIS->xsl->str;
  argums[5] = THIS->xml->str;
  for (i = 0; argums[i]; i += 2) {
    errcode = SablotAddArgBuffer(situation, sproc, argums[i], argums[i+1]);
    if (errcode) {
      SablotDestroyProcessor(sproc);
      SablotDestroySituation(situation);
      Pike_error("Error adding arguments to the Situation (arg='%s')\n",
                 argums[i]);
    }
  }
  
  if (THIS->xsl_type == SX_DATA) { 
    xslsrc = "arg:/_xsl";
  } else {
    xslsrc = THIS->xsl->str;    
  }
  
  if (THIS->xml_type == SX_DATA) { 
    xmlsrc = "arg:/_xml";
  } else {
    xmlsrc = THIS->xml->str;    
  }
  
  if (THIS->variables != NULL) {
    struct svalue sind, sval;
    
    MY_MAPPING_LOOP(THIS->variables, count, k)  {
      sind = k->ind;
      sval = k->val;
      if (!(sind.type == T_STRING && sval.type == T_STRING)) {
        continue;
      }
      SablotAddParam(situation, sproc, sind.u.string->str, sval.u.string->str);
    }
  }
  
  SablotRegHandler(sproc, HLR_MESSAGE, &sablot_mh, (void *)(&THIS->err));
  SablotRegHandler(sproc, HLR_MISC, &sablot_misc, (void *)THIS);
  THREADS_ALLOW();

  if (THIS->do_callbacks &&
      SablotRegHandler(THIS->sproc, HLR_SCHEME, &THIS->sab_scheme_handler, THIS))
    Pike_error("Failed to register the scheme handler\n");
  
  success |= SablotRunProcessorGen(situation, sproc, xslsrc, xmlsrc, "arg:/_output");
  success |= SablotGetResultArg(sproc, "arg:/_output", &parsed);
  THREADS_DISALLOW();

  if (parsed != NULL) {
    pop_n_elems(args);
    push_text(parsed);    
  } else {
    SablotDestroyProcessor(sproc);
    SablotDestroySituation(situation);
    Pike_error("Parsing failed.\n");
  }
  SablotDestroyProcessor(sproc);
  SablotDestroySituation(situation);
}

static void free_xslt_storage(struct object *o)
{
  if (THIS->base_uri != NULL)
    free_string(THIS->base_uri);
  if (THIS->variables != NULL)
    free_mapping(THIS->variables);
  if (THIS->xml != NULL)
    free_string(THIS->xml);
  if (THIS->xsl != NULL)
    free_string(THIS->xsl);
  if (THIS->charset)
    free(THIS->charset);
  if (THIS->content_type)
    free(THIS->content_type);
  MEMSET(THIS, 0, sizeof(xslt_storage));
}

static void init_xslt_storage(struct object *o)
{
  MEMSET(THIS, 0, sizeof(xslt_storage));
}

static void f_create(INT32 args)
{
  pop_n_elems(args);
}

static void f_error(INT32 args)
{
  pop_n_elems(args);
  if (THIS->err != NULL)
    ref_push_mapping(THIS->err);
  else
    push_int(0);
}

static void f_content_type(INT32 args)
{
  pop_n_elems(args);
  if (THIS->content_type != NULL)
    push_text(THIS->content_type);
  else
    push_int(0);
}

static void f_charset(INT32 args)
{
  pop_n_elems(args);
  if (THIS->charset != NULL)
    push_text(THIS->charset);
  else
    push_int(0);
}

static void f_set_xml_data(INT32 args)
{
  struct pike_string *str;
  
  get_all_args("set_xml_date", args, "%t", &str);
  if (THIS->xml != NULL)
    free_string(THIS->xml);
  THIS->xml = str;
  add_ref(THIS->xml);
  THIS->xml_type = SX_DATA;
  pop_n_elems(args);
}

static void f_set_xml_file(INT32 args)
{
  struct pike_string *str;

  get_all_args("set_xml_file", args, "%t", &str);
  if (THIS->xml != NULL)
    free_string(THIS->xml);
  THIS->xml = str;
  add_ref(THIS->xml);
  THIS->xml_type = SX_FILE;
  pop_n_elems(args);
}

static void f_set_xsl_data(INT32 args)
{
  struct pike_string  *str;

  get_all_args("set_xsl_data", args, "%t", &str);
  if (THIS->xsl != NULL)
    free_string(THIS->xsl);
  THIS->xsl = str;
  add_ref(THIS->xsl);
  THIS->xsl_type = SX_DATA;
  pop_n_elems(args);
}

static void f_set_base_uri(INT32 args)
{
  struct pike_string  *str;

  get_all_args("set_base_uri", args, "%t", &str);
  if(THIS->base_uri != NULL)
    free_string(THIS->base_uri);
  THIS->base_uri = str;
  add_ref(THIS->base_uri);
  pop_n_elems(args);
}

static void f_set_xsl_file(INT32 args)
{
  struct pike_string  *str;

  get_all_args("set_xsl_file", args, "%t", &str);
  if(THIS->xsl != NULL)
    free_string(THIS->xsl);
  THIS->xsl = str;
  add_ref(THIS->xsl);
  THIS->xsl_type = SX_FILE;
  pop_n_elems(args);
}

static void f_set_variables(INT32 args)
{
  struct mapping  *map;

  get_all_args("set_variables", args, "%m", &map);
  if(THIS->variables != NULL)
    free_mapping(THIS->variables);
  THIS->variables = map;
  add_ref(THIS->variables);
  pop_n_elems(args);
}

/* callback wrappers
 *
 * All of them return an array with the following contents:
 *
 *  arr[0] - (int) the error code (0 - success, 1 - failure in general)
 *  arr[1] - (mixed) a callback-specific value
 */
INLINE static int getRespValues(struct svalue *retcode, struct svalue *retval, INT32 type2)
{
  struct array  *a;

  if (Pike_sp[-1].type != T_ARRAY)
    return 1;
  
  a = Pike_sp[-1].u.array;
  array_index(retcode, a, 0);
  
  if (retcode->type != T_INT)
    return 1;

  if (type2 != T_VOID && retval->type != type2)
    return 1;
  
  array_index(retval, a, 1);
  return 0;
}

/*
 * Pike synopsis (actual name doesn't matter):
 *
 * array(int|string) getAll(string scheme, string rest);
 *
 * open the URI and return the whole string
 *
 *  scheme = URI scheme (e.g. "http")
 *  rest = the rest of the URI (without colon)
 *
 * index 0 of the returned contains the error result (0 - success, 1 -
 * failure) 
 * index 1 of the returned array contains the result of the get.
 */
static int sh_getAll(void *userData, SablotHandle processor,
                     const char *scheme, const char *rest,
                     char **buffer, int *byteCount)
{
  xslt_storage       *This = (xslt_storage*)userData;
  struct svalue       retcode, retval;
  
  if (!buffer || !byteCount || !This || !This->scheme_cb.getAll)
    return 1;

  push_text(scheme);
  push_text(rest);
  apply_svalue(This->scheme_cb.getAll, 2);
  
  if (getRespValues(&retcode, &retval, T_STRING)) {
    pop_stack();
    return 1;
  }

  if (retcode.u.integer) {
    pop_stack();
    return retcode.u.integer;
  }
  
  if (This->scheme_cb.getAllBuffer) {
    sub_ref(This->scheme_cb.getAllBuffer);
    free_string(This->scheme_cb.getAllBuffer);
  }
  
  copy_shared_string(This->scheme_cb.getAllBuffer, retval.u.string);
  pop_stack();
  add_ref(This->scheme_cb.getAllBuffer);
  
  *buffer = This->scheme_cb.getAllBuffer->str;
  *byteCount = This->scheme_cb.getAllBuffer->len;
  
  return retcode.u.integer;
}

/*
 * Pike synopsis (actual name doesn't matter):
 *
 * array(int|string) freeMemory(string buffer);
 *
 * release the resources allocated in the getAll call
 *
 * index 0 of the returned contains the error result (0 - success, 1 -
 * failure) 
 * index 1 of the returned array is ignored
 */
static int sh_freeMemory(void *userData, SablotHandle processor, char *buffer)
{
  xslt_storage  *This = (xslt_storage*)userData;
  struct svalue  retcode, retval;
  
  if (!This || !This->scheme_cb.freeMemory)
    return 1;

  /* Call up to pike and then dereference the string */
  push_string(This->scheme_cb.getAllBuffer);
  apply_svalue(This->scheme_cb.freeMemory, 1);
  if (getRespValues(&retcode, &retval, T_VOID)) {
    pop_stack();
    return 1;
  }

  if (retcode.u.integer) {
    pop_stack();
    return retcode.u.integer;
  }
  
  if (This->scheme_cb.getAllBuffer) {
    sub_ref(This->scheme_cb.getAllBuffer);
    This->scheme_cb.getAllBuffer = NULL;
  }

  pop_stack();
  return 0;
}

/*
 * Pike synopsis (actual name doesn't matter):
 *
 * array(int|string) open(string scheme, string rest);
 *
 * open the URI and assign a handle to this instance
 *
 *  scheme = URI scheme (e.g. "http")
 *  rest = the rest of the URI (without colon)
 *
 * index 0 of the returned contains the error result (0 - success, 1 -
 * failure) 
 * index 1 of the returned array contains the integer handle.
 */
static int sh_open(void *userData, SablotHandle processor,
                   const char *scheme, const char *rest, int *handle)
{
  xslt_storage  *This = (xslt_storage*)userData;
  struct svalue  retcode, retval;
  
  if (!scheme || !rest || !handle || !This || !This->scheme_cb.open)
    return 1;

  /* call up to pike and expect an integer on return - the handle */
  push_text(scheme);
  push_text(rest);
  apply_svalue(This->scheme_cb.open, 2);
  if (getRespValues(&retcode, &retval, T_INT)) {
    pop_stack();
    return 1;
  }
  
  if (retcode.u.integer) {
    pop_stack();
    return retcode.u.integer;
  }

  *handle = retval.u.integer;
  pop_stack();
  
  return 0;
}

/*
 * Pike synopsis (actual name doesn't matter):
 *
 * array(int|string) put(int handle, string buffer);
 *
 * put the buffer contents into the scheme
 *
 *  handle = the handle previously assigned to the buffer in the open call
 *  buffer = the data to put into the scheme
 *
 * index 0 of the returned contains the error result (0 - success, 1 -
 * failure) 
 * index 1 of the returned array contains the number of actual bytes
 * written to the scheme
 */
static int sh_put(void *userData, SablotHandle processor, int handle,
                  const char *buffer, int *byteCount)
{
  xslt_storage  *This = (xslt_storage*)userData;
  struct svalue  retcode, retval;
  
  if (!buffer || !byteCount || !This || !This->scheme_cb.put)
    return 1;

  /* 
   * call up to pike and expect an integer on return - the actual number of
   * bytes written to the scheme
   */
  push_int(handle);
  push_text(buffer);
  apply_svalue(This->scheme_cb.put, 2);
  if (getRespValues(&retcode, &retval, T_INT)) {
    pop_stack();
    return 1;
  }

  if (retcode.u.integer) {
    pop_stack();
    return retcode.u.integer;
  }

  *byteCount = retval.u.integer;
  pop_stack();
  
  return 0;
}

/*
 * Pike synopsis (actual name doesn't matter):
 *
 * array(int|string) get(int maxSize)
 *
 * retrieve data from the scheme and put it in the document
 *
 *  maxSize = the maximum number of bytes to return
 *
 * index 0 of the returned contains the error result (0 - success, 1 -
 * failure) 
 * index 1 of the returned array contains the result of the get.
 */
static int sh_get(void *userData, SablotHandle processor, int handle,
                  char *buffer, int *byteCount)
{
  xslt_storage  *This = (xslt_storage*)userData;
  struct svalue  retcode, retval;
  
  if (!buffer || !byteCount || !This || !This->scheme_cb.get)
    return 1;

  /* call up to pike, get the buffer (*byteCount max) on return */
  push_int(*byteCount);
  apply_svalue(This->scheme_cb.get, 1);
  if (getRespValues(&retcode, &retval, T_STRING)) {
    pop_stack();
    return 1;
  }

  if (retcode.u.integer) {
    pop_stack();
    return retcode.u.integer;
  }

  *byteCount = retval.u.string->len < *byteCount ? retval.u.string->len : *byteCount;
  MEMCPY(buffer, retval.u.string->str, *byteCount);
  pop_stack();

  return 0;
}

/*
 * Pike synopsis (actual name doesn't matter):
 *
 * array(int|string) close(string scheme, string rest);
 *
 * close the specified instance
 *
 *  handle = the handle allocated in the open call
 *
 * index 0 of the returned contains the error result (0 - success, 1 -
 * failure) 
 * index 1 of the returned array is ignored
 */
static int sh_close(void *userData, SablotHandle processor, int handle)
{
  xslt_storage  *This = (xslt_storage*)userData;
  struct svalue  retcode, retval;
  
  if (!This || !This->scheme_cb.close)
    return 1;

  /* call up to pike and ignore the return value */
  push_int(handle);
  apply_svalue(This->scheme_cb.close, 1);
  if (getRespValues(&retcode, &retval, T_VOID)) {
    pop_stack();
    return 1;
  }

  if (retcode.u.integer) {
    pop_stack();
    return retcode.u.integer;
  }
  
  return 0;
}

INLINE static void install_callbacks(struct mapping *cbmap)
{
  struct svalue    *sv;
  
  THIS->do_callbacks = 0;

  /* get all the callbacks one by one and set them in THIS */
  if ((sv = simple_mapping_string_lookup(cbmap, "getAll"))) {
    THIS->scheme_cb.getAll = sv;
    THIS->do_callbacks = 1;
  }

  if ((sv = simple_mapping_string_lookup(cbmap, "freeMemory"))) {
    THIS->scheme_cb.freeMemory = sv;
    THIS->do_callbacks = 1;
  }

  if ((sv = simple_mapping_string_lookup(cbmap, "get"))) {
    THIS->scheme_cb.get = sv;
    THIS->do_callbacks = 1;
  }

  if ((sv = simple_mapping_string_lookup(cbmap, "open"))) {
    THIS->scheme_cb.open = sv;
    THIS->do_callbacks = 1;
  }

  if ((sv = simple_mapping_string_lookup(cbmap, "put"))) {
    THIS->scheme_cb.put = sv;
    THIS->do_callbacks = 1;
  }

  if ((sv = simple_mapping_string_lookup(cbmap, "close"))) {
    THIS->scheme_cb.close = sv;
    THIS->do_callbacks = 1;
  }

  /* if any callback was present, try to install the handler */
  if (THIS->do_callbacks) {
    if (THIS->scheme_cb.getAll)
      THIS->sab_scheme_handler.getAll = sh_getAll;
    if (THIS->scheme_cb.freeMemory)
      THIS->sab_scheme_handler.freeMemory = sh_freeMemory;
    if (THIS->scheme_cb.open)
      THIS->sab_scheme_handler.open = sh_open;
    if (THIS->scheme_cb.get)
      THIS->sab_scheme_handler.get = sh_get;
    if (THIS->scheme_cb.put)
      THIS->sab_scheme_handler.put = sh_put;
    if (THIS->scheme_cb.close)
      THIS->sab_scheme_handler.close = sh_close;
  }
}

/* Expects a mapping as the parameter:
 *
 *  getAll
 *  freeMemory
 *  get
 *  open
 *  put
 *  close
 *
 * For synopsis of the functions see above.
 */
static void f_set_scheme_callbacks(INT32 args)
{
  struct mapping   *cbmap;  
  
  get_all_args("set_scheme_callbacks", args, "%m", &cbmap);
  install_callbacks(cbmap);
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
  ADD_FUNCTION("run", f_run, tFunc(tVoid, tString), 0);
  ADD_FUNCTION("set_scheme_callbacks", f_set_scheme_callbacks, tFunc(tMapping, tVoid), 0);
  
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

 
