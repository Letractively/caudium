/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Project
 * Copyright � 2000 Roxen Internet Software
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

/* The Perl module from Pike 7.1 */

#define NO_PIKE_SHORTHAND

#include "global.h"
RCSID("$Id$");
#include "caudium_util.h"

#include "perl_machine.h"

#ifdef HAVE_PERL

/* #define PERL_560 1 */

#include <EXTERN.h>
#include <perl.h>

#ifdef USE_THREADS
/* #error Threaded Perl not supported. */
#endif

#define MY_XS 1
#undef MY_XS

/* #define PIKE_PERLDEBUG */

#ifdef MY_XS
EXTERN_C void boot_DynaLoader();

static void xs_init()
{ char *file = __FILE__;
  dXSUB_SYS;
#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[my xs_init]\n");
#endif
  newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
}
#endif


/* Do not redefine my malloc macro you stupid Perl! */
#include "dmalloc.h"

  /* this is just for debugging */
#define _sv_2mortal(x) (sv_2mortal(x))

static int num_perl_interpreters=0;
DEFINE_MUTEX(perlrunning);

#ifdef MULTIPLICITY
#endif

struct perlmod_storage
{
  char **argv;
  char **env;
  char *env_block;
  struct array *argv_strings;
  int constructed, parsed;
  int array_size_limit;
  PerlInterpreter *perl;
};

#define _THIS ((struct perlmod_storage *)(Pike_fp->current_storage))

#ifdef PERL_560
#define my_perl PERL
#endif

#define BLOCKING 1

#ifndef BLOCKING

#define MT_PERMIT THREADS_ALLOW(); mt_lock(&perl_running);
#define MT_FORBID mt_unlock(&perl_running); THREADS_DISALLOW();

#else

#define MT_PERMIT ;
#define MT_FORBID ;

#endif

/* utility function: push a zero_type zero */
static void _push_zerotype()
{ push_int(0);
  Pike_sp[-1].subtype = 1;
}

static SV * _pikev2sv(struct svalue *s)
{ switch (s->type)
  { case PIKE_T_INT:
      return newSViv(s->u.integer); break;
    case PIKE_T_FLOAT:
      return newSVnv(s->u.float_number); break;
    case PIKE_T_STRING:
      if (s->u.string->size_shift) break;
      return newSVpv(s->u.string->str, s->u.string->len); break;
  }
  Pike_error("Unsupported value type.\n");
  return 0;
}

static void _sv_to_svalue(SV *sv, struct svalue *sval)
{ if (sv && (SvOK(sv)))
  { if (SvIOKp(sv))
    { sval->type = PIKE_T_INT; sval->subtype = 0;
      sval->u.integer = SvIV(sv);
      return;
    }
    else if (SvNOKp(sv))
    { sval->type = PIKE_T_FLOAT; sval->subtype = 0;
      sval->u.float_number = SvNV(sv);
      return;
    }
    else if (SvPOKp(sv))
    { sval->type = PIKE_T_STRING; sval->subtype = 0;
      sval->u.string = make_shared_binary_string(SvPVX(sv), SvCUR(sv));
      return;
    }
  }
  sval->type = PIKE_T_INT; sval->u.integer = 0;
  sval->subtype = !sv; /* zero-type zero if NULL pointer */
}

static void _pikepush_sv(SV *sv)
{ if (!SvOK(sv))
     push_int(0);
  else if (SvIOKp(sv))
     push_int(SvIV(sv));
  else if (SvNOKp(sv))
     push_float((float)(SvNV(sv)));
  else if (SvPOKp(sv))
     push_string(make_shared_binary_string(SvPVX(sv), SvCUR(sv)));
  else
     push_int(0);
}

