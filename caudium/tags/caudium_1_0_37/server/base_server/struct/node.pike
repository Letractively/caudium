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
int folded=1, type;
mixed data;
function describer;
object prev, next, current, up, down;

mapping below=([]);

array (string) _path = ({ });
string path(int i)
{
  array rp = Array.map(_path, replace, "/", "%2F");
  if(i) return replace("/"+rp*"/",
		       ({ " ", "\t", "\n", "\r", 
			  "?", "&", "%"}), 
		       ({ "%20", "%07", "%0A", "%0D", 
			  "%3f", "%26", "%25" }) );
  return "/"+rp*"/";
}

string name() { return _path[-1]; }

string describe(int i)
{
  string res="";
  mixed tmp;

  if(describer) tmp = describer(this_object());

  if(stringp(tmp))
    res += tmp + "\n";

  if(!folded)
  {
    object node = down;
    while(node)
    {
      res += "  " + (node->describe()/"\n") * "\n  ";
      node = node->next;
    }
  }
  return res;
}

object descend(string what, int nook)
{
  object o;

  what = replace(what, "%2F", "/");
  if(objectp(below[what]))
    return below[what];
  if(nook) return 0;

  o=object_program(this_object())();

  if(!down)  // The new node is the first node below this one in the tree.
    down=o;
  
  o->up = this_object(); 

  if(current)
  {
    o->prev = current;
    current->next = o;
  }

  current = o; // The last node to be added..
  o->_path = _path + ({ what });
  return below[what]=o;
}

void map(function fun)
{
  object node;

  fun(this_object());
  node=down;
  while(node)
  {
    node->map(fun);
    node=node->next; 
  }
}

void clear()
{
  object node;
  object tmp;
  current=0;
  node=down;
  below=([]);
  while(node)
  {
    tmp=node->next; 
    node->dest();
    node=tmp;
  }
  down=0;
}

void dest()
{
  object node;
  object tmp;

  node=down;

  below=([]);

  while(node)
  {
    tmp=node->next; 
    node->dest();
    node=tmp;
  }

  if(prev)  prev->next = next;
  if(next)  next->prev = prev;

  if(up)
  {
    if(up->down == this_object())     up->down = prev||next;
    if(up->current == this_object())  up->current = prev||next;
  }
  next=prev=0;
  up=down=0;
  destruct();
}


