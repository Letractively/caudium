string hostname;
string port;
int max_conns;

array conns=({});

void create(string _host, int _port, int maxconn)
{
  if(!strlen(_host)) error("No host specified.");
  if(!port) error("No port number specified.");
  hostname=_host;
  port=_port;
  max_conns=maxconn;
}

mapping handle_request(id)
{
  object c=get_connection();
  mapping response=([]);
  response=c->handle(id);
  replace_connection(c);
  return response;
}

object get_connection()
{
  foreach(conns, object c)
  {
    if(!c->inuse)
    {
      conns-=({c});
      return c;
    }    
  }  
  return connection(hostname, port);

}

void replace_connection(object conn)
{
  if(sizeof(conns)<max_conns)
    conns+=({conn});
}

class connection
{
  inherit protocol;
  object c;
  int inuse=0;

  void create(string host, int port)
  {
     c=Stdio.File();    
     if(!c->connect(host, port))
       error("Protocols.AJP.client.connection(): Unable to connect to " + host + ":" + port + ".");
  }

  mapping handle(object id)
  {
    inuse=1;
    mapping r=([]);
    
    inuse=0;
    return r;
  }
}