static int _perl_parse(struct perlmod_storage *ps,
                          int argc, char *argv[], char *envp[])
{ int result;
#ifndef MY_XS
  extern void xs_init(void);
#endif
#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[_perl_parse, argc=%d]\n", argc);
#endif

  if (!ps)
         Pike_error("Internal error: no Perl storage allocated.\n");
  if (!ps->perl)
         Pike_error("Internal error: no Perl interpreter allocated.\n");
  if (!ps->constructed)
         Pike_error("Internal error: Perl interpreter not constructed.\n");
  if (!envp && !ps->env)
  { /* Copy environment data, since Perl may wish to modify it. */

    INT32 d;
    int env_block_size=0;
    char *env_blockp;

#ifdef DECLARE_ENVIRON
    extern char **environ;
#endif

    for(d=0;environ[d];d++)
      env_block_size+=strlen(environ[d])+1;

    if (env_block_size)
      ps->env_block=xalloc(env_block_size);
    else
      ps->env_block = NULL;
    ps->env=(char **)xalloc(sizeof(char *)*(d+1));

    env_blockp = ps->env_block;

    for(d=0;environ[d];d++)
    {
      int l=strlen(environ[d]);
      ps->env[d]=env_blockp;
      MEMCPY(env_blockp,environ[d],l+1);
      env_blockp+=l+1;
    }

#ifdef PIKE_DEBUG
    if(env_blockp - ps->env_block > env_block_size)
      fatal("Arglebargle glop-glyf.\n");
#endif

    ps->env[d]=0;
  }
  MT_PERMIT;
  result = perl_parse(ps->perl, xs_init, argc, argv, envp ? envp : ps->env);
  MT_FORBID;
  ps->parsed += 1;
  return result;
}

static char *dummyargv[] = { "perl", "-e", "1", 0 };

static void init_perl_glue(struct object *o)
{ struct perlmod_storage *ps = _THIS;

#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[init_perl_glue]\n");
#endif

  ps->argv             = 0;
  ps->env              = 0;
  ps->env_block        = 0;
  ps->argv_strings     = 0;
  ps->constructed      = 0;
  ps->parsed           = 0;
  ps->array_size_limit = 500;

#ifndef MULTIPLICITY
  if(num_perl_interpreters>0)
  {
    ps->perl=0;
#ifdef PIKE_PERLDEBUG
    fprintf(stderr,"num_perl_interpreters=%d\n",num_perl_interpreters);
#endif
    /*    Pike_error("Perl: There can be only one!\n"); */
    return;
  }
#endif
  MT_PERMIT;
  ps->perl = perl_alloc();
  PL_perl_destruct_level=2;
  MT_FORBID;
  if(ps->perl) num_perl_interpreters++;

/* #define SPECIAL_PERL_DEBUG */
#ifdef SPECIAL_PERL_DEBUG
  if (!ps->constructed)
  { fprintf(stderr, "[SpecialDebug: early perl_construct]\n");
    perl_construct(ps->perl);
    ps->constructed = 1;
  }
  if (!ps->parsed)
  { fprintf(stderr, "[SpecialDebug: early perl_parse]\n");
    perl_parse(ps->perl, xs_init, 3, dummyargv, NULL);
    ps->parsed = 1;
  }
#endif
}

static void _free_arg_and_env()
{ struct perlmod_storage *ps = _THIS;

  if (ps->argv)
  { free((char *)ps->argv);
    ps->argv=0;
  }

  if (ps->argv_strings)
  { free_array(ps->argv_strings);
    ps->argv_strings=0;
  }

  if (ps->env)
  { free((char *)ps->env);
    ps->env=0;
  }

  if (ps->env_block)
  { free((char *)ps->env_block);
    ps->env_block=0;
  }
}

static void exit_perl_glue(struct object *o)
{ struct perlmod_storage *ps = _THIS;
#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[exit_perl_glue]\n");
#endif

  if (ps->perl)
  {
    if (ps->constructed)
    {
      if (!ps->parsed)
      { /* This should be unnecessary, but for some reason, some
         * perl5.004 installations dump core if we don't do this.
         */
        _perl_parse(ps, 3, dummyargv, NULL);
      }
      perl_destruct(ps->perl);
      ps->constructed = 0;
    }
    MT_PERMIT;
    perl_free(ps->perl);
    MT_FORBID;
    num_perl_interpreters--;
  }
  _free_arg_and_env();
}

