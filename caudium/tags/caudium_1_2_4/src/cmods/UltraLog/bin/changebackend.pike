#!/usr/bin/env pike
import "../pmod/";
import spider;
array data = ({
  "pages",  "codes",  "hits",   "refs",   "errorpages", "hits_per_hour",
  "kb_per_hour", "dirs", "pages_per_hour", "sessions_per_hour", "sess_len",
  "redirs", "refsites", "refto", "errefs", "agents", "sites", "topdomains",
  "domains", "hosts_per_hour"
});

constant cvs_version = "$Id$";

int main(int argc, array argv)
{
  if(argc<5)
  {
    werror("Syntax: %s <frommethod> <tomethod> <todir> indir1 .. indirN\n",
	   argv[0]);
    exit(1);
  }
  string from = argv[1];
  string to = argv[2];
  string todir = argv[3];
  foreach(argv[4..], string dir) {
    write(dir+"...\n");
    array p = dir / "/" - ({""});
    string profile = p[-1];
    string proftodir = combine_path(getcwd(), todir,  profile+"/");
    object from = Storage[String.capitalize(lower_case(from))](combine_path(getcwd(), dir+"/"));
    object to = Storage[String.capitalize(lower_case(to))](proftodir);
    mapping dates = from->get_available_dates();
    foreach(sort(indices(dates)), int y) {
      foreach(sort(indices(dates[y])), string m) {
	foreach(sort(indices(dates[y][m])), string d)
	{
	  write("\t%04d-%02d-%02d\n", y, m, d);
	  from->set_period( ({ Util.PERIOD_DAY, y, m, d }) );
	  to->set_period( ({ Util.PERIOD_DAY, y, m, d }) );
	  foreach(data, string table) {
	    mixed data = from->load(table);
	    to->save(table, data);
	  }
	  to->sync();
	}
      }
    }
  }
}
