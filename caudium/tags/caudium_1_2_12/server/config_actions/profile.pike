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

// $Id$
#ifndef PROFILE
constant action_disabled = 1;
#else /* PROFILE */
inherit "wizard";

constant name = "Maintenance//Profiling information...";
constant doc = "Show average access time for all pages accessed on your server.";
constant wizard_name = "Profiling information";

mapping preprocess(mapping in)
{
  // remove final part after '/' if any.
  mapping q = ([]);
  foreach(indices(in), string i)
  {
    string oi = i;
    i = reverse(i);
    sscanf(i, "%*s/%s", i);
    i  = reverse(i);
    if(!strlen(i)) i = "/";
    if(!q[i])
      q[i]=copy_value(in[oi]);
    else 
    {
      q[i][0] += in[oi][0];
      q[i][1] += in[oi][1];
      if(q[i][2] < in[oi][2])
	q[i][2] = in[oi][2];
    }
  }
  return q;
}


string page_0(object id, mixed f, int|void detail)
{
  string res = "";
  foreach(caudium->configurations, object c)
  {
    res += "<h1>"+c->name+"</h1><p>";
    
    mapping q = detail?c->profile_map:preprocess(c->profile_map);
    array ind = indices(q);
    array val = values(q);
    array rows = ({});

    sort(column(val,2), val, ind);
    for(int i = sizeof(val)-1; i>=0; i--)
      rows += ({ ({ ind[i], (string)val[i][0], 
		    sprintf("%.2f",val[i][1]), 
		    sprintf("%.3f",val[i][1]/val[i][0]),
		    sprintf("%.3f",val[i][2]), 
      }) });

    res += html_table( ({"Page", "Accesses", "Total time", "Avg. time", "Max time" }), rows );
  }
  return res+"<p><i>Press 'next' for detailed information</i>";
}

string page_1(object id)
{
  return page_0(id,0,1);
}

string handle(object id)
{
  return wizard_for(id,0);
}
#endif /* PROFILE */
