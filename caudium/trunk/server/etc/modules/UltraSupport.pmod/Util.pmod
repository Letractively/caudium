// $Id$

constant PERIOD_MONTH = 0;
constant PERIOD_YEAR  = 1;
constant PERIOD_WEEK  = 2;
constant PERIOD_DAY   = 3;

import ".";

/* These will be size limited to the defined size */
constant compmaps =
(<
  "agents",
  "hits", 
  "pages", 
  "redirs",
  "refs",
  "refsites",
  "domains",
  "sites",
>);

void compress_mappings(object o, string|int table, int maxsize)
{
  if(!table)
    foreach(indices(compmaps), table) 
    {
      if((sizeof(o[table])-1) > maxsize) {
	werror("\t\tCleaning table %s: %d...", table,sizeof(o[table]));
	o[table] = UltraLog.compress_mapping(o[table], maxsize);
	werror("done.\n");
      }
    }
  else if(compmaps[table]) {
    if((sizeof(o[table])-1) > maxsize) {
      werror("\t\tCleaning table %s: %d...", table, sizeof(o[table]));
      o[table] = UltraLog.compress_mapping(o[table], maxsize);
      werror("done.\n");
    }
  } 
}


array dir_glob(string dirname, string p) {
  array matches = ({});
  array dir = get_dir(dirname);
  if(!dir) return ({});
  dir = glob(p, dir);
  foreach(sort(dir), string sf)  matches += ({ dirname + sf });
  return matches;
}
array glob_expand(string glob)
{
  array path;
  string lfile;
  array matches = ({});
  string dirname="";
  if(!strlen(glob) || !sizeof(path = glob / "/"))
    return ({ });
  array dirs=({});
  if(glob[-1] != '/') {
    lfile = path[-1];
    path = path[..sizeof(path)-2];
  }
  for(int i = 0; i < sizeof(path); i++)
  {
    if(!strlen(path[i])) {
      dirname += "/";
      continue;
    }
    if(search(path[i], "*") != -1 ||
       search(path[i], "?") != -1) {
      array newdirs = ({});
      if(sizeof(dirs))
	foreach(dirs, string dn) newdirs += dir_glob(dn+"/", path[i]);
      else 			 newdirs += dir_glob(dirname, path[i]);
      if(!sizeof(newdirs)) return ({});
      dirs = newdirs;
    }
    dirname += path[i] +"/";
  }
  if(lfile)
    if(sizeof(dirs))
      foreach(dirs, string dn)
	matches += dir_glob(dn+"/", lfile);
    else
      matches += dir_glob(dirname, lfile);
  return  matches;
}


void add_mapping_mapstr(mapping orig, mapping add)
{
  string ns;
  foreach(indices(add), string ind)
  {
    ns = http_decode_string(ind);
    if(!orig[ns]) orig[ns] = ([]);
    add_mapping_str(orig[ns], add[ind]);
  }
}

void add_mapping_str(mapping orig, mapping add)
{
  foreach(indices(add), string ind)
    //    orig[http_decode_string(ind)] += add[ind];
    orig[ind] += add[ind];
}

void add_mapping_mapint(mapping orig, mapping add)
{
  foreach(indices(add), int ind)
  {
    if(!orig[ind]) orig[ind] = ([]);
    add_mapping_int(orig[ind], add[ind]);
  }
}

void add_mapping_int(mapping orig, mapping add)
{
  foreach(indices(add), int ind)
    orig[ind] += add[ind];
}


void mkdirhier(string dir)
{
  string now="/";
  foreach(dir / "/" - ({""}), string d)
  {
    now += d+"/";
    mkdir(now);
  }
}

string compress(string data)
{
#if constant(Gz.deflate)
  return Gz.deflate(2)->deflate(data);
#else
  return data;
#endif
}

string uncompress(string data)
{
#if constant(Gz.inflate)
  return Gz.inflate()->inflate(data);
#else
  return data;
#endif
}

