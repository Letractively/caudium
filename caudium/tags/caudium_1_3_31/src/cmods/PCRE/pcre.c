/*
 * Pike Extension Modules - A collection of modules for the Pike Language
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

/* PCRE Support - This module adds PCRE support to Pike. */

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"
#include "pcre_config.h"



#include <stdio.h>
#include <fcntl.h>

#ifdef HAVE_PCRE

#ifdef HAVE_PCRE_H
# include <pcre.h>
#endif

#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif


static int parse_options(char *pp, int *study)
{
  int opts = 0;
  while(*pp) {
    switch (*pp++) {
      /* Perl compatible options */
    case 'i':	opts |= PCRE_CASELESS;  break;
    case 'm':	opts |= PCRE_MULTILINE; break;
    case 's':	opts |= PCRE_DOTALL;	break;
    case 'x':	opts |= PCRE_EXTENDED;	break;
	
      /* PCRE specific options */
    case '8':	opts |= PCRE_UTF8;	     break;	
    case 'A':	opts |= PCRE_ANCHORED;       break;
    case 'B':	opts |= PCRE_NOTBOL;         break;
    case 'D':	opts |= PCRE_DOLLAR_ENDONLY; break;
    case 'E':	opts |= PCRE_NOTEMPTY;       break;
    case 'L':	opts |= PCRE_NOTEOL;         break;
    case 'S':	if(study != NULL) *study = 1;break;
    case 'N':	if(study != NULL) *study = 0;break;
    case 'U':	opts |= PCRE_UNGREEDY;	     break;
    case 'X':	opts |= PCRE_EXTRA;	     break;	
    case ' ': case '\n':
      break;
      
    default:
      return -pp[-1];
    }
  }
  return opts;
}


/* Create a new PCRE regular expression and compile
 * and optionally study (optimize) the expression.
 */

void f_pcre_create(INT32 args)
{
  struct pike_string *regexp; /* Regexp pattern */
  pcre_extra *extra = NULL;   /* result from study, if enabled */
  pcre *re = NULL;            /* compiled regexp */
  int opts = 0;           /* Regexp compile options */
  const char *errmsg;          /* Error message pointer */
  int erroffset;              /* Error offset */
  int do_study = 1;           /* Study the regexp when it's compiled */
  char *pp;                   /* Temporary char pointer */
  unsigned const char *table = NULL; /* Translation table */
#if HAVE_SETLOCALE
  char *locale = setlocale(LC_CTYPE, NULL); /* Get current locale for
					     * translation table. */
#endif
  free_regexp(Pike_fp->current_object);
  switch(args)
  {
   case 2:
    switch(Pike_sp[-1].type) {
     case T_STRING:
      opts = parse_options(Pike_sp[-1].u.string->str, &do_study);
      if(opts < 0)
	Pike_error("PCRE.Regexp->create(): Unknown option modifier '%c'.\n", -opts);
      break;
     case T_INT:
      if(Pike_sp[-1].u.integer == 0) {
	break;
      }
      /* Fallthrough */
     default:
      Pike_error("Bad argument 2 to PCRE.Regexp->create() - expected string.\n");
      break;
    }
    /* Fall through */
   case 1:
    if(Pike_sp[-args].type != T_STRING || Pike_sp[-args].u.string->size_shift > 0) {
      Pike_error("PCRE.Regexp->create(): Invalid argument 1. Expected 8-bit string.\n");
    }
    regexp = Pike_sp[-args].u.string;
    if((INT32)strlen(regexp->str) != regexp->len)
      Pike_error("PCRE.Regexp->create(): Regexp pattern contains null characters. Use \\0 instead.\n");
    
    break;
   case 0: /* Regexp() compatibility */
    return;
    
   default:
    Pike_error("PCRE.Regexp->create(): Invalid number of arguments. Expected 1 or 2.\n");
  }

#if HAVE_SETLOCALE
  if (strcmp(locale, "C"))
    table = pcre_maketables();
#endif

  /* Compile the pattern and handle errors */
  re = pcre_compile(regexp->str, opts, &errmsg, &erroffset, table);
  if(re == NULL) {
    Pike_error("Failed to compile regexp: %s at offset %d\n", errmsg, erroffset);
  }

  /* If study option was specified, study the pattern and
     store the result in extra for passing to pcre_exec. */
  if (do_study) {
    extra = pcre_study(re, 0, &errmsg);
    if (errmsg != NULL) {
      Pike_error("Error while studying pattern: %s", errmsg);
    }
  }
  THIS->regexp = re;
  THIS->extra = extra;
  THIS->pattern = regexp;
  add_ref(regexp);
  pop_n_elems(args);
}

