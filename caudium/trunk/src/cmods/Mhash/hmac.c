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

#include "pexts.h"
#include "mhash_config.h"

#ifdef HAVE_MHASH
//! class: Mhash.HMAC
//!  The Mhash library supports HMAC generation (a mechanism for message
//!  authentication using cryptographic hash functions, which is
//!  described in rfc2104). HMAC can be used to create message
//!  digests using a secret key, so that these message digests
//!  cannot be regenerated (or replaced) by someone else.  
//! see_also: Mhash.Hash



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

//! method: void create(int|void type)
//!  Called when instantiating a new object. It takes an optional first
//!  argument with the type of hash to use.
//! arg: int|void type
//!  The hash type to use. Can also be set with set_type();
//! name: create - Create a new hash instance.

void f_hmac_create(INT32 args)
{
  if(THIS->type != -1 || THIS->hmac || THIS->res) {
    Pike_error("Recursive call to create. Use Mhash.HMAC()->reset() or \n"
	  "Mhash.HMAC()->set_type() to change the hash type or reset\n"
	  "the object.\n");
  }
  switch(args) {
  default:
    Pike_error("Invalid number of arguments to Mhash.HMAC(), expected 0 or 1.\n");
    break;
  case 1:
    if(sp[-args].type != T_INT) {
      Pike_error("Invalid argument 1. Expected integer.\n");
    }
    THIS->type = sp[-args].u.integer;
    THIS->hmac = mhash_init(THIS->type);
    if(THIS->hmac == MHASH_FAILED) {
      THIS->hmac = NULL;
      Pike_error("Failed to initialize hash.\n");
    }
    break;
  case 0:
    break;
  }
  
  pop_n_elems(args);
}

//! method: void create(string key)
//!  Set the secret key to use when generating the HMAC.
//! arg: string key
//!  The secret key, or password, to use.
//! name: set_key - Set the HMAC secret key
void f_hmac_set_key(INT32 args) 
{
  int ret;
  if(args == 1) {
    if(sp[-args].type != T_STRING) {
      Pike_error("Invalid argument 1. Expected string.\n");
    }
    if(THIS->pw) free_string(THIS->pw);
    THIS->pw = sp[-args].u.string;
    add_ref(THIS->pw);
    ret = init_hmac();
    if(ret == HMAC_LIVE) {
      Pike_error("Hash generation already in progress. Password change will not take\n"
	    "affect until HMAC object is reset.\n");
    }
  } else {
    Pike_error("Invalid number of arguments to Mhash.HMAC->feed(), expected 1.\n");
  }
  pop_n_elems(args);
}

//! method: void feed(string data)
//! method: void update(string data)
//!  Update the current hash context with data.
//!  update() is here for compatibility reasons with Crypto.md5.
//! arg: string data
//!  The data to update the context with.
//! name: feed - Update the current hash context.
void f_hmac_feed(INT32 args) 
{
  int ret;
  ret = init_hmac();
  switch(ret) {
   case HMAC_TYPE:
    Pike_error("The hash type is not set. Use Mhash.HMAC()->set_type() "
	  "to set it.\n");
   case HMAC_PASS:
    Pike_error("The HMAC password is missing. Use Mhash.HMAC()->set_key() "
	  "to set it.\n");
   case HMAC_FAIL:
    Pike_error("Failed to initialize the hash due to an unknown error.\n");
   case HMAC_DONE:
    Pike_error("Hash is ended. Use Mhash.HMAC()->reset() to reset the hash.\n");
   case HMAC_OK:
   case HMAC_LIVE:
    /* Ready to go! */
    if(args == 1) {
      if(sp[-args].type != T_STRING) {
	Pike_error("Invalid argument 1. Expected string.\n");
      }
      mhash(THIS->hmac, sp[-args].u.string->str,
	    sp[-args].u.string->len << sp[-args].u.string->size_shift);
    } else {
      Pike_error("Invalid number of arguments to Mhash.HMAC->feed(), expected 1.\n");
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
    Pike_error("No hash result available!\n");
  }
  return mhash_get_block_size(THIS->type);
}

//! method: string digest()
//! method: string hexdigest()
//!  Get the result of the hashing operation. digest() returns a binary string.
//!  You can use Mhash.to_hex to convert it to hexadecimal format.
//! name: digest, hexdigest - Return the resulting hash
//! see_also: to_hex
//! returns:
//!   The resulting digest.

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

//! method: string query_name()
//!  Get the name of the selected hash routine. 
//! name: query_name - Get hash routine name
//! returns: 
//!  The name of the selected hash routine, zero if none is selected or
//!  -1 if the selected hash is invalid.
/* Same function that's in the mhash object so docs are repeated here but
 * the function is not.
 */

//! method: void reset()
//!  Clean up the current hash context and start from the beginning. Use
//!  this if you want to hash another string. 
//! name: reset - Reset hash context
//! note:
//!  This will note reset the chosen password.
void f_hmac_reset(INT32 args)
{
  int ret;
  free_hash();
  ret = init_hmac();
  if(ret == HMAC_FAIL) {
    Pike_error("Failed to initialize hash.\n");
  }
  pop_n_elems(args);
}


//! method: void set_type(int type)
//!  Set or change the type of the has in the current context.
//!  This function will also reset any hashing in progress.
//! name: set_type - Change the HMAC hash type
void f_hmac_set_type(INT32 args)
{
  int ret;
  if(args == 1) {
    if(sp[-args].type != T_INT) {
      Pike_error("Invalid argument 1. Expected integer.\n");
    }
    if(mhash_get_hash_pblock(sp[-args].u.integer) == 0)
    {
      Pike_error("The selected hash is invalid or doesn't support HMAC mode.\n");
    }
    THIS->type = sp[-args].u.integer;
  } else {
    Pike_error("Invalid number of arguments to Mhash.HMAC()->set_type, expected 1.\n");
  }
  free_hash();
  ret = init_hmac();
  if(ret == HMAC_FAIL) {
    Pike_error("Failed to initialize hash.\n");
  }
  pop_n_elems(args);
}

void mhash_init_hmac_program(void) {
  start_new_program();
  ADD_STORAGE( mhash_storage  );
  ADD_FUNCTION("create", f_hmac_create,   tFunc(tOr(tInt,tVoid),tVoid), 0);
  ADD_FUNCTION("set_key", f_hmac_set_key, tFunc(tStr,tVoid), 0);
  ADD_FUNCTION("update", f_hmac_feed,   	tFunc(tStr,tVoid), 0 ); 
  ADD_FUNCTION("feed", f_hmac_feed,     	tFunc(tStr,tVoid), 0 );
  ADD_FUNCTION("digest", f_hmac_digest, 	tFunc(tVoid,tStr), 0);
  ADD_FUNCTION("query_name", f_hash_query_name, tFunc(tVoid,tStr), 0 ); 
  ADD_FUNCTION("reset", f_hmac_reset,   	tFunc(tVoid,tVoid), 0 ); 
  ADD_FUNCTION("set_type", f_hmac_set_type, 	tFunc(tVoid,tVoid), 0 ); 
  set_init_callback(init_hash_storage);
  set_exit_callback(free_hash_storage);
  end_class("HMAC", 0);
}

#endif
