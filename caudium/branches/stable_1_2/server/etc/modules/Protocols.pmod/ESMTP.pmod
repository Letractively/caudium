class protocol
{
  // Maybe this should be the other way around?
  inherit Protocols.NNTP.protocol;
}

class client
{
  inherit protocol;

  int is_esmtp;

  constant DSN_SUCCESS = 1;
  constant DSN_DELAY   = 2;
  constant DSN_FAILURE = 4;

  constant reply_codes =
  ([ 211:"System status, or system help reply",
     214:"Help message",
     220:"<host> Service ready",
     221:"<host> Service closing transmission channel",
     250:"Requested mail action okay, completed",
     251:"User not local; will forward to <forward-path>",
     354:"Start mail input; end with <CRLF>.<CRLF>",
     421:"<host> Service not available, closing transmission channel "
         "[This may be a reply to any command if the service knows it "
         "must shut down]",
     450:"Requested mail action not taken: mailbox unavailable "
         "[E.g., mailbox busy]",
     451:"Requested action aborted: local error in processing",
     452:"Requested action not taken: insufficient system storage",
     500:"Syntax error, command unrecognized "
         "[This may include errors such as command line too long]",
     501:"Syntax error in parameters or arguments",
     502:"Command not implemented",
     503:"Bad sequence of commands",
     504:"Command parameter not implemented",
     550:"Requested action not taken: mailbox unavailable "
         "[E.g., mailbox not found, no access]",
     551:"User not local; please try <forward-path>",
     552:"Requested mail action aborted: exceeded storage allocation",
     553:"Requested action not taken: mailbox name not allowed "
         "[E.g., mailbox syntax incorrect]",
     554:"Transaction failed" ]);

  static private int cmd(string c, string|void comment)
  {
    int r = command(c);
    switch(r) {
    case 200..399:
      break;
    default:
      throw(({"SMTP: "+c+"\n"+(comment?"SMTP: "+comment+"\n":"")+
	      "SMTP: "+reply_codes[r]+"\n", backtrace()}));
    }
    return r;
  }

  void create(void|string server, int|void port, void|string maildomain)
  {
    if(!server)
    {
      // Lookup MX record here (Using DNS.pmod)
      object dns=master()->resolv("Protocols")["DNS"]->client();
      server=dns->get_primary_mx(gethostname());
    }

    if(!port)
      port = 25;

    if(!server || !connect(server, port))
      {
	throw(({"Failed to connect to mail server.\n",backtrace()}));
      }

    if(readreturncode()/100 != 2)
      throw(({"Connection refused by SMTP server.\n",backtrace()}));

    string fqdn = gethostname ();
    fqdn += (maildomain) ? ("." + maildomain) : "";
    //werror ("ESMTP client: fqdn= " + fqdn + "\n");
    if(catch(cmd("EHLO "+fqdn))) {
      //werror ("Protocols.SMTP: not ESMTP server\n");
      is_esmtp = 0;
      cmd("HELO "+fqdn, "greeting failed.");
    }
    else {
      //werror ("Protocols.SMTP: ESMTP server\n");
      is_esmtp = 1;
    }
  }

  void send_message(string from, array(string) to, string body, void|int dsn_options)
  {
    string dsn_comm = "";
    if (is_esmtp && dsn_options) {
      if (dsn_options & DSN_DELAY) {
	//werror ("Protocols.SMTP: DSN_DELAY\n");
	dsn_comm = "DELAY";
      }
      if (dsn_options & DSN_SUCCESS) {
	//werror ("Protocols.SMTP: DSN_SUCCESS\n");
	dsn_comm += (sizeof(dsn_comm)>0?",":"")+"SUCCESS";
      }
      if (dsn_options & DSN_FAILURE) {
	//werror ("Protocols.SMTP: DSN_FAILURE\n");
	dsn_comm += (sizeof(dsn_comm)>0?",":"")+"FAILURE";
      }
    }
    //werror ("dsn_comm= " + dsn_comm + "\n");
    if (is_esmtp && dsn_options) {
      cmd("MAIL FROM: <" + from + "> RET=HDRS ENVID=IMHOMSG");
      //werror ("MAIL FROM: <" + from + "> RET=HDRS ENVID=IMHOMSG" + "\n");
    }
    else {
      cmd("MAIL FROM: <" + from + ">");
      //werror ("MAIL FROM: <" + from + ">" + "\n");
    }
    if (!is_esmtp || !sizeof (dsn_comm)) {
      foreach(to, string t) {
	cmd("RCPT TO: <" + t + ">");
	//werror ("RCPT TO: <" + t + ">" + "\n");
      }
    }
    else {
      foreach(to, string t) {
	cmd("RCPT TO: <" + t + "> NOTIFY=" + dsn_comm + " ORCPT=rfc822;" + t);
	//werror ("RCPT TO: <" + t + "> NOTIFY=" + dsn_comm + " ORCPT=rfc822;" + t + "\n");
      }
    }
    cmd("DATA");
    cmd(body+"\r\n.");
    cmd("QUIT");
    //werror ("ESMTP: mail sent.\n");
  }
}
