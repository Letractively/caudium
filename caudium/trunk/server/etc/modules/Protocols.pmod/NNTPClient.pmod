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

#define NNTPCMD(X) \
	if (!connection) return 0;\
	err = catch { \
		res = _cmd(X); \
	} \
	; \
	if (!res) return 0;

class connection
{
  object connection = 0;
  int lastreply = 0;
  int locked = 0;
  mixed err = 0;
  
  void create(void|string connectionserver)
  {
    if (!connectionserver && !(connectionserver = getenv("NNTPSERVER")))
       return;
  
    connection = Stdio.FILE();
  
    if (!connection->connect(connectionserver, 119))
    {
       connection = 0;
       return;
    }
  
    string status = connection->gets();
  
    sscanf(status, "%d %s", lastreply, string rest);
  }
  
  int close()
  {
    return connection->close();
  }

  string _gets()
  {
    string result = connection->gets();

    sscanf(result, "%s\r", result);

    return result;
  }

  string _cmd(string command)
  {
    connection->write(command + "\r\n");
    return _gets();
  }

  int reader()
  {
    string res;

    NNTPCMD("mode reader");

    sscanf(res, "%d %s", lastreply, res);

    if (!err && lastreply >= 200 && lastreply < 300) return 1;

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

    if (!err && sscanf(res, "%d %d %d %d %s",
                       lastreply, int msgcount, int minmsg, int maxmsg, name))
       return ({ msgcount, minmsg, maxmsg, name });

    destruct(connection);

    connection = 0;

    return 0;
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

    if (lastreply != 220) return 0;

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

    if (lastreply != 221) return 0;

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

    if (lastreply != 222) return 0;

    res = _gets();

    while (res != ".")
    {
      body += res + "\n";
      res = _gets();
    }

    return body;
  }

  mapping active(void|string wildmat)
  {
    string res;
    mapping result = ([]);
    
    // BUG: don't remove {} or pike cpp will fail
    if(stringp(wildmat))
    {
      NNTPCMD(sprintf("list active %s", wildmat));
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

    if (lastreply != 215) return 0;

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

    if (lastreply != 215) return 0;

    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s %d %s", string grp, int time, string who))
         result[grp] = ({ time, who });

      res = _gets();
    }

    return result;
  }

  mapping newsgroups(void|string group)
  {
    string res;
    mapping result = ([]);
 
    if(stringp(group))
    {
      NNTPCMD(sprintf("list newsgroups %s", group));
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

    if (lastreply != 215) return 0;

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

    if (lastreply != 221) return 0;

    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s%[\t ]%s", string msg, string space, string xhdrval))
         result[(int)msg || msg] = xhdrval;

      res = _gets();
    }

    return result;
  }

  mapping xover(string msgspec)
  {
    string res;
    mapping result = ([]);

    NNTPCMD(sprintf("xover %s", msgspec));

    sscanf(res, "%d %s", lastreply, res);

    if (err)
    {
       destruct(connection);
       connection = 0;
       return 0;
    }

    if (lastreply != 224) return 0;

    res = _gets();

    while (res != ".")
    {
      if (sscanf(res, "%s%[\t ]%s", string msg, string space, string xoverval))
         result[(int)msg || msg] = xoverval / "\t";

      res = _gets();
    }

    return result;
  }
}