static void perlmod_create(INT32 args)
{ struct perlmod_storage *ps = _THIS;

#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[perlmod_create, %d args]\n", args);
#ifdef MY_XS
  fprintf(stderr, "[has MY_XS]\n");
#endif
#endif
    
  if (args != 0) Pike_error("Perl->create takes no arguments.");
  if (!ps || !ps->perl) Pike_error("No perl interpreter available.\n");

  MT_PERMIT;
  if(!ps->constructed)
  { perl_construct(ps->perl);
    ps->constructed++;
  }
  if (!ps->parsed)
  {
    _perl_parse(ps, 3, dummyargv, NULL);
  }
  MT_FORBID;
  pop_n_elems(args);
  push_int(0);
}

static void perlmod_parse(INT32 args)
{
  int e;
  struct mapping *env_mapping=0;
  struct perlmod_storage *ps = _THIS;
#ifndef MY_XS
  extern void xs_init(void);
#endif

#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[perlmod_parse, %d args]\n", args);
#endif
    
  check_all_args("Perl->parse",args,BIT_ARRAY, BIT_MAPPING|BIT_VOID, 0);
  if(!ps->perl) Pike_error("No perl interpreter available.\n");

  switch(args)
  {
    default:
      env_mapping = Pike_sp[1-args].u.mapping;
      mapping_fix_type_field(env_mapping);

      if(m_ind_types(env_mapping) & ~BIT_STRING)
	Pike_error("Bad argument 2 to Perl->create().\n");
      if(m_val_types(env_mapping) & ~BIT_STRING)
	Pike_error("Bad argument 2 to Perl->create().\n");
      
    case 1:
      if (_THIS->argv_strings || _THIS->env_block)
      { /* if we have already setup args/env, free the old values now */
        _free_arg_and_env();
      }

      ps->argv_strings = Pike_sp[-args].u.array;
      add_ref(ps->argv_strings);
      array_fix_type_field(ps->argv_strings);

      if(ps->argv_strings->size<2)
	   Pike_error("Perl: Too few elements in argv array.\n");

      if(ps->argv_strings->type_field & ~BIT_STRING)
	   Pike_error("Bad argument 1 to Perl->parse().\n");
  }

  ps->argv=(char **)xalloc(sizeof(char *)*ps->argv_strings->size);
  for(e=0;e<ps->argv_strings->size;e++)
    ps->argv[e]=ITEM(ps->argv_strings)[e].u.string->str;

  if(env_mapping)
  {
    INT32 d;
    int env_block_size=0;
    char *env_blockp;
    struct keypair *k;
    MAPPING_LOOP(env_mapping)
      env_block_size+=k->ind.u.string->len+k->val.u.string->len+2;

    ps->env_block=xalloc(env_block_size);
    ps->env=(char **)xalloc(sizeof(char *)*(m_sizeof(env_mapping)+1));

    env_blockp = ps->env_block;
    d=0;
    MAPPING_LOOP(env_mapping)
      {
	ps->env[d++]=env_blockp;
	MEMCPY(env_blockp,k->ind.u.string->str,k->ind.u.string->len);
	env_blockp+=k->ind.u.string->len;

	*(env_blockp++)='=';

	MEMCPY(env_blockp,k->val.u.string->str,k->ind.u.string->len);
	env_blockp+=k->val.u.string->len;

	*(env_blockp++)=0;
      }
    ps->env[d]=0;
  }
  else ps->env = 0;

  e = _perl_parse(ps, ps->argv_strings->size, ps->argv, ps->env);

  pop_n_elems(args);
  push_int(e);
}

static void perlmod_run(INT32 args)
{
  INT32 i;
  struct perlmod_storage *ps = _THIS;

  if(!ps->perl) Pike_error("No perl interpreter available.\n");
  pop_n_elems(args);

  if(!_THIS->constructed || !_THIS->parsed)
    Pike_error("No Perl program loaded (run() called before parse()).\n");

  MT_PERMIT;
  i=perl_run(ps->perl);
  MT_FORBID;

  push_int(i);
}

