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
#include <string.h>
#include <stdarg.h>
#include <libxml/xmlmemory.h>
#include <libxml/debugXML.h>
#include <libxml/HTMLtree.h>
#include <libxml/xmlIO.h>
#include <libxml/DOCBparser.h>
#include <libxml/xinclude.h>
#include <libxml/catalog.h>
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>


#include "global.h"
#include "interpret.h"
#include "stralloc.h"
#include "pike_macros.h"
#include "module_support.h"
#include "error.h"
#include "mapping.h"
#include "threads.h"

#include <stdio.h>
#include <fcntl.h>

#include "xslt.h"

extern int xmlLoadExtDtdDefaultValue;
struct program *xslt_program=NULL;

StylesheetCache sCache;

static void free_xslt_storage(struct object *o)
{
    if(THIS->base_uri != NULL)  free_string(THIS->base_uri);
    if(THIS->variables != NULL) free_mapping(THIS->variables);
    if(THIS->xml != NULL)       free_string(THIS->xml);
    if(THIS->xsl != NULL)       free_string(THIS->xsl);
    if(THIS->charset)           free(THIS->charset);
    if(THIS->content_type)      free(THIS->content_type);
    
    if(THIS->match_include != NULL ) free_svalue(THIS->match_include);
    if(THIS->open_include != NULL ) free_svalue(THIS->open_include);
    if(THIS->read_include != NULL ) free_svalue(THIS->read_include);
    if(THIS->close_include != NULL ) free_svalue(THIS->close_include);
    if(THIS->file != NULL ) free_object(THIS->file);
    
    MEMSET(THIS, 0, sizeof(xslt_storage));
}

static void init_xslt_storage(struct object *o)
{
    MEMSET(o->storage, 0, sizeof(xslt_storage));
}

void f_create(INT32 args)
{
    pop_n_elems(args);
}

void f_set_base_uri(INT32 args)
{
    if ( args != 1 )
        Pike_error("XSLT.Parser()->set_base_uri: Expected one argument.\n");
    if( sp[-args].type != T_STRING )
      Pike_error(
	"XSLT.Parser()->set_base_uri: Invalid argument 1, expected string.\n");
    if ( THIS->base_uri != NULL )
        free_string(THIS->base_uri);
    THIS->base_uri = sp[-args].u.string;
    add_ref(THIS->base_uri);
    pop_n_elems(args);  
}

void f_set_xml_data(INT32 args)
{
    if(args != 1)
	Pike_error("XSLT.Parser()->set_xml_data: Expected one argument.\n");
    if(sp[-args].type != T_STRING)
	Pike_error("XSLT.Parser()->set_xml_data: Invalid argument 1, expected string.\n");
    if(THIS->xml != NULL) 
	free_string(THIS->xml);

    THIS->xml = sp[-args].u.string;
    add_ref(THIS->xml);
    pop_n_elems(args);    
}

