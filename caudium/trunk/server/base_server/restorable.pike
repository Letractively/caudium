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

/* $Id$ */

static private array __vars=({});

static private array save_variables()
{
  mixed b, a;
  array res = ({ }), variable;
  if(!sizeof(__vars)) // First time, not initialized.
    foreach(indices(this_object()), a)
    {
      b=this_object()[a];
      if(!catch { this_object()[a]=b; } ) // It can be assigned. Its a variable!
      {
	__vars+=({});
	res += ({ ({ a, b }) });
      }
    }
  else
    foreach(__vars, a)
      res += ({ ({ a, this_object()[a] }) });
  return res;
}


static private void restore_variables(array var)
{
  if(var)
    foreach(var, var)
      catch { this_object()[var[0]] = var[1]; };
}

string cast(string to)
{
  if(to!="string") error("Cannot cast to "+to+".\n");
  return encode_value(save_variables());
}

void create(string from)
{
  array f;
  catch {
    restore_variables(decode_value(from));
  };
}
