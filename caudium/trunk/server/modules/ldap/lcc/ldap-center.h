/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

//
// Error codes
//
#define ERR_NO_SESSION_VARS     0x0001
#define ERR_INVALID_REQUEST     0x0002
#define ERR_PROVIDER_ABSENT     0x0003
#define ERR_LDAP_CONNECT        0x0004
#define ERR_AUTH_FAILED         0x0005
#define ERR_LDAP_BIND           0x0006
#define ERR_SCREEN_ABSENT       0x0007
#define ERR_INVALID_USER        0x0008
#define ERR_LDAP_CONN_MISSING   0x0009
#define ERR_LDAP_MODIFY         0x000A

//
// Session storage shortcuts
//
#define SVARS(_id_) _id_->misc->session_variables
#define SDATA(_id_) SVARS(_id_)->ldap_center_data
#define SUSER(_id_) SDATA(_id_)->user
#define SSTORE(_id_) SVARS(_id_)->session_store

//
// Other macros
//
#define PROVIDER(name) id->conf->get_provider(name)
#define P_MENU(prefix) id->conf->get_provider(QUERY(prefix) + "_menu")
#define P_SCREENS(prefix) id->conf->get_provider(QUERY(prefix) + "_screens")
