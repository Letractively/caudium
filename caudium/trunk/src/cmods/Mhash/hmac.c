/*
 * Pike Extension Modules - A collection of modules for the Pike Language
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

/* Glue for the MHash library, for various hashing routines. See
 * http://mhash.sourceforge.net/ for more information about mhash.
 */

#include "global.h"
RCSID("$Id$");

#include "stralloc.h"
#include "pike_macros.h"
#include "module_support.h"
#include "program.h"
#include "error.h"
#include "threads.h"
#include "mhash_config.h"

#ifdef HAVE_MHASH
/* Initialize this hash. If it fails, return != 0 */
static int init_hmac(void)
{
  if(THIS->hmac != NULL) { return HMAC_LIVE; }
  if(THIS->type == -1)   { return HMAC_TYPE; }
  if(THIS->pw   == NULL) { return HMAC_PASS; }
  if(THIS->res  != NULL) { return HMAC_DONE; }
  THIS->hmac = mhash_hmac_init(THIS->type, THIS->pw->str, 
			       THIS->pw->len << THIS->pw->size_shift,
			       mhash_get_hash_pblock(THIS->type));
  if(THIS->hmac == MHASH_FAILED) {
    THIS->hmac = NULL;
    return HMAC_FAIL;
  }
  return HMAC_OK;
}

/* Create a new hmac object.  */

  void f_hmac_create(INT32 args)
{
  if(THIS->type != -1 || THIS->hmac || THIS->res) {
    error("Recursive call to create. Use Mhash.HMAC()->reset() or \n"
	  "Mhash.HMAC()->set_type() to change the hash type or reset\n"
	  "the object.\n");
  }
  switch(args) {
  default:
    error("Invalid number of arguments to Mhash.HMAC(), expected 0 or 1.\n");
    break;
  case 1:
    if(sp[-args].type != T_INT) {
      error("Invalid argument 1. Expected integer.\n");
    }
    THIS->type = sp[-args].u.integer;
    THIS->hmac = mhash_init(THIS->type);
    if(THIS->hmac == MHASH_FAILED) {
      THIS->hmac = NULL;
      error("Failed to initialize hash.\n");
    }
    break;
  case 0:
    break;
  }
  
  pop_n_elems(args);
}

/* Set the HMAC password */
void f_hmac_set_password(INT32 args) 
{
  int ret;
  if(args == 1) {
    if(sp[-args].type != T_STRING) {
      error("Invalid argument 1. Expected string.\n");
    }
    if(THIS->pw) free_string(THIS->pw);
    THIS->pw = sp[-args].u.string;
    add_ref(THIS->pw);
    ret = init_hmac();
    if(ret == HMAC_LIVE) {
      error("Hash generation already in progress. Password change will not take\n"
	    "affect until HMAC object is reset.\n");
    }
  } else {
    error("Invalid number of arguments to Mhash.HMAC->feed(), expected 1.\n");
  }
  pop_n_elems(args);
}

/* Add feed to a the hash */
void f_hmac_feed(INT32 args) 
{
  int ret;
  ret = init_hmac();
  switch(ret) {
   case HMAC_TYPE:
    error("The hash type is not set. Use Mhash.HMAC()->set_type() "
	  "to set it.\n");
   case HMAC_PASS:
    error("The HMAC password is missing. Use Mhash.HMAC()->set_password() "
	  "to set it.\n");
   case HMAC_FAIL:
    error("Failed to initialize the hash due to an unknown error.\n");
   case HMAC_DONE:
    error("Hash is ended. Use Mhash.HMAC()->reset() to reset the hash.\n");
   case HMAC_OK:
   case HMAC_LIVE:
    /* Ready to go! */
    if(args == 1) {
      if(sp[-args].type != T_STRING) {
	error("Invalid argument 1. Expected string.\n");
      }
      mhash(THIS->hmac, sp[-args].u.string->str,
	    sp[-args].u.string->len << sp[-args].u.string->size_shift);
    } else {
      error("Invalid number of arguments to Mhash.HMAC->feed(), expected 1.\n");
    }
  }
  pop_n_elems(args);
}

static int get_digest(void)
{
  if(THIS->res == NULL && THIS->hmac != NULL) {
    THIS->res = mhash_hmac_end(THIS->hmac);
    THIS->hmac = NULL;
  }
  if(THIS->res == NULL) {
    error("No hash result available!\n");
  }
  return mhash_get_block_size(THIS->type);
}

void f_hmac_digest(INT32 args)
{
  int len, i;
  struct pike_string *res;
  len = get_digest();
  res = begin_shared_string(len);
  for(i = 0; i < len; i++) {
    STR0(res)[i] = THIS->res[i];
  }
  res = end_shared_string(res);
  pop_n_elems(args);
  push_string(res);
}

void f_hmac_hexdigest(INT32 args)
{
  int len, i, e;
  char hex[3];
  struct pike_string *res;
  len = get_digest();
  res = begin_shared_string(len*2);
  for(e = 0, i = 0; i < len; i++, e+=2) {
    snprintf(hex, 3, "%.2x", THIS->res[i]);
    STR0(res)[e] = hex[0];
    STR0(res)[e+1] = hex[1];
  }
  res = end_shared_string(res);
  pop_n_elems(args);
  push_string(res);
}


/* Reset the hash */
void f_hmac_reset(INT32 args)
{
  int ret;
  free_hash();
  ret = init_hmac();
  if(ret == HMAC_FAIL) {
    error("Failed to initialize hash.\n");
  }
  pop_n_elems(args);
}

/* Change hash type */
void f_hmac_set_type(INT32 args)
{
  int ret;
  if(args == 1) {
    if(sp[-args].type != T_INT) {
      error("Invalid argument 1. Expected integer.\n");
    }
    if(mhash_get_hash_pblock(sp[-args].u.integer) == 0)
    {
      error("The selected hash is invalid or doesn't support HMAC mode.\n");
    }
    THIS->type = sp[-args].u.integer;
  } else {
    error("Invalid number of arguments to Mhash.HMAC()->set_type, expected 1.\n");
  }
  free_hash();
  ret = init_hmac();
  if(ret == HMAC_FAIL) {
    error("Failed to initialize hash.\n");
  }
  pop_n_elems(args);
}

void mhash_init_hmac_program(void) {
  start_new_program();
  ADD_STORAGE( mhash_storage  );
  ADD_FUNCTION("create", f_hmac_create,   tFunc(tOr(tInt,tVoid),tVoid), 0);
  ADD_FUNCTION("set_password", f_hmac_set_password, tFunc(tStr,tVoid), 0);
  ADD_FUNCTION("update", f_hmac_feed,   	tFunc(tStr,tVoid), 0 ); 
  ADD_FUNCTION("feed", f_hmac_feed,     	tFunc(tStr,tVoid), 0 );
  ADD_FUNCTION("digest", f_hmac_digest, 	tFunc(tVoid,tStr), 0);
  ADD_FUNCTION("hexdigest", f_hmac_hexdigest, 	tFunc(tVoid,tStr), 0 ); 
  ADD_FUNCTION("query_name", f_hash_query_name, tFunc(tVoid,tStr), 0 ); 
  ADD_FUNCTION("reset", f_hmac_reset,   	tFunc(tVoid,tVoid), 0 ); 
  ADD_FUNCTION("set_type", f_hmac_set_type, 	tFunc(tVoid,tVoid), 0 ); 
  set_init_callback(init_hash_storage);
  set_exit_callback(free_hash_storage);
  end_class("HMAC", 0);
}

#endif
