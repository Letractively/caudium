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

/* $Id$ */
   
import "../";
mapping available;
array tdate;
string path;
string key;
int modified;



mapping get_available_dates()
{
  mapping dates;
  catch {
    dates = decode_value(Stdio.read_file(path+"available_dates"));
    if(!mappingp(dates)) dates = 0;
  };
  if(!dates) {
    dates = ([]);
    foreach((array(int))(get_dir(path)||({})) - ({0}), int y) {
      if(!y) continue;
      if(!dates[y]) dates[y] = ([]);
      foreach((array(int))(get_dir(path+y)||({})) - ({0}), int m) {
	if(!m) continue;
	if(!dates[y][m]) dates[y][m] = (<>);
	foreach((array(int))(get_dir(path+y+"/"+m)||({})) - ({0}), int d) {
	  if(d && sizeof(get_dir(path+y+"/"+m+"/"+d)||({})))
	    dates[y][m][d] = 1;
	}
      }
    }
    rm(path+"available_dates");
    Stdio.write_file(path+"available_dates", encode_value(dates));
  }
  return available = dates;
}

array(int) get_days()
{
  get_available_dates();
  if(available[ tdate[1] ] &&
     available[ tdate[1] ][ tdate[2] ])
    return indices(available[ tdate[1] ][ tdate[2] ]);
  return ({ });
}

array(int) get_months()
{
  get_available_dates();
  if(available[ tdate[1] ])
    return indices(available[ tdate[1] ]);
  return ({ });
}
void create(string _path)
{
  path = _path;
  if(!strlen(path) || path[-1] != '/')  path+= "/";
  Util.mkdirhier(path);
  get_available_dates();
}

void set_period(array period)
{
  tdate = period;
  switch(period[0])
  {
   case Util.PERIOD_DAY:
    key = sprintf("%s/%d/%d/%d/", path, @period[1..]);
    break;
   case Util.PERIOD_WEEK:
    key = sprintf("%s/%d/week_%d/", path, @period[1..]);
    break;
   case Util.PERIOD_MONTH:
    key = sprintf("%s/%d/%d/", path, @period[1..]);
    break;
   case Util.PERIOD_YEAR:
    key = sprintf("%s/%d/", path, period[1]);
    break;
  }
}
void invalidate(mapping dates)
{
#define urm(x) do { /*write("%s\n", x);*/ rm(x); } while(0)
  foreach(indices(dates), int y) {
    foreach(get_dir(path+y)||({}), string f) {
      if(f[..3] == "week")
	foreach(get_dir(path+y+"/"+f)||({}), string w)
	  urm(path+y+"/"+f+"/"+w);
      urm(path+y+"/"+f);
    }
    foreach(indices(dates[y]), int m) {
      foreach(get_dir(path+y+"/"+m)||({}), string f)
	urm(path+y+"/"+m+"/"+f);
      foreach(indices(dates[y][m]), int d) {
	foreach(glob("report_*",
		     get_dir(path+y+"/"+m+"/"+d)||({})), string f)
	  urm(path+y+"/"+m+"/"+d+"/"+f);
      }
    }
  }
}

mixed load(string table)
{
  if(!table || !strlen(table))
    return 0;
  mixed tmp;
  tmp = Stdio.read_file(key+table);
  if(!tmp) return 0;
  catch { tmp = Util.uncompress(tmp); };
  mixed err = catch { tmp = decode_value(tmp); };
  if(err) {
    werror("Error decoding data for %s (%s)\n%s\n",
	   table, key, describe_backtrace(err));
    return 0;
  }
  return tmp;
}

mapping load_list(array list)
{
  mapping tmp = ([]);
  foreach(list, string l)
    tmp[l] = load(l);
  return tmp;
}

void save(string table, mixed data)
{
  get_available_dates();
  if(tdate && tdate[0] == Util.PERIOD_DAY) {
    if(!available[ tdate[1] ])
      available[ tdate[1] ] = ([]);
    if(!available[ tdate[1] ][ tdate[2] ])
      available[ tdate[1] ][ tdate[2] ] = (<>);
    if(!available[ tdate[1] ][ tdate[2] ][ tdate[3] ]) {
      available[ tdate[1] ][ tdate[2] ][ tdate[3] ] = 1;
      rm(path+"available_dates");
      Stdio.write_file(path+"available_dates", encode_value(available));
    }
  }
  Util.mkdirhier(key);
  rm(key+table);
  Stdio.write_file(key+table, Util.compress(encode_value(data)));
  modified = 1;
}

void sync() {
  /*
    if(modified) {
    db->sync();
    modified = 0;
    }
  */
}

void destroy() {
  sync();
}