void low_load_all(object db, mapping|object stat, array data)
{
  mixed tmp = db->load_list(data);
  if(tmp) {
    foreach(indices(tmp), string table) {
      if(!tmp[table]) continue;
      stat[table] = tmp[table];
      if(!search(table, "kb_per_"))
      {
	array ok = (mappingp(stat[table])  ? values(stat[table]) : stat[table])
	  - ({0});
	if(sizeof(ok))
	  stat->avg_bandwidth = 8 * (`+(@ok, 0, 0) / sizeof(ok) / 3600);
      }
    }
    stat->loaded = 1;
  }
}
void low_load(object db, string table, mapping|object stat)
{
  mixed tmp, data;
  tmp = db->load(table);
  if(tmp) {
    stat[table] = tmp;
    if(!search(table, "kb_per_"))
    {
      array ok = (mappingp(stat[table])  ? values(stat[table]) : stat[table])
	- ({0});
      if(sizeof(ok))
	stat->avg_bandwidth = 8 * (`+(@ok, 0, 0) / sizeof(ok) / 3600);
    }
    stat->loaded = 1;
  } else
    stat->loaded = 0;
  
}

int load(object db, mapping|object stat, array data, string|void table) 
{
  if(table) {
    if(search(data, table) != -1)
      low_load(db, table, stat);
    switch(table) {
     case "sessions_per_month":
      low_load(db, "wsessions_per_month", stat);
      break;
     case "kb_per_month":
      low_load(db, "wkb_per_month", stat);
      break;
     case "agent_os_ver":
     case "agent_os":
     case "agent_ver":
     case "common_os":
     case "agent":
      low_load(db, "agents", stat);
      break;
     case "pages_per_month":
      low_load(db, replace(table, "pages", "wpages"), stat);
      low_load(db, replace(table, "pages", "whits"), stat);
     case "pages_per_day":
     case "pages_per_hour":
      low_load(db, replace(table, "pages", "hits"), stat);
      break;
     case "hits_per_month":
      low_load(db, replace(table, "hits", "wpages"), stat);
      low_load(db, replace(table, "hits", "whits"), stat);
     case "hits_per_hour":
     case "hits_per_day":
      low_load(db, replace(table, "hits", "pages"), stat);
      break;
     case "error_code":
      low_load(db, "codes", stat);
      break;
     case "sess_hour_len":
     case "sess_month_len":
     case "sess_day_len":
      low_load(db, "sess_len", stat);
      break;
     case "sess_month_hits":
     case "sess_day_hits":
     case "sess_hour_hits":
      string t1, t2, t3;
      if(stat->loaded) {
	low_load(db, replace(table, "hits", "pages"), stat);
      } else {
	t1 = replace(table-"_hits", "sess_", "pages_per_");
	t2 = replace(table-"_hits", "sess_", "hits_per_");
	t3 = replace(table-"_hits", "sess_", "sessions_per_");
	low_load(db, t1, stat);
	low_load(db, t2, stat);
	low_load(db, t3, stat);
	for(int h = 0; h < sizeof(stat[t3]); h ++)
	{
	  if(stat[t3][h]) {
	    stat[table][h]   = stat[t2][h] / (float)stat[t3][h];
	    stat[replace(table, "hits", "pages")][h] =
	      stat[t1][h] / (float)stat[t3][h];
	  }
	}
      }
    }
  } else {
    low_load_all(db, stat, data);
  }
}


int save(object db, array data, object period) 
{
  foreach(data, string f) {
    if((arrayp(period[f]) &&
	sizeof(period[f] - ({0}))) ||
       (mappingp(period[f]) && sizeof(period[f]))) {
      db->save(f, period[f]);
    }
    if(period->extra && period->extra[f] && sizeof(period->extra[f])) {
      db->save(f, period->extra[f]);
    }
  }
  db->sync();
}
