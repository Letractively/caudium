#include <module.h>
inherit "module";
inherit "roxenlib";
//#include <array.h>
//#include <simulate.h>

constant rnd="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.";

mapping(string:int) sucker_clients = ([ ]);
mapping(string:int) sucker_hosts = ([ ]);
object logfile = 0;

void update_log()
{
  if(logfile) {
    logfile->seek(0);
    logfile->write(encode_value(({ sucker_clients, sucker_hosts })));
  }
}

string random_string()
{
  return
    `+(@map(map(map(allocate(10), lambda(int x){return strlen(rnd);}), random),
	    lambda(int x){return rnd[x..x];}));
}

string query_location()
{
  return query( "mountpoint" );
}

object|mapping find_file( string f, object id )
{
  string body="";
  int cnt;

  if(id->method != "GET")
    return 0;

  if((f=="" || f[0]!='/') && query_location()[-1] != '/')
    return http_redirect( query_location()+"/"+f, id );

  sucker_clients[id->client[0]]++;
  sucker_hosts[id->remoteaddr]++;
  if(logfile) {
    remove_call_out(update_log);
    call_out(update_log, 3);
  }

  for(cnt=(int)query( "num_links" ); cnt>0; --cnt)
    body+="<a href=\""+random_string()+"\">"+random_string()+"</a><br>\n";

  body+="<br>\n";

  for(cnt=(int)query( "num_emails" ); cnt>0; --cnt)
    body+="<a href=\"mailto:"+random_string()+"@"+random_string()+".com\">"+
      random_string()+"</a><br>\n";

  return http_string_answer("<html><head><title>"+random_string()+
			    "</title><head>\n<body>"+body+
			    "</body>\n</html>\n", "text/html");
}

string status()
{
  array(string) clt_sort, host_sort;

  sort(values(sucker_clients), clt_sort=indices(sucker_clients));
  sort(values(sucker_hosts), host_sort=indices(sucker_hosts));

  return (logfile? "Log file is <font color=green>open</font>.":
	  ((query("logfile")-" ")-"\t"==""? "No log file.":
	   "Log file is <font color=red>not open</font>."))+
    "\n<table border=1><tr><th>Client</th><th>Hits</th>\n"+
    map(reverse(clt_sort), lambda(string client){
      return "<tr><td>"+client+"</td><td>"+sucker_clients[client]+"</td></tr>";
    })*""+
    "</table><table border=1><tr><th>Host</th><th>Hits</th>\n"+
    map(reverse(host_sort), lambda(string host){
      return "<tr><td>"+host+"</td><td>"+sucker_hosts[host]+"</td></tr>";
    })*""+
    "</table>";
}

array register_module()
{
  return ({
    MODULE_LOCATION,
      "Robot Trap",
      "A module to get robots/download scripts trapped in an endless "
      "maze of links.  Can also provide phoney email addresses, to "
      "trick scripts collecting addresses for spamming purposes.",
      0,
      0,
      });
}

void start( int idi )
{
  string logfn = (query("logfile")-" ")-"\t";

  if(logfn != "" && (logfile=Stdio.File()) && logfile->open(logfn, "crw")) catch{
    array(mapping(string:int)) l = decode_value(logfile->read(0x7fffffff));
    sucker_clients = l[0];
    sucker_hosts = l[1];
  };
  else {
    if(logfile) logfile->close();
    logfile = 0;
  }
}

void stop()
{
  if(logfile) {
    if(!zero_type(find_call_out(update_log))) {
      remove_call_out(update_log);
      update_log();
    }
    logfile->close();
    logfile=0;
  }
}

void create()
{
  defvar( "mountpoint", "/", "Mount point", TYPE_LOCATION, 
	  "This is where the module will be inserted in the "
	  "namespace of your server." );

  defvar( "num_links", 10, "Number of links per page", TYPE_INT,
	  "This is the number of random links that will be "
	  "generated on each page." );

  defvar( "num_emails", 0, "Number of addresses per page", TYPE_INT,
	  "This is the number of random email addresses that will be "
	  "generated on each page." );

  defvar( "logfile", "", "Log file", TYPE_FILE,
	  "This is the filename where the module keeps it's logfile. "
	  "Leave blank for no logfile." );
}
