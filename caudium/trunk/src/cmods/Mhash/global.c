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

/* Hash id -> name */
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



void mhash_init_globals(void) {
  add_function("query_name", f_query_name, "function(int:string)", 0 ); 

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
#endif
