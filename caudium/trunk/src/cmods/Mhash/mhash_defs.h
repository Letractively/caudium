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
  MHASH hmac;
  int type;
  unsigned char *res;
  struct pike_string *pw;
} mhash_storage;


/* Mhash.Hash functions */
void f_hash_create(INT32 args);
void f_hash_feed(INT32 args);
void f_hash_digest(INT32 args);
void f_hash_hexdigest(INT32 args);
void f_hash_query_name(INT32 args);
void f_hash_reset(INT32 args);
void f_hash_set_type(INT32 args);
void mhash_init_mhash_program(void);

/* Mhash.HMAC object functions */
void f_hmac_create(INT32 args);
void f_hmac_feed(INT32 args);
void f_hmac_digest(INT32 args);
void f_hmac_hexdigest(INT32 args);
void f_hmac_reset(INT32 args);
void f_hmac_set_type(INT32 args);
void f_hmac_set_key(INT32 args);
void mhash_init_hmac_program(void);

/* Class global funcs */
void f_to_hex(INT32 args);
void mhash_init_globals(void);
void f_query_name(INT32 args);
     
/* Shared functions */
void free_hash(void);
void free_hash_storage(struct object *);
void init_hash_storage(struct object *);


/* Return values from init_hmac */
#define HMAC_OK		0
#define HMAC_TYPE	1 /* Type missing */
#define HMAC_PASS	2 /* Password missing */
#define HMAC_FAIL	3 /* Failed to initialize */
#define HMAC_LIVE	4 /* Current object is already live */
#define HMAC_DONE	5 /* We have finished the current feed */

     
