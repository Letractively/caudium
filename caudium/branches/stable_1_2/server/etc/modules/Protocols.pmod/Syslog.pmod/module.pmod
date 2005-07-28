// $Id$
// Syslog interface (remote or local)

//!
void remote(int pri, string message, string host, int|void port) 
{
  object udp = Stdio.UDP();

  if (!intp(port) || port ==0) port = 514; // Default port value

  udp->bind(0);
  udp->send(host, port, sprinf("<%d> %s", pri, message));
  udp=0;
}

