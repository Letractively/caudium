/*
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

// (c) Daniel Podlejski
// $Id$

#define POSTINGOK "(posting ok)"

#define NNTPCMD(X) \
	if (!connection) return 0;\
	err = catch { \
		res = _cmd(X); \
	} \
	; \
	if (!res) return 0; \

#define NNTPPORT 119

class connection
{
  object connection = 0;
  int lastreply = 0;
  int locked = 0;
  // global error (socket, network, ...)
  mixed err = 0;
  // error in protocol
  string proto_err = ""; 
  int allowed2post = 0;
  
  void create(void|string connectionserver, void|int argport)
  {
    int port = NNTPPORT;
    if(argport)
      port = argport;
    if (!connectionserver && !(connectionserver = getenv("NNTPSERVER")))
       return;
  
    connection = Stdio.FILE();

    if (!connection->connect(connectionserver, port))
    {
       connection = 0;
       return;
    }
  
    string status = connection->gets();
    sscanf(status, "%d %s", lastreply, string rest);
    if(lastreply != 200)
    {
      proto_err = status;
      return 0;
    }
  }
  
  int close()
  {
    return connection->close();
  }

  string _gets()
  {
    string result = connection->gets();

    sscanf(result, "%s\r", result);
    write("NNTPClient: gets: " + result + "\n");
    return result;
  }

  string _cmd(string command)
  {
    write("NNTPClient: _cmd: " + command + "\n");
    connection->write(command + "\r\n");
    return _gets();
  }

  int reader()
  {
    string res;

    NNTPCMD("mode reader");

    sscanf(res, "%d %s", lastreply, res);

    if(search(res, POSTINGOK) != -1)
      allowed2post = 1;

    if (!err && lastreply >= 200 && lastreply < 300) return 1;

    proto_err = lastreply + " " + res;
    
    destruct(connection);

    connection = 0;

    return 0;
  }

  void quit()
  {
    string res;

    NNTPCMD("quit");

    if (!err) connection->close();

    destruct(connection);

    connection = 0;
  }

  array group(string name)
  {
    string res;

    NNTPCMD(sprintf("group %s", name));

    sscanf(res, "%d %d %d %d %s",
              lastreply, int msgcount, int minmsg, int maxmsg, name);

    if(err)
    {
      destruct(connection);
      connection = 0;
      return 0;
    }
    
    if(lastreply != 211)
    {
      proto_err = res;
      return 0;
    }
    
    return ({ msgcount, minmsg, maxmsg, name });
  }

  string article(void|int|string msgspec)
  {
    string res, article = "";

    if (!msgspec) msgspec = "";

    NNTPCMD(sprintf("article %s", (string)msgspec));

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 220) 
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    res = _gets();

    while (res != ".")
    {
      article += res + "\n";
      res = _gets();
    }

    return article;
  }

  string head(void|int|string msgspec)
  {
    string res, head = "";

    if (!msgspec) msgspec = "";

    NNTPCMD(sprintf("head %s", (string)msgspec));

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 221) 
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    res = _gets();

    while (res != ".")
    {
      head += res + "\n";
      res = _gets();
    }

    return head;
  }

  string body(void|int|string msgspec)
  {
    string res, body = "";

    if (!msgspec) msgspec = "";

    NNTPCMD(sprintf("body %s", (string)msgspec));

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 222)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      body += res + "\n";
      res = _gets();
    }

    return body;
  }

  mapping active(void|string groupname)
  {
    string res;
    mapping result = ([]);

    if(groupname)
    {
      NNTPCMD(sprintf("list active %s", groupname));
    }
    else
    {
      NNTPCMD("list active");
    }
    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 215) 
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s %d %d %s", string grp, int min, int max, int mode))
         result[grp] = ({ min, max, mode });

      res = _gets();
    }

    return result;
  }

  mapping active_times()
  {
    string res;
    mapping result = ([]);

    NNTPCMD("list active.times");

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 215)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s %d %s", string grp, int time, string who))
         result[grp] = ({ time, who });

      res = _gets();
    }

    return result;
  }

  mapping newsgroups(void|int|string groupname)
  {
    string res;
    mapping result = ([]);

    if(groupname)
    {
      NNTPCMD(sprintf("list newsgroups %s", (string) groupname));
    }
    else
    { 
      NNTPCMD("list newsgroups");
    }
    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 215)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s%[\t ]%s", string grp, string sep, string desc))
         result[grp] = desc;

      res = _gets();
    }

    return result;
  }

  mapping newgroups(string date)
  {
    string res;
    mapping result = ([]);

    NNTPCMD(sprintf("newgroups %s", date));
    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 231 && lastreply != 235)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s%[\t ]%s", string grp, string sep, string desc))
         result[grp] = desc;

      res = _gets();
    }

    return result;
  }

  mapping xhdr(string hdr, string msgspec)
  {
    string res;
    mapping result = ([]);

    NNTPCMD(sprintf("xhdr %s %s", hdr, msgspec));

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 221) 
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s%[\t ]%s", string msg, string space, string xhdrval))
         result[(int)msg || msg] = xhdrval;

      res = _gets();
    }

    return result;
  }

  mapping xover(string|int msgspec, void|string msgspec2)
  {
    string res;
    mapping result = ([]);
    if(!msgspec2)
    {
      NNTPCMD(sprintf("xover %s", (string) msgspec));
    }
    else
    {
      NNTPCMD(sprintf("xover %s-%s", (string) msgspec, (string) msgspec2));
    }
    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }
    if (lastreply != 224)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s%[\t ]%s", string msg, string space, string xoverval))
         result[(int)msg || msg] = xoverval / "\t";

      res = _gets();
    }

    return result;
  }

  int post(string message)
  {
    string res;
    NNTPCMD("post");

    sscanf(res, "%d %s", lastreply, res);
    
    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }
    if (lastreply != 340)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    
    NNTPCMD(message + "\r\n.\r\n");

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }
    if(lastreply != 240)
    {
      proto_err = lastreply + " " + res;
      return 0;
    }
    return 1;
  }
}