/* Do a regular expression match */
void f_pcre_match(INT32 args) 
{
  struct pike_string *data; /* Data to match */
  pcre_extra *extra = NULL;   /* result from study, if enabled */
  pcre *re = NULL;            /* compiled regexp */
  char *pp;                 /* Pointer... */
  int opts = 0;             /* Match options */
  int is_match;             /* Did it match? */

  if(THIS->regexp == NULL)
    Pike_error("PCRE.Regexp not initialized.\n");
  switch(args)
  {
   case 2:
    switch(Pike_sp[-1].type) {
     case T_STRING:
      opts = parse_options(Pike_sp[-1].u.string->str, NULL);
      if(opts < 0)
	Pike_error("PCRE.Regexp->match(): Unknown option modifier '%c'.\n", -opts);
      break;
     case T_INT:
      if(Pike_sp[-1].u.integer == 0) {
	break;
      }
      /* Fallthrough */
     default:
      Pike_error("Bad argument 2 to PCRE.Regexp->match() - expected string.\n");
      break;
    }
    /* Fall through */
   case 1:
    if(Pike_sp[-args].type != T_STRING || Pike_sp[-args].u.string->size_shift > 0) {
      Pike_error("PCRE.Regexp->match(): Invalid argument 1. Expected 8-bit string.\n");
    }
    data = Pike_sp[-args].u.string;
    break;
   default:
    Pike_error("PCRE.Regexp->match(): Invalid number of arguments. Expected 1 or 2.\n");
  }
  re = THIS->regexp;
  extra = THIS->extra;

  /* Do the pattern matching */
  is_match = pcre_exec(re, extra, data->str, data->len, 0,
		       opts, NULL, 0);
  pop_n_elems(args);
  switch(is_match) {
  case PCRE_ERROR_NOMATCH:   push_int(0);  break;
  case PCRE_ERROR_NULL:      Pike_error("Invalid argumens passed to pcre_exec.\n");
  case PCRE_ERROR_BADOPTION: Pike_error("Invalid options sent to pcre_exec.\n");
  case PCRE_ERROR_BADMAGIC:  Pike_error("Invalid magic number.\n");
  case PCRE_ERROR_UNKNOWN_NODE: Pike_error("Unknown node encountered. PCRE bug or memory error.\n");
  case PCRE_ERROR_NOMEMORY:  Pike_error("Out of memory during execution.\n");
  default:
    push_int(1); /* A match! */
    break; 
  }
}
/* Split the string according to the regexp */
void f_pcre_split(INT32 args) 
{
  struct array *arr;	    /* Result array */ 
  struct pike_string *data; /* Data to split */
  pcre_extra *extra = NULL; /* result from study, if enabled */
  pcre *re = NULL;          /* compiled regexp */
  char *pp;                 /* Pointer... */
  int opts = 0;             /* Match options */
  int *ovector, ovecsize;   /* Subpattern storage */
  int ret;                  /* Result codes */
  int i, e;                 /* Counter variable */
  if(THIS->regexp == NULL)
    Pike_error("PCRE.Regexp not initialized.\n");
  get_all_args("PCRE.Regexp->split", args, "%S", &data);
  switch(args) {
  case 2:
    switch(Pike_sp[-1].type) {
    case T_STRING:
      opts = parse_options(Pike_sp[-1].u.string->str, NULL);
      if(opts < 0)
	Pike_error("PCRE.Regexp->split(): Unknown option modifier '%c'.\n", -opts);
      break;
    case T_INT:
      if(Pike_sp[-1].u.integer == 0) {
	break;
      }
      /* Fallthrough */
    default:
      Pike_error("Bad argument 2 to PCRE.Regexp->split() - expected string.\n");
      break;
    }
    /* Fallthrough */
  case 1:
    if(Pike_sp[-args].type != T_STRING || Pike_sp[-args].u.string->size_shift > 0) {
      Pike_error("PCRE.Regexp->match(): Invalid argument 1. Expected 8-bit string.\n");
    }
    data = Pike_sp[-args].u.string;
    break;
  default:
    Pike_error("PCRE.Regexp->match(): Invalid number of arguments. Expected 1 or 2.\n");    
  }
  re = THIS->regexp;
  extra = THIS->extra;

  /* Calculate the size of the offsets array, and allocate memory for it. */
  pcre_fullinfo(re, extra, PCRE_INFO_CAPTURECOUNT, &ovecsize);
  ovecsize = (ovecsize + 1) * 3;
  ovector = (int *)malloc(ovecsize * sizeof(int));
  if(ovector == NULL)
    Pike_error("PCRE.Regexp->split(): Out of memory.\n");

  /* Do the pattern matching */
  ret = pcre_exec(re, extra, data->str, data->len, 0,
		       opts, ovector, ovecsize);
  switch(ret) {
   case PCRE_ERROR_NOMATCH:   pop_n_elems(args); push_int(0);  break;
   case PCRE_ERROR_NULL:      Pike_error("Invalid argumens passed to pcre_exec.\n");
   case PCRE_ERROR_BADOPTION: Pike_error("Invalid options sent to pcre_exec.\n");
   case PCRE_ERROR_BADMAGIC:  Pike_error("Invalid magic number.\n");
   case PCRE_ERROR_UNKNOWN_NODE: Pike_error("Unknown node encountered. PCRE bug or memory error.\n");
   case PCRE_ERROR_NOMEMORY:  Pike_error("Out of memory during execution.\n");
   default:
    switch(ret) {
     case 1: /* No submatches, be Pike Regexp compatible */
      pop_n_elems(args);
      push_int(0);
      arr = aggregate_array(1);
      break;
     default: 
      e = ret * 2;
      for (i = 2; i < e ; i += 2) {
	push_string(make_shared_binary_string(data->str + ovector[i],
					      (int)(ovector[i+1] - ovector[i])));
      }
      arr = aggregate_array(ret-1);
      pop_n_elems(args);
    }
    push_array(arr);
    break;
  }
  free(ovector);
}