static void _perlmod_eval(INT32 args, int perlflags)
{ struct pike_string *firstarg;
  struct perlmod_storage *ps = _THIS;
  int i, n;
// #define sp _perlsp
  dSP;

  if (!ps->perl) Pike_error("Perl interpreter not available.\n");

  check_all_args("Perl->eval", args, BIT_STRING, 0);
  firstarg = Pike_sp[-args].u.string;

  ENTER;
  SAVETMPS;
  PUSHMARK(sp);

  PUTBACK;
// #undef sp

  if (!ps->parsed)
  {
#if 0
    _perl_parse(ps, 3, dummyargv, NULL);
#else
#ifndef MY_XS
    extern void xs_init(void);
#endif
    perl_parse(ps->perl, xs_init, 3, dummyargv, NULL);
#endif
  }

  MT_PERMIT;

/* perl5.6.0 testing: newSVpv((const char *) "ABC", 3); */

  n = perl_eval_sv(newSVpv((firstarg->str),
                           (firstarg->len)),
                    perlflags | G_EVAL);

  MT_FORBID;

  pop_n_elems(args);

// #define sp _perlsp
  SPAGAIN;

  if (SvTRUE(GvSV(PL_errgv)))
  { char errtmp[256];
    memset(errtmp, 0, sizeof(errtmp));
    strcpy(errtmp, "Error from Perl: ");
    strncpy(errtmp+strlen(errtmp),
            SvPV(GvSV(PL_errgv), PL_na),
            254-strlen(errtmp));
    POPs;
    PUTBACK; FREETMPS; LEAVE;
    Pike_error(errtmp);
  }

  if (perlflags & G_ARRAY)
  { struct array *a = allocate_array(n);
    for(i = 0; i < n; ++i)
         _sv_to_svalue(POPs, &(a->item[(n-1)-i]));
    push_array(a);
  }
  else if (n > 0)
  { for(; n > 1; --n) POPs;
    _pikepush_sv(POPs);
  }
  else _push_zerotype();

  PUTBACK; FREETMPS; LEAVE;
// #undef sp
}

static void perlmod_eval(INT32 args)
  { _perlmod_eval(args, G_SCALAR); }

static void perlmod_eval_list(INT32 args)
  { _perlmod_eval(args, G_ARRAY); }

static void _perlmod_call(INT32 args, int perlflags)
{ struct perlmod_storage *ps = _THIS;
  int i, n; char *pv;
// #define sp _perlsp
  dSP;

#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[perlmod_call: args=%d]\n", args);
#endif

  if (!ps->perl) Pike_error("No perl interpreter available.\n");

  if (args <   1) Pike_error("Too few arguments.\n");
  if (args > 201) Pike_error("Too many arguments.\n");

  if (Pike_sp[-args].type != PIKE_T_STRING ||
      Pike_sp[-args].u.string->size_shift)
       Pike_error("bad Perl function name (must be an 8-bit string)");

  ENTER;
  SAVETMPS;
  PUSHMARK(sp);

  for(n = 1; n < args; ++n)
  { struct svalue *s = &(Pike_sp[n-args]);
    char *msg;
    switch (s->type)
    { case PIKE_T_INT:
        XPUSHs(sv_2mortal(newSViv(s->u.integer)));
        break;
      case PIKE_T_FLOAT:
        XPUSHs(sv_2mortal(newSVnv((double)(s->u.float_number))));
        break;
      case PIKE_T_STRING:
        if (s->u.string->size_shift)
        { PUTBACK; FREETMPS; LEAVE;
          Pike_error("widestrings not supported in Pike-to-Perl call interface");
          return;
        }
        XPUSHs(sv_2mortal(newSVpv(s->u.string->str, s->u.string->len)));
        break;
      case PIKE_T_MAPPING:
        msg = "Mapping argument not allowed here.\n"; if (0)
      case PIKE_T_OBJECT:
        msg = "Object argument not allowed here.\n"; if (0)
      case PIKE_T_MULTISET:
        msg = "Multiset argument not allowed here.\n"; if (0)
      case PIKE_T_ARRAY:
        msg = "Array argument not allowed here.\n"; if (0)
      default:
        msg = "Unsupported argument type.\n";
        PUTBACK; FREETMPS; LEAVE;
        Pike_error(msg);
        return;
    }
  }
  PUTBACK;

  pv = Pike_sp[-args].u.string->str;  
// #undef sp
  MT_PERMIT;

  n = perl_call_pv(pv, perlflags);

  MT_FORBID;
// #define sp _perlsp

  pop_n_elems(args);

  SPAGAIN;

  if (SvTRUE(GvSV(PL_errgv)))
  { char errtmp[256];
    memset(errtmp, 0, sizeof(errtmp));
    strcpy(errtmp, "Error from Perl: ");
    strncpy(errtmp+strlen(errtmp),
            SvPV(GvSV(PL_errgv), PL_na),
            254-strlen(errtmp));
    POPs;
    PUTBACK; FREETMPS; LEAVE;
    Pike_error(errtmp);
  }

  if (n < 0)
  { PUTBACK; FREETMPS; LEAVE;
    Pike_error("Internal error: perl_call_pv returned a negative number.\n");
  }

  if (!(perlflags & G_ARRAY) && n > 1)
       while (n > 1) --n, POPs;

  if (n > ps->array_size_limit)
  { PUTBACK; FREETMPS; LEAVE;
    Pike_error("Perl function returned too many values.\n");
  }

  if (perlflags & G_ARRAY)
  { struct array *a = allocate_array(n);
    for(i = 0; i < n; ++i)
         _sv_to_svalue(POPs, &(a->item[(n-1)-i]));
    push_array(a);
  }
  else if (n == 1)
     _pikepush_sv(POPs);
  else /* shouldn't happen unless we put G_DISCARD in perlflags */
     _push_zerotype();

  PUTBACK; FREETMPS; LEAVE;
// #undef sp
}

