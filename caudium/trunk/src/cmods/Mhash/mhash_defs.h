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

#define THIS ((mhash_storage *)fp->current_object->storage)

typedef struct
{
  MHASH hash;
  int type;
  unsigned char *res;
} mhash_storage;

#ifndef ADD_STORAGE
/* Pike 0.6 */
#define ADD_STORAGE(x) add_storage(sizeof(x))
#endif


/* Mhash object functions */
void f_hash_create(INT32 args);
void f_hash_feed(INT32 args);
void f_hash_digest(INT32 args);
void f_hash_hexdigest(INT32 args);
void f_hash_name(INT32 args);
void f_hash_reset(INT32 args);
void f_hash_set_type(INT32 args);
void mhash_init_mhash_program(void);


/* Class global funcs */
void mhash_init_globals(void);
void f_query_name(INT32 args);

     