static void free_regexp(struct object *o)
{
  if(THIS->pattern) { free_string(THIS->pattern); }
  if(THIS->regexp)  { pcre_free(THIS->regexp);    }
  if(THIS->extra)   { pcre_free(THIS->extra);     }
  MEMSET(THIS, 0, sizeof(PCRE_Regexp));
}

static void init_regexp(struct object *o)
{
  MEMSET(THIS, 0, sizeof(PCRE_Regexp));
}

#endif /* HAVE_PCRE */

/* Init the module */
void pike_module_init(void)
{
#ifdef HAVE_PCRE

#ifdef PEXTS_VERSION
  pexts_init();
#endif

  start_new_program();
  ADD_STORAGE( PCRE_Regexp  );
  ADD_FUNCTION( "create", f_pcre_create,
		tFunc(tOr(tStr,tVoid) tOr(tStr,tVoid), tVoid), 0);
  ADD_FUNCTION("match", f_pcre_match,
	       tFunc(tStr tOr(tStr,tVoid), tInt), 0);
  ADD_FUNCTION("split", f_pcre_split,
	       tFunc(tStr tOr(tStr,tVoid), tArr(tStr)), 0);
  set_init_callback(init_regexp);
  set_exit_callback(free_regexp);
  end_class("Regexp", 0);
  add_integer_constant("version", 2, 0);
#endif
}

/* Restore and exit module */
void pike_module_exit( void )
{
}

/*
 * Local variables:
 * c-basic-offset: 2
 * End:
 */
