/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
 *
 */

/* Dummy host_lookup, used when NO_DNS is defined. */

//string cvs_version = "$Id$";
void create_host_name_lookup_processes() {}

string quick_host_to_ip(string h) { return h; }
string quick_ip_to_host(string h) { return h; }
string blocking_ip_to_host(string h) { return h; }
string blocking_host_to_ip(string h) { return h; }

void host_to_ip(string|void host, function|void callback, mixed ... args)
{
  return callback(0, @args);
}

void ip_to_host(string|void ipnumber, function|void callback, mixed ... args)
{
  return callback(ipnumber, @args);
}