static void perlmod_call_list(INT32 args)
{ _perlmod_call(args, G_ARRAY | G_EVAL);
}

static void perlmod_call(INT32 args)
{ _perlmod_call(args, G_SCALAR | G_EVAL);
}

static void _perlmod_varop(INT32 args, int op, int type)
{ int i, wanted_args;

  wanted_args = type == 'S' ? 1 : 2;
  if (op == 'W') ++wanted_args;

  if (!(_THIS->perl)) Pike_error("No Perl interpreter available.\n");

  if (args != wanted_args) Pike_error("Wrong number of arguments.\n");
  if (Pike_sp[-args].type != PIKE_T_STRING ||
      Pike_sp[-args].u.string->size_shift != 0)
       Pike_error("Variable name must be an 8-bit string.\n");

  if (type == 'S') /* scalar */
  { SV *sv = perl_get_sv(Pike_sp[-args].u.string->str, TRUE | GV_ADDMULTI);
    if (op == 'W')
      { sv_setsv(sv, sv_2mortal(_pikev2sv(Pike_sp-1)));}
    pop_n_elems(args);
    if (op == 'R') _pikepush_sv(sv);
  }
  else if (type == 'A') /* array */
  { AV *av = perl_get_av(Pike_sp[-args].u.string->str, TRUE | GV_ADDMULTI);
    SV **svp;
    if (Pike_sp[1-args].type != PIKE_T_INT || (i = Pike_sp[1-args].u.integer) < 0)
          Pike_error("Array subscript must be a non-negative integer.\n");
    if (op == 'W')
         av_store(av, i, _sv_2mortal(_pikev2sv(Pike_sp+2-args)));
    pop_n_elems(args);
    if (op == 'R')
    { if ((svp = av_fetch(av, i, 0))) _pikepush_sv(*svp);
                                 else _push_zerotype();
    }
  }
  else if (type == 'H') /* hash */
  { HV *hv = perl_get_hv(Pike_sp[-args].u.string->str, TRUE | GV_ADDMULTI);
    SV *key = sv_2mortal(_pikev2sv(Pike_sp+1-args));
    HE *he;
    if (op == 'W')
    { if ((he = hv_store_ent
                   (hv, key, _sv_2mortal(_pikev2sv(Pike_sp+2-args)), 0)))
         sv_setsv(HeVAL(he), _sv_2mortal(_pikev2sv(Pike_sp+2-args)));
      else
         Pike_error("Internal error: hv_store_ent returned NULL.\n");
    }
    pop_n_elems(args);
    if (op == 'R')
    { if ((he = hv_fetch_ent(hv, key, 0, 0)))
         _pikepush_sv(HeVAL(he));
      else
         _push_zerotype();
    }
  }
  else Pike_error("Internal error in _perlmod_varop.\n");

  if (op != 'R') push_int(0);
}

