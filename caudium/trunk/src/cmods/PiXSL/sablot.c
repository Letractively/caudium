/* $Id$ */
#include "global.h"
RCSID("$Id$");
#include "stralloc.h"
#include "pike_macros.h"
#include "module_support.h"
#include "error.h"

#include "threads.h"
#include <stdio.h>
#include <fcntl.h>

#include "sablot_config.h"

#ifdef HAVE_SABLOT
#include <sablot.h>
#endif

/* Initialize and start module */
void pike_module_init( void )
{
#ifdef HAVE_SABLOT
  add_function_constant( "parse", f_parse,
			 "function(string,string,void|string:string)", 0);
  add_function_constant( "parse_files", f_parse_files,
			 "function(string,string:string)", 0);
#endif
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

/** Functions implementing Pike functions **/
#ifdef HAVE_SABLOT

static void really_do_parse(SablotHandle sproc, char *xsl, char *xml,
			    char **argums, char **res)
{
  SablotRunProcessor(sproc, xsl, xml, "arg:/_output",
			       NULL, argums);  
  SablotGetResultArg(sproc, "arg:/_output", res);
}

static void f_parse( INT32 args )
{
  SablotHandle sproc;
  struct pike_string *xml, *xsl, *out = NULL;
  struct svalue base;
  char *parsed = NULL;
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
  really_do_parse(sproc, "arg:/_xsl", "arg:/_xml", argums, &parsed);
  THREADS_DISALLOW();
  pop_n_elems(args);
  if(parsed != NULL) {
    out = make_shared_string(parsed);
    push_string(out);
  } else
    push_int(0);
  SablotDestroyProcessor(sproc);
}

static void f_parse_files( INT32 args )
{
  SablotHandle sproc;
  struct pike_string *xml, *xsl, *out = NULL;
  char *parsed = NULL;
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
  really_do_parse(sproc, xsl->str, xml->str, argums, &parsed);
  THREADS_DISALLOW();
  pop_n_elems(args);
  if(parsed != NULL) {
    out = make_shared_string(parsed);
    push_string(out);
  } else
    push_int(0);
  SablotDestroyProcessor(sproc);
}
#endif  
