/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

constant doc = "Generic matrix filter. Specify a 'matrix' argument with a matrix, row and space separated like this:<pre>matrix='x x x x x x\nx x x x x x\nx x x x x x'</pre>The matrix can be any size. All rows must be of the same size. You can specify a base color using the 'color' argument, and a divisor using the 'divisor' argument.";

void render( mapping args, mapping this, string channel, object id, object m )
{
  array color = Colors.Colors.parse_color( args->color||"black" );
  if(!this[channel]) return;
  array matrix = (args->matrix||"0 1 0\n1 2 1\n0 1 0")/"\n";
  matrix = Array.map(matrix, lambda(string s){
			       return (array(int))(s/" "-({""}));
			     });
  
  if(args->divisor = (int)args->divisor)
    this[channel]=this[channel]->apply_matrix(matrix,@color,args->divisor);
  else
    this[channel]=this[channel]->apply_matrix(matrix,@color);
}
