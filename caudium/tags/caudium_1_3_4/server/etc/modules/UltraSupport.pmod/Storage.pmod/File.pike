/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

constant multiload = 1;

mapping available;
array tdate;
string path;
string savedir;
string key;
int modified;
mapping load_cache;
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
      int m,d;
      if(!y) continue;
      if(!dates[y]) dates[y] = ([]);
      foreach((get_dir(path+y)||({})) - ({0}), string p ) {
	if(sscanf(p, "%2d%2d.sav", m, d) == 2) {
	  if(!dates[y][m]) dates[y][m] = (<>);
	  dates[y][m][d] = 1;
	}
      }
    }
    rm(path+ "available_dates");
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
  Stdio.mkdirhier(path);
  get_available_dates();
}

void remove_cache()
{
  load_cache = 0;
}

void set_period(array period)
{
  if(equal(period, tdate))
    return;
  load_cache = 0;
  tdate = period;
  savedir = path+period[1]+"/";  
  switch(period[0])
  {
   case Util.PERIOD_DAY:
    key = sprintf("%02d%02d.sav",@period[2..]);
    break;
   case Util.PERIOD_WEEK:
    key = sprintf("week%02d.sav", period[2]);
    break;
   case Util.PERIOD_MONTH:
    key = sprintf("month%02d.sav", period[2]);
    break;
   case Util.PERIOD_YEAR:
    key = "year.sav";
    break;
  }
  call_out(remove_cache, 30);
}

void invalidate(mapping dates)
{
#define urm(x) do { write("%s\n", x); rm(x); } while(0)
  int m;
  foreach(indices(dates), int y) {
    foreach(get_dir(path+y)||({}), string f) {
      if(f[..3] == "week" ||
	 f[..3] == "year" ||
	 search(f, "report" ) != -1 ||
	 (sscanf(f, "month%d", m) && dates[y][m]))
	urm(path+y+"/"+f);
    }
  }
}

mapping load_list(void|array list)
{
  mixed tmp, tmp2;
  if(!load_cache) {
    tmp = Stdio.read_file(savedir+key);
    if(!tmp) return 0;
    catch { tmp = Util.uncompress(tmp); };
    mixed err = catch { tmp = decode_value(tmp); };
    if(err) {
      werror("Error decoding data for %s\n%s\n",
	     key, describe_backtrace(err));
      return 0;
    }
    load_cache = tmp;
  } else
    tmp = load_cache;
  if(list) {
    tmp2 = ([]);
    foreach(list, string l)
      tmp2[l] = tmp[l];
    return tmp2;
  }
  return tmp || ([]);
}

mixed load(string table)
{
  if(!table || !strlen(table))
    return 0;
  mapping tmp = load_cache || load_list() || ([]);
  return tmp[table];
}
mapping savetmp;
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
  if(!savetmp) savetmp = ([]);
  savetmp[table] = data;
}

void sync() {
  if(savetmp) {
    Stdio.mkdirhier(savedir);
    rm(savedir+key);
    Stdio.write_file(savedir+key, Util.compress(encode_value(savetmp)));
    savetmp = 0;
  }
}

void destroy() {
  sync();
}