static void perlmod_get_scalar(INT32 args)
   { _perlmod_varop(args, 'R', 'S');}
static void perlmod_set_scalar(INT32 args)
   { _perlmod_varop(args, 'W', 'S');}
static void perlmod_get_array_item(INT32 args)
   { _perlmod_varop(args, 'R', 'A');}
static void perlmod_set_array_item(INT32 args)
   { _perlmod_varop(args, 'W', 'A');}
static void perlmod_get_hash_item(INT32 args)
   { _perlmod_varop(args, 'R', 'H');}
static void perlmod_set_hash_item(INT32 args)
   { _perlmod_varop(args, 'W', 'H');}

static void perlmod_array_size(INT32 args)
{ AV *av;
  if (args != 1) Pike_error("Wrong number of arguments.\n");
  if (Pike_sp[-args].type != PIKE_T_STRING ||
      Pike_sp[-args].u.string->size_shift != 0)
      Pike_error("Array name must be given as an 8-bit string.\n");

  av = perl_get_av(Pike_sp[-args].u.string->str, TRUE | GV_ADDMULTI);
  if (!av) Pike_error("Interal error: perl_get_av() return NULL.\n");
  pop_n_elems(args);
  /* Return av_len()+1, since av_len() returns the value of the highest
   * index, which is 1 less than the size. */
  push_int(av_len(av)+1);
}

static void perlmod_get_whole_array(INT32 args)
{ AV *av; int i, n; struct array *arr;
  if (args != 1) Pike_error("Wrong number of arguments.\n");
  if (Pike_sp[-args].type != PIKE_T_STRING ||
      Pike_sp[-args].u.string->size_shift != 0)
      Pike_error("Array name must be given as an 8-bit string.\n");

  av = perl_get_av(Pike_sp[-args].u.string->str, TRUE | GV_ADDMULTI);
  if (!av) Pike_error("Interal error: perl_get_av() returned NULL.\n");
  n = av_len(av) + 1;

  if (n > _THIS->array_size_limit)
     Pike_error("The array is larger than array_size_limit.\n");

  arr = allocate_array(n);
  for(i = 0; i < n; ++i)
  { SV **svp = av_fetch(av, i, 0);
    _sv_to_svalue(svp ? *svp : NULL, &(arr->item[i]));
  }
  pop_n_elems(args);
  push_array(arr);
}

static void perlmod_get_hash_keys(INT32 args)
{ HV *hv; HE *he; SV *sv; int i, n; I32 len; struct array *arr;
  if (args != 1) Pike_error("Wrong number of arguments.\n");
  if (Pike_sp[-args].type != PIKE_T_STRING ||
      Pike_sp[-args].u.string->size_shift != 0)
      Pike_error("Hash name must be given as an 8-bit string.\n");

  hv = perl_get_hv(Pike_sp[-args].u.string->str, TRUE | GV_ADDMULTI);
  if (!hv) Pike_error("Interal error: perl_get_av() return NULL.\n");

  /* count number of elements in hash */
  for(n = 0, hv_iterinit(hv); (he = hv_iternext(hv)); ++n);

  if (n > _THIS->array_size_limit)
     Pike_error("The array is larger than array_size_limit.\n");

  arr = allocate_array(n);
  for(i = 0, hv_iterinit(hv); (he = hv_iternext(hv)); ++i)
       _sv_to_svalue(hv_iterkeysv(he), &(arr->item[i]));

  pop_n_elems(args);
  push_array(arr);
}

