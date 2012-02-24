#!/usr/bin/pike

// $Id$

/* This script is used to get running webserver version on a given set of sites
   Execute it with no arguments to get more informations */
/* given a list of websites in a file, will create a new file telling 
   which web server it runs */
      

// The timeout of the connection in seconds once we launch the connection  
// process to the remote server
#define TIMEOUT 10
// the MAX number of simultaneous connections we made
#define MAX_CONN 2000

// the number of connections at a given time
static int nb_connections = 0;
// the progress bar
static object bar;
// the number of sites we have checked so far
static int checked;
// the resuls are in this mapping
mapping(string:string) results = ([ ]);

void usage(string myname)
{
  string usage = sprintf("%s <inputfile> <outputfile>\n", myname);
  usage += "where inputfile is a file that contains a list of website\n";
  usage += "output will contains the same list with the webserver serving the site\n";
  usage += "if output already exists, it will be overwritten\n";
  write(usage);
}

inline void write2servers(string site, string servername)
{
  //write(sprintf("%s %s\n", site, servername));
  results += ([ site: servername ]);
  nb_connections--;
  checked++;
  bar->update(1);
}

class socket {

  // the server name we try to guess
  private string server = "";
  // the buffer for the data we read from the server
  private string buffer = "";
  // the site we are connected to
  private string site = "";
  private object fd;
  // the function to call on exit
  private object exit_cb;
  
  // note that a call_back function never (and can't) return anything 
  // by design
  // it is called by something external to this program (here the data
  // coming from the socket)
  private inline void read_callback(mixed id, string data)
  {
    // when we are called, we are not sure to get all the response from 
    // the server, we have to buffer it
    buffer += data;
  }
  
  // the server close the connection (as it should in HTTP non keepalived)
  private inline void close_callback(mixed id)
  {
    // first see if we get some data to work on
    if(sizeof(buffer) > 0)
    {
      int retpos = 0, oldretpos = 0;
      // here comes the headers parser
      // not very beautiful but should be fast
      while(retpos != -1)
      {
        retpos = search(buffer, "\r\n", oldretpos);
        string header_line = buffer[oldretpos..retpos-1];
        oldretpos = retpos+2;
	int pos = search(header_line, ":");
	if(pos != -1 && lower_case(header_line[..pos-1]) == "server")
	{
	  // remove one space in the server string
	  write2servers(site, String.trim_whites(header_line[pos+1..]));
	  remove_call_out(handle_timeout);
	  destruct(this_object());
	  return 0;
	}
      }
    }
    // fallback to unknow server
    write2servers(site, "null");
    // remove the timeout callout
    remove_call_out(handle_timeout);
    destruct(this_object());
  }
  
  inline void connect(int status, object _fd)
  {
    fd   = _fd;
    if(!status)
    {
     write2servers(site, "null"); 
     remove_call_out(handle_timeout);
     destruct(this_object());
     return 0;
    }
    fd->write(sprintf("HEAD / HTTP/1.1\r\nHost: %s\r\nConnection: Close\r\n\r\n", site));
    // first set socket to non blocking mode
    // this mean that the program (and so the thread) will not be 
    // blocked because we are waiting for something on the socket
    // read_callback() will be called automatically when data from
    // the server come to us, it is the same for the other callbacks
    fd->set_nonblocking(read_callback, 0, close_callback);
    // launch a new connection
    exit_cb->check_another_server();
  }

  inline void handle_timeout(object fd)
  {
    write2servers(site, "null");
    remove_call_out(handle_timeout);
    destruct(this_object());
  }

  inline void destroy()
  {
    catch(fd->close());
    if(find_call_out(exit_cb->check_another_server))
      remove_call_out(exit_cb->check_another_server);
    if(nb_connections < MAX_CONN)
    {
      exit_cb->check_another_server();
    }
  }

  inline void create(object cb, string _site)
  {
    exit_cb = cb;
    site = _site;
  }
  
};

class http {
 
  private array(string) lines = ({ });
  private object output_fd;
  private int nb_sites, start_time;
  private object async_dns_client;
  
  void create(array(string) _lines, object _output_fd, int _start_time)
  {
    output_fd = _output_fd;
    start_time = _start_time;
    checked = 0;
    //_lines = Array.uniq(_lines);
    foreach(_lines, string site)
    {
      if(site[0..6] == "http://")
        site = site[6..]; 
      if(sizeof(site) == 0)
        break;
      lines += ({ site });
    }
    nb_sites = sizeof(lines);
    bar = Tools.Install.ProgressBar("Checking", 0, nb_sites);
    async_dns_client = Protocols.DNS.async_client();
    check_another_server();
  }

  void end()
  {
    int elapsed_time = time() - start_time;
    write("\nTest finished\n");
    if(elapsed_time > 0)
      write("Scanned %d hosts in %d seconds: %f hosts/s\n", 
        checked, elapsed_time, (float)checked/elapsed_time);
    string output = "";
    foreach(indices(results), string indice)
      output += sprintf("%s %s\n", indice, results[indice]);
    output_fd->write(output);
    output_fd->close();
    exit(0);
  }

  inline void connect(string name, string|int ip)
  {
    if(ip)
    {
      // please note I write File and not FILE, there are two things different
      object fd = Stdio.File();
      object socket = socket(this_object(), name);
      int port = 80;
      // we connect asynchronously to the server, that is we don't wait for it 
      // to reply
      fd->async_connect(ip, port, socket->connect, fd);
      // a call_out allow you to make a delayed call to a function.
      // it is very useful for managing timeouts
      // test for the socket object because it may have be destroyed already
      if(socket)
        call_out(socket->handle_timeout, TIMEOUT, fd);
    }
    else
    {
      write2servers(name, "null");    
      if(nb_connections < MAX_CONN)
        check_another_server();
    }
  }
  
  inline void check_another_server()
  {
    //write("number of connections=%d\n", nb_connections);
    if(sizeof(lines) == 0)
    {
      if(nb_sites == checked)
        end();
    }
    else
    {
      string site = lines[0];
      // decrease the buffer
      lines = lines[1..];
      // resolve the name asynchronously
      async_dns_client->host_to_ip(site, connect);
      nb_connections++;
    }
  }
}

int main(int argc, array argv)
{
  if(argc != 3)
  {
    usage(argv[0]);
    return 1;
  }
  object infile = Stdio.File(argv[1], "r");
  // the number of sites we have to check
  int nb_sites;
  array(string) lines = ({ });
  foreach((infile->read() - "\r") / "\n", string line)
  {
    if(line && sizeof(line) > 0)
      lines += ({ line });
  }
  infile->close();
  if(!infile)
  {
    werror(sprintf("inputfile %s cannot be open for reading\n", argv[1]));
    return 2;
  }
  int j = 0;
  http(lines, Stdio.File(argv[2], "wc"), time());
  // if we return a negative value from main then we 
  // wait indefinitely (for the threads to finish their job)
  // don't put it something positive there or you won't let 
  // your threads the time to finish
  return -1;
}
