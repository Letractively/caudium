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

#define QUICKHASH(NAME,TYPE)	\
void PIKE_CONCAT(f_hash_,NAME)(INT32 args);\
void PIKE_CONCAT(f_hash_,NAME)(INT32 args) { \
  MHASH hash;\
  unsigned char *res;\
  struct pike_string *str;\
  int len, i;\
  if(args != 1 && sp[-1].type != T_STRING) {\
    Pike_error("Invalid / incorrect args to hash_" #NAME ". Expected string.\n");\
  }\
  hash = mhash_init(TYPE);\
  if(hash == MHASH_FAILED) {\
    Pike_error("Failed to initialize hash.\n");\
  }\
  mhash(hash, sp[-1].u.string->str,\
	sp[-1].u.string->len << sp[-1].u.string->size_shift);\
  res = mhash_end(hash);\
  len = mhash_get_block_size(TYPE);\
  str = begin_shared_string(len);\
  for(i = 0; i < len; i++) {\
    STR0(str)[i] = res[i];\
  }\
  str = end_shared_string(str);\
  pop_n_elems(args);\
  push_string(str);\
  free(res); \
}\

#define ADDQHASH(HASH) \
ADD_FUNCTION("hash_"#HASH, PIKE_CONCAT(f_hash_, HASH), tFunc(tStr,tStr), 0); \

