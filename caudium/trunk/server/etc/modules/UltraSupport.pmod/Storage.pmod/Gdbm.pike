// $Id$
import "../";
object db;
string key;
string path;
array tdate;
mapping available;
mapping get_available_dates()
{
  object dates = Gdbm.gdbm(path+"available_dates.gdbm", "rwc");
  mixed tmp = dates->fetch("dates");
  available = ([]);
  if(!tmp)
    return ([ ]);
  if(catch { tmp = decode_value(tmp); })
    return ([ ]);
  if(!mappingp(tmp))
    return ([]);
  return available = tmp;
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
  if(db) {
    sync();
    destruct(db);
  }
  db = Gdbm.gdbm(path+period[1]+"_stats.gdbm", "rwcf");
  tdate = period;
  switch(period[0])
  {
   case Util.PERIOD_DAY:
    key = sprintf("%02d%02d_", @period[2..]);
    break;
   case Util.PERIOD_WEEK:
    key = sprintf("wk%02d_", period[2]);
    break;
   case Util.PERIOD_MONTH:
    key = sprintf("mo%02d_", period[2]);
    break;
   case Util.PERIOD_YEAR:
    key = "yr_";
    break;
  }
}

int modified;
void invalidate(mapping dates)
{
  foreach(indices(dates), int y) {
    array all = ({});
    if(db) {
      sync();
      destruct(db);
    }
    db = Gdbm.gdbm(path+y+"_stats.gdbm", "rwcf");
    db->delete("yr");
    foreach(indices(dates[y]), int m) 
      db->delete(sprintf("mo%02d", m));
    for(string key = db->firstkey(); key; key = db->nextkey(key)) 
      all += ({ key });
    foreach(glob("*report_*", all), string f) 
      db->delete(f);
    foreach(glob("wk*", all), string f) 
      db->delete(f);
  }
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

mixed load(string table)
{
  if(!table || !strlen(table))
    return 0;
  mixed tmp;
  tmp = db->fetch(key+table);
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
      object dates = Gdbm.gdbm(path+"available_dates.gdbm", "rwc");
      dates->store("dates", encode_value(available));
      dates->sync();
      destruct(dates);
    }
  }
  db->store(key+table, Util.compress(encode_value(data)));
}

void sync() {
  db && db->sync();
}

void destroy() {
  if(db) {
    sync();
    destruct(db);
  }
}
