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

//! class: Mhash.Hash
//!  An instance of a normal Mhash object. This object can be used to
//!  calculate various hashes supported by the Mhash library.
//! see_also: Mhash.HMAC
//! method: void create(int|void type)
//!  Called when instantiating a new object. It takes an optional first
//!  argument with the type of hash to use.
//! arg: int|void type
//!  The hash type to use. Can also be set with set_type();
//! name: create - Create a new hash instance.

void f_hash_create(INT32 args)
{
  if(THIS->type != -1 || THIS->hash || THIS->res) {
    Pike_error("Recursive call to create. Use Mhash.Hash()->reset() or \n"
	  "Mhash.Hash()->set_type() to change the hash type or reset\n"
	  "the object.\n");
  }
  switch(args) {
  default:
    Pike_error("Invalid number of arguments to Mhash.Hash(), expected 0 or 1.\n");
    break;
  case 1:
    if(sp[-args].type != T_INT) {
      Pike_error("Invalid argument 1. Expected integer.\n");
    }
    THIS->type = sp[-args].u.integer;
    break;
  case 0:
    break;
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
void f_hash_feed(INT32 args) 
{
  if(THIS->hash == NULL) {
    if(THIS->type != -1)
      Pike_error("Hash is ended. Use Mhash.Hash()->reset() to reset the hash.\n");
    else
      Pike_error("Hash is uninitialized. Use Mhash.Hash()->set_type() to select hash type.\n");
  }
  if(args == 1) {
    if(sp[-args].type != T_STRING) {
      Pike_error("Invalid argument 1. Expected string.\n");
    }
    mhash(THIS->hash, sp[-args].u.string->str,
	  sp[-args].u.string->len << sp[-args].u.string->size_shift);
  } else {
    Pike_error("Invalid number of arguments to Mhash.Hash->feed(), expected 1.\n");
  }
  pop_n_elems(args);
}

static int get_digest(void)
{
  if(THIS->res == NULL && THIS->hash != NULL) {
    THIS->res = mhash_end(THIS->hash);
    THIS->hash = NULL;
  }
  if(THIS->res == NULL) {
    Pike_error("No hash result available!\n");
  }
  return mhash_get_block_size(THIS->type);
}

//! method: string digest()
//!  Get the result of the hashing operation. 
//! name: digest, hexdigest - Return the resulting hash
//! see_also: Mhash.to_hex
//! returns:
//!   The resulting digest.
void f_hash_digest(INT32 args)
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
void f_hash_query_name(INT32 args)
{
  char *name;
  pop_n_elems(args);
  if(THIS->type != -1) {
    name = mhash_get_hash_name(THIS->type);
    if(name == NULL) {
      push_int(-1);
    } else {
      push_text(name);
      free(name);
    }
  } else {
    push_int(0);
  }
}

//! method: void reset()
//!  Clean up the current hash context and start from the beginning. Use
//!  this if you want to hash another string.
//! name: reset - Reset hash context
void f_hash_reset(INT32 args)
{
  free_hash();
  if(THIS->type != -1) {
    THIS->hash = mhash_init(THIS->type);
    if(THIS->hash == MHASH_FAILED) {
      THIS->hash = NULL;
      Pike_error("Failed to initialize hash.\n");
    }
  }
  pop_n_elems(args);
}

//! method: void set_type(int type)
//!  Set or change the type of the has in the current context.
//!  This function will also reset any hashing in progress.
//! name: set_type - Change the hash type
void f_hash_set_type(INT32 args)
{
  if(args == 1) {
    if(sp[-args].type != T_INT) {
      Pike_error("Invalid argument 1. Expected integer.\n");
    } 
    THIS->type = sp[-args].u.integer;
  } else {
    Pike_error("Invalid number of arguments to Mhash.Hash()->set_type, expected 1.\n");
  }
  free_hash();
  if(THIS->type != -1) {
    THIS->hash = mhash_init(THIS->type);
    if(THIS->hash == MHASH_FAILED) {
      THIS->hash = NULL;
      Pike_error("Failed to initialize hash.\n");
    }
  }
  pop_n_elems(args);
}

void mhash_init_mhash_program(void) {
  start_new_program();
  ADD_STORAGE( mhash_storage  );
  ADD_FUNCTION("create", f_hash_create,   tFunc(tOr(tInt,tVoid),tVoid), 0);
  ADD_FUNCTION("update", f_hash_feed,   	tFunc(tStr,tVoid), 0 ); 
  ADD_FUNCTION("feed", f_hash_feed,     	tFunc(tStr,tVoid), 0 );
  ADD_FUNCTION("digest", f_hash_digest, 	tFunc(tVoid,tStr), 0);
  ADD_FUNCTION("query_name", f_hash_query_name, tFunc(tVoid,tStr), 0 ); 
  ADD_FUNCTION("reset", f_hash_reset,   	tFunc(tVoid,tVoid), 0 ); 
  ADD_FUNCTION("set_type", f_hash_set_type, 	tFunc(tVoid,tVoid), 0 ); 
  set_init_callback(init_hash_storage);
  set_exit_callback(free_hash_storage);
  end_class("Hash", 0);
}

#endif