void f_charset(INT32 args)
{
    pop_n_elems(args);
    if(THIS->charset != NULL)
	push_text(THIS->charset);
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

void f_set_include_callbacks(INT32 args)
{
  int i;
  if ( args != 4 )
    Pike_error("XSLT.Parser()->set_include_callbacks(): Expected four arguments (functions: match, open, read, close).\n");
  for ( i = 0; i < 4; i++ )
    if ( sp[-args+i].type != T_FUNCTION )
      Pike_error("Arguments must be a function pointers !\n");
  
  if ( THIS->match_include != NULL )
    free_svalue(THIS->match_include);
  if ( THIS->open_include != NULL )
    free_svalue(THIS->open_include);
  if ( THIS->read_include != NULL )
    free_svalue(THIS->read_include);
  if ( THIS->close_include != NULL )
    free_svalue(THIS->close_include);

  THIS->match_include = malloc(sizeof(struct svalue));
  THIS->open_include = malloc(sizeof(struct svalue));
  THIS->read_include = malloc(sizeof(struct svalue));
  THIS->close_include = malloc(sizeof(struct svalue));

  assign_svalue(THIS->match_include, &sp[-4]);
  assign_svalue(THIS->open_include, &sp[-3]);
  assign_svalue(THIS->read_include, &sp[-2]);
  assign_svalue(THIS->close_include, &sp[-1]);
  pop_n_elems(args);
}

/*****************************************************************************
 * handle include files
 * _include_match will try to find a file
 * _include_open will open it and 
 * _include_read is called subsequently for reading it
 */
int _include_match(const char* filename)
{
  int match;
  
  if ( THIS->match_include == NULL )
    return 0;
  push_svalue(THIS->match_include);
  push_text(filename);
  f_call_function(2);
  
  if ( Pike_sp[-1].type != T_INT ) {
    pop_stack();
    return 0;
  }
  match = Pike_sp[-1].u.integer == 1;
  pop_stack();
  return match;
}

void* _include_open(char* const filename)
{
    struct object*    obj;

    if ( THIS->open_include == NULL )
      return 0;
    
    push_svalue(THIS->open_include);
    push_text(filename);
    f_call_function(2);

    if ( Pike_sp[-1].type == T_INT ) {
	pop_stack();
	return 0;
    }
    obj = Pike_sp[-1].u.object;

    if ( THIS->file != NULL )
	free_object(THIS->file);
    
    THIS->file = obj;
    add_ref(THIS->file);
    THIS->iPosition = 0;

    pop_stack();
    return THIS;
}

int _include_read(void* context, char* buffer, int len)
{
    int result;
    THREAD_SAFE_RUN(result=f_include_read(context, buffer, len));
    return result;
}

int f_include_read(void* context, char* buffer, int len)
{
    struct pike_string* str;


    if ( THIS->read_include == NULL )
	return 0;

    add_ref(THIS->file); // somehow the function call makes it loose refs
    push_object(THIS->file);
    push_int(THIS->iPosition);
    apply_svalue(THIS->read_include, 2);
 
    if ( Pike_sp[-1].type == T_INT ) {
	pop_stack();
	return 0;
    }

    str = Pike_sp[-1].u.string;
    if ( str->len == 0 ) {
      pop_stack();
      return 0;
    }
    if ( str->len > len+THIS->iPosition ) {
	strncpy(buffer, &str->str[THIS->iPosition], len);
	THIS->iPosition += len;
    }
    else if ( str->len - THIS->iPosition >= 0 ) {
	strncpy(buffer, 
		&str->str[THIS->iPosition], 
		str->len-THIS->iPosition);
	buffer[str->len-THIS->iPosition] = '\0';
	len = str->len+1-THIS->iPosition;
    }
    else {
      fprintf(stdout, 
	      "Fatal error while reading include file-length mismatch!\n");
    }
    pop_stack();
    return len;
}

void _include_close(void* context)
{
  struct pike_string* str;
  
  if ( THIS->close_include == NULL )
    return;
  push_svalue(THIS->close_include);
  add_ref(THIS->file);
  push_object(THIS->file);
  f_call_function(2);
}

void xsl_error(void* ctx, const char* msg, ...) {
    va_list args;
    char test[200000];
    xslt_storage* store = (xslt_storage*) ctx;

    
    va_start(args, msg);
    vsprintf(test, msg, args);
    if ( store->err_str != NULL ) {
	sprintf(test, "%s\n%s", &test[0], store->err_str->str);
	free_string(store->err_str);
    }
 
    (struct pike_string *)(store->err_str) = make_shared_string(&test[0]);
    add_ref(store->err_str);
    va_end(args);
}


void f_error(INT32 args)
{
    pop_n_elems(args);
    if( THIS->err != NULL )
      push_string(THIS->err_str);
    else
      push_int(0);
}

static void f_run( INT32 args )
{
    xsltStylesheetPtr cur = NULL;
    xmlDocPtr      doc, res, xsl;
    const char*        params[2];
    char        *xmlstr, *xslstr;
    xmlOutputBufferPtr    xmlBuf;
    struct keypair            *k;
    int           success, count;
    char **vars           = NULL;
    char* resultBuffer;
    xmlCharEncodingHandlerPtr encoding;
    int i;
    
    if ( THIS->xml == NULL || THIS->xsl == NULL) {
	Pike_error("XML or XSL input not set correctly.\n");
    }
    if ( THIS->err_str != NULL ) {
	free_string(THIS->err_str);
	THIS->err_str = NULL;
    }
    xmlSubstituteEntitiesDefault(1);
    xmlLoadExtDtdDefaultValue = 1;
    THREADS_ALLOW();
    THREADS_DISALLOW();
    
    xmlstr = THIS->xml->str;
    xslstr = THIS->xsl->str;
#if 0
    fprintf(stdout, "XML:%s\n", xmlstr);
    fprintf(stdout, "XSL:%s\n", xslstr);
#endif

    xmlSetGenericErrorFunc(THIS, (xsl_error));
    doc = xmlParseMemory(THIS->xml->str, THIS->xml->len);
    xmlRegisterInputCallbacks(
	   _include_match, _include_open, _include_read, _include_close);
    
    xsl = xmlParseMemory(xslstr, strlen(xslstr));
    cur = xsltParseStylesheetDoc(xsl);

    params[0] = NULL;

    if ( THIS->variables != NULL ) 
    {
	struct svalue sind, sval;
	int tmpint=0;
	vars = malloc( sizeof(char *) * 
		       ( 1 + ((m_sizeof(THIS->variables)) * 2 )));
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
    else {
	vars = malloc(sizeof(char *));
	vars[0] = NULL;
    }

    res = xsltApplyStylesheet(cur, doc, vars);
    
    xmlBuf = xmlAllocOutputBuffer(
	xmlGetCharEncodingHandler((xmlCharEncoding)10));
    xsltSaveResultTo( xmlBuf, res, cur );

    encoding = xmlBuf->encoder;
    if ( THIS->charset != NULL )
      free(THIS->charset);
    THIS->charset =  malloc(strlen(encoding->name));
    strcpy(THIS->charset, encoding->name);

    // content type ??
    
    if ( THIS->err_str != NULL ) {
	Pike_error(THIS->err_str->str);
    }
    else {
	pop_n_elems(args);
	resultBuffer = malloc(strlen(xmlBuf->conv->content)+1);
	strcpy(resultBuffer, xmlBuf->conv->content);
	push_text(resultBuffer);
    }
    xmlFreeDoc(doc);
    xmlFreeDoc(res);
    xsltFreeStylesheet(cur);

}
    
/* Initialize and start module */
void pike_module_init( void )
{
    start_new_program();
    ADD_STORAGE(xslt_storage);
    set_init_callback(init_xslt_storage);
    set_exit_callback(free_xslt_storage);
    add_function("create", f_create, "function(void:void)", 0);
    add_function("set_xml_data", f_set_xml_data, "function(string:void)",
		 OPT_SIDE_EFFECT);
    add_function("set_xsl_data", f_set_xsl_data, "function(string:void)",
		 OPT_SIDE_EFFECT);
    add_function("set_include_callbacks", f_set_include_callbacks, 
		 "function(function, function, function, function:void)", 0);
    add_function("set_base_uri", f_set_base_uri, "function(string:void)",
		 OPT_SIDE_EFFECT);
    add_function("charset", f_charset, "function(void:string)",
		 OPT_SIDE_EFFECT);
    add_function("content_type", f_content_type, "function(void:string)",
		 OPT_SIDE_EFFECT);
    add_function("set_variables", f_set_variables, "function(mapping:void)",
		 OPT_SIDE_EFFECT);
    add_function("error", f_error, "function(void:string)", 0);
    add_function( "run", f_run, "function(void:string)", 0);
    xslt_program = end_program();
    add_program_constant("Parser", xslt_program, 0);
}

/* Restore and exit module */
void pike_module_exit( void )
{
    if(xslt_program)
	free_program(xslt_program);
}

 
