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
#include "mhash_quick.h"

//! class: Mhash
//!  Mhash is an open source library which provides a uniform interface
//!  to a large number of hash algorithms. These algorithms can be used
//!  to compute checksums,message digests, and other signatures. The HMAC
//!  support implements the basics for message authentication, following
//!  RFC 2104. This is the Mhash glue.

//! method: string query_name(int type)
//!  Return the name of the hash with the specified type.
//! arg: int type
//!  The type of the hash. Normally accessed through Mhash.MD5,
//!  Mhash.HAVAL128 etc.
//! returns:
//!  The name of the hash.
void f_query_name(INT32 args)
{
  char *name;
  if(args == 1) {
    if(sp[-args].type != T_INT) {
      error("Invalid argument 1. Expected integer.\n");
    } 
    name = mhash_get_hash_name(sp[-args].u.integer);
    pop_n_elems(args);
    if(name == NULL) {
      push_int(0);
    } else {
      push_text(name);
      free(name);
    }
  } else {
    error("Invalid number of arguments to Mhash.Hash()->set_type, expected 1.\n");
  }
}
 
QUICKHASH(crc32, MHASH_CRC32);
QUICKHASH(crc32b, MHASH_CRC32B);
QUICKHASH(gost, MHASH_GOST);
QUICKHASH(haval128, MHASH_HAVAL128);
QUICKHASH(haval160, MHASH_HAVAL160);
QUICKHASH(haval192, MHASH_HAVAL192);
QUICKHASH(haval224, MHASH_HAVAL224);
QUICKHASH(haval256, MHASH_HAVAL256);
QUICKHASH(md5,MHASH_MD5);
QUICKHASH(ripemd160, MHASH_RIPEMD160);
QUICKHASH(sha1, MHASH_SHA1);
QUICKHASH(tiger, MHASH_TIGER);



//! method: string to_hex(string bin)
//!  Convert a hash result to hexadecimal format from binary format.
//!  This is useful if you want to use safe characters only.
//! arg: string bin
//!  The binary string to convert.
//! returns:
//!  The hexadecimal representation of bin.
void f_to_hex(INT32 args)
{
  unsigned char *res, hex[3];
  struct pike_string *str;
  int len, i, e;
  if(args != 1 && sp[-1].type != T_STRING) {
    error("Invalid / incorrect args to to_hex. Expected string.\n");
  }
  len = sp[-1].u.string->len << sp[-1].u.string->size_shift;
  str = begin_shared_string(len*2);
  res = (unsigned char *)sp[-1].u.string->str;
  for(e = 0, i = 0; i < len; i++, e+=2) { 
    snprintf(hex, 3, "%.2x", res[i]); 
    STR0(str)[e] = hex[0]; 
    STR0(str)[e+1] = hex[1]; 
  }
  str = end_shared_string(str);
  pop_n_elems(args);
  push_string(str);
}

void mhash_init_globals(void) {
  add_function("query_name", f_query_name, "function(int:string)", 0 ); 
  add_function("to_hex", f_to_hex, "function(string:string)", 0 ); 

  ADDQHASH(crc32);     ADDQHASH(crc32b);    ADDQHASH(gost);
  ADDQHASH(haval128);  ADDQHASH(haval160);  ADDQHASH(haval192);
  ADDQHASH(haval224);  ADDQHASH(haval256);  ADDQHASH(md5);
  ADDQHASH(ripemd160); ADDQHASH(sha1);      ADDQHASH(tiger);
  
  add_integer_constant("CRC32", MHASH_CRC32, 0);
  add_integer_constant("MD5", MHASH_MD5, 0);
  add_integer_constant("SHA1", MHASH_SHA1, 0);
  add_integer_constant("HAVAL256", MHASH_HAVAL256, 0);
  add_integer_constant("RIPEMD160", MHASH_RIPEMD160, 0);
  add_integer_constant("TIGER", MHASH_TIGER, 0);
  add_integer_constant("GOST", MHASH_GOST, 0);
  add_integer_constant("CRC32B", MHASH_CRC32B, 0);
  add_integer_constant("HAVAL192", MHASH_HAVAL192, 0);
  add_integer_constant("HAVAL160", MHASH_HAVAL160, 0);
  add_integer_constant("HAVAL128", MHASH_HAVAL128, 0);
  add_integer_constant("HAVAL224", MHASH_HAVAL224, 0);
#if 0
  /* Not existing yet...  */
  add_integer_constant("SNEFRU", MHASH_SNEFRU, 0);
  add_integer_constant("MD2", MHASH_MD2, 0);
#endif
}


/* Free allocated data in a hash object */

void free_hash(void)
{
  if(THIS->hash != NULL) {
    void *tmp = mhash_end(THIS->hash);
    if(tmp != NULL) free(tmp);
    THIS->hash = NULL;
  }
  if(THIS->hmac != NULL) {
    void *tmp = mhash_hmac_end(THIS->hmac);
    if(tmp != NULL) free(tmp);
    THIS->hmac = NULL;
  }
  if(THIS->res != NULL) {
    free(THIS->res);
    THIS->res = NULL;
  }
}

/* Free the hash storage */
void free_hash_storage(struct object *o)
{
  /* We don't want to free the password every time... */
  if(THIS->pw != NULL) {
    free_string(THIS->pw);
    THIS->pw = NULL;
  }
  free_hash();
}

/* Initialize the hash storage */
void init_hash_storage(struct object *o)
{
  MEMSET(THIS, 0, sizeof(mhash_storage));
  THIS->type = -1;
}


#endif
