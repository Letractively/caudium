/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
 */
/*
 * $Id$
 */

//! This is the real Caudium version. It should be changed before each
//! release
constant __caudium_version__ = "1.3";
constant __caudium_build__ = "27";
constant __caudium_state_ver__ = "DEVEL";

//! any code may _append_ to this string - NEVER replace it!
string __caudium_extra_ver__ = "";

//! The full Caudium version string
string real_version = "Caudium/"+__caudium_version__+"."+__caudium_build__+" "+__caudium_state_ver__;