static void perlmod_array_size_limit(INT32 args)
{ int i;
  switch (args)
  { case 0:
      break;
    case 1:
      if (Pike_sp[-args].type != PIKE_T_INT || Pike_sp[-args].u.integer < 1)
           Pike_error("Argument must be a integer in range 1 to 2147483647.");
      _THIS->array_size_limit = Pike_sp[-args].u.integer;
      break;
    default:
      Pike_error("Wrong number of arguments.\n");
  }
  pop_n_elems(args);
  push_int(_THIS->array_size_limit);
}

void pike_module_init(void)
{
#ifdef PIKE_PERLDEBUG
  fprintf(stderr, "[perl: module init]\n");
#endif

  start_new_program();
  ADD_STORAGE(struct perlmod_storage);
  /* function(void:int) */
  ADD_FUNCTION("create",perlmod_create,tFunc(tVoid,tInt),0);
  /* function(array(string),void|mapping(string:string):int) */
  ADD_FUNCTION("parse",perlmod_parse,tFunc(tArr(tStr) tOr(tVoid,tMap(tStr,tStr)),tInt),0);
  /* function(:int) */
  ADD_FUNCTION("run",perlmod_run,tFunc(tNone,tInt),0);

  /* function(string,mixed...:mixed) */
  ADD_FUNCTION("call",perlmod_call,tFuncV(tStr,tMix,tMix),0);

  /* function(string,mixed...:mixed) */
  ADD_FUNCTION("call_list",perlmod_call_list,tFuncV(tStr,tMix,tMix),0);

  /* function(string:mixed) */
  ADD_FUNCTION("eval",perlmod_eval,tFunc(tStr,tMix),0);

  /* function(string:array) */
  ADD_FUNCTION("eval_list",perlmod_eval_list,tFunc(tStr,tArr(tMix)),0);

  /* function(string:mixed) */
  ADD_FUNCTION("get_scalar",perlmod_get_scalar,tFunc(tStr,tMix),0);

  /* function(string,mixed:mixed) */
  ADD_FUNCTION("set_scalar",perlmod_set_scalar,tFunc(tStr tMix,tMix),0);

  /* function(string,int:mixed) */
  ADD_FUNCTION("get_array_item",perlmod_get_array_item,
               tFunc(tStr tInt,tMix),0);

  /* function(string,int,mixed:mixed) */
  ADD_FUNCTION("set_array_item",perlmod_set_array_item,
               tFunc(tStr tInt tMix,tMix),0);

  /* function(string,mixed:mixed) */
  ADD_FUNCTION("get_hash_item",perlmod_get_hash_item,
               tFunc(tStr tMix,tMix),0);

  /* function(string,mixed,mixed:mixed) */
  ADD_FUNCTION("set_hash_item",perlmod_set_hash_item,
               tFunc(tStr tMix tMix,tMix),0);

  /* function(string:int) */
  ADD_FUNCTION("array_size",perlmod_array_size,
               tFunc(tStr,tInt),0);

  /* function(string:int) */
  ADD_FUNCTION("get_array",perlmod_get_whole_array,
               tFunc(tStr,tArr(tMix)),0);

  /* function(string:int) */
  ADD_FUNCTION("get_hash_keys",perlmod_get_hash_keys,
               tFunc(tStr,tArr(tMix)),0);

#if 0
  /* function(string,array:array) */
  ADD_FUNCTION("set_array", perlmod_set_whole_array,
               tFunc(tStr tArr(tMix),tArr(tMix)),0);
#endif

  /* function(void|int:int) */
  ADD_FUNCTION("array_size_limit",perlmod_array_size_limit,
        tFunc(tOr(tVoid,tInt),tInt),0);

  set_init_callback(init_perl_glue);
  set_exit_callback(exit_perl_glue);
  end_class("Perl",0);

  add_integer_constant("MULTIPLICITY",
#ifdef MULTIPLICITY
                       1,
#else
                       0,
#endif
                       0);
}

void pike_module_exit(void)
{
}

#else /* HAVE_PERL */

#ifdef ERROR_IF_NO_PERL
#error "No Perl!"
#endif

void pike_module_init(void) {}
void pike_module_exit(void) {}
#endif
