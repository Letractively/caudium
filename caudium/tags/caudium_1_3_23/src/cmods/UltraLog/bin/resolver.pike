#!/usr/bin/env pike

constant cvs_version = "$Id$";
int running, save_num;
mapping to_write = ([]);
mapping outstanding = ([]);
mapping resolved = ([]);
mapping in_progress = ([]);
object fifo = Thread.Fifo(1000);

int main(int argc, string argv)
{
  thread_create(do_it, argv[1]);
  return -1;
}
void write_out()
{
  int last;
  string out = "";
  int writeout, count, last_out = 0;
  while(1) {
    array res = sort(indices(to_write));
    if(!sizeof(res)) res = ({-1});
    werror("\r%7d %7d %7d %7d %7d", last_out, res[0],
	   running, sizeof(outstanding), sizeof(to_write));
    while(to_write[last_out])
      //foreach(sort(indices(to_write)), last_out)
    {
      out += to_write[last_out];
      m_delete(to_write, last_out);
      m_delete(outstanding, last_out);
      last_out++;
      writeout++;
      count++;
    }
    count = 0;
    if(strlen(out)) {
      write(out);
      out = "";
      last = time();
      sleep(1);
    } else  if((time() - last) > 2 && sizeof(to_write)) {
      while(outstanding[last_out] && !to_write[last_out]) {
	out += outstanding[last_out]->line;
	//	werror("\rTimed out on %s                                    \n",
	//	       outstanding[last_out]->ip);
	resolved[outstanding[last_out]->ip] = outstanding[last_out]->ip;
	handle_progress(outstanding[last_out]->ip,
			outstanding[last_out]->ip);
	m_delete(outstanding, last_out);
	m_delete(to_write, last_out);
	
	last_out++;
      }
    //      last += 3;
    sleep(1);
    } else
      sleep(1);
    if(writeout > 50000)
    {
      if(sizeof(resolved) != save_num) {
	//	werror("\rSaving (%d)...", writeout);
	writeout = 0;
	rm("resolver.cache");
	Stdio.write_file("resolver.cache", encode_value(resolved));
	//	werror("ok.                            ");
	save_num = sizeof(resolved);
      }
    }
  }
}

void handle_progress(string ip, string host) {
  if(in_progress[ip])
    foreach(in_progress[ip], int lnr)
    {
      if(!outstanding[lnr])
	continue;
      to_write[lnr] = sprintf("%s %s\n", host, outstanding[lnr]->rest);
      m_delete(outstanding, lnr);
      //      running--;
    }
  m_delete(in_progress, ip);
}

void resolved_ip(string ip, string host, int lnr) {
  array err = catch { 
    running--;
    if(!host) host = ip;
    else      host = lower_case(host);
    resolved[ip] = host;
    if(outstanding[lnr]) {
      to_write[lnr] = sprintf("%s %s\n", host, outstanding[lnr]->rest);
      m_delete(outstanding, lnr);
    } else {
      //      werror("\rReq #%d (%s->%O): Timed Out, returned.\n",
      //	     lnr, ip, host);
    }
    handle_progress(ip, host);
  };
  if(err)
    werror(describe_backtrace(err));
}

void do_it(string file)
{
  if(catch(resolved = decode_value(Stdio.read_file("resolver.cache"))))
    resolved = ([]);
  save_num = sizeof(resolved);
  //  for(int i = 0; i < 20; i ++)
  //    thread_create(resolver_thread);
  object fd = Stdio.FILE(file, "r");
  string line, ip;
  int lnr;
  thread_create(write_out);
  object dns = Protocols.DNS.async_client("127.0.0.1");
  while((line = fd->gets())) {
    mapping data = ([]);
    
    if(sscanf(line, "%s %s", data->ip, data->rest) != 2) {
      to_write[lnr] = line+"\n";
    } else if(sscanf(data->ip, "%*d.%*d.%*d.%*d") != 4) {
      to_write[lnr] = sprintf("%s %s\n", lower_case(data->ip), data->rest);
    } else if(resolved[data->ip]) {
      to_write[lnr] = sprintf("%s %s\n", resolved[data->ip],
			      data->rest);
    } else if(in_progress[data->ip]) {
      data->line = line;
      outstanding[lnr] = data;
      in_progress[data->ip] += ({ lnr });
      //      running++;
    } else {
      running++;
      //    fifo->write(data);
      data->line = line;
      outstanding[lnr] = data;
      in_progress[data->ip] = ({});
      dns->ip_to_host(data->ip, resolved_ip, lnr);
    }
    while(running > 500 || sizeof(to_write) > 80000)
      sleep(1);
    lnr++;
    //    break;
  }
  //  for(int i = 0; i < 1000; i ++)
  //    fifo->write(0);
  
  while(running || sizeof(to_write) || sizeof(outstanding)) {
    sleep(1);
  }
  rm("resolver.cache");
  Stdio.write_file("resolver.cache", encode_value(resolved));
  exit(0);
}



