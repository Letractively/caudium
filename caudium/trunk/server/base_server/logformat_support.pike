/*
 * Caudium - An extensible World Wide Web server
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

// Logging format support functions.
nomask private inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

nomask private inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

nomask private inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}
