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

/* Init the module */
void pike_module_init(void)
{  
  mhash_init_mhash_program();
  mhash_init_hmac_program();
  mhash_init_globals();
}


/* Restore and exit module */
void pike_module_exit( void )
{
}

#else /* HAVE_MHASH */
void pike_module_exit( void ) { }
void pike_module_init( void ) { }
#endif /* HAVE_MHASH */

/*
 * Local variables:
 * c-basic-offset: 2
 * End:
 */
