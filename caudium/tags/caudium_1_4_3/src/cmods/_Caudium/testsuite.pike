/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
/*
 * $Id$
 */

// Global variables
int tests = 0;		// Individual test counter.
int testsok = 0;	// Individual test counter for successfull tests.

// This write to stdout if result is ok or not
void write_result(int retcode, mixed a, mixed b) {
  tests++;
  if(!retcode) {
    testsok++;
    write("+");
  } else {
    write("-\n");
    write(sprintf("     a = %O \n",a));
    write(sprintf("     b = %O \n",b));
  }
}

// This retrun a ok or fail if test has fails
int returnok(int z) {
  if(z) {
    write("   fail\n");
    return 1;
  } else {
    write(" ok\n");
    return 0;
  }
}

// Write the test name ;-)
void prtest(string name) {
  write(sprintf("  Testing _Caudium.%-25s\t",name+"()..."));
}

// Do test with mapping in format "source":"destination" with function given
// in argument.
// The mapping can also in the form "source": ({ "destination1", "destination2" })
// In this case the test will fail only if source is not equal to destination1
// AND source is not equal to destination2. This is used to test functions that
// can output several good values
int mapping_test(mapping tst, function totest, void|mixed ...args) {
  int out = 0;
  foreach(indices(tst), string foo) {
    int i = 1, j = 0;
    array ress = ({ tst[foo] });
    if(arrayp(tst[foo]))
      ress = tst[foo];
    array ress_from_fun = allocate(sizeof(ress));

    foreach(ress, string res)
    {
      if(args && sizeof(args))
        ress_from_fun[j] = totest(foo, @args); 
      else
        ress_from_fun[j] = totest(foo);
      i &= !(res == ress_from_fun[j++]);
    }
    out |= i;
    write_result(out, ress, ress_from_fun);
  }
  return returnok(out);
}

int TEST_extension() {
  mapping tst = ([ "caudium.c":"c",
                   "index.rxml":"rxml",
                   "foo.c~":"c",
                   "test.c#":"c",
                   "zorgl.php":"php",
                   "again.pof.rxml":"rxml" ]);
  prtest("extension");
  return mapping_test(tst, _Caudium.extension);
}  

int TEST_http_encode_cookie() {
  mapping tst = ([ "=":"%3D", 
                   ",":"%2C",
                   ";":"%3B",
                   "%":"%25",
                   ":":"%3A",
                   "CaudiumCookie=Zorglub; expires= baf":"CaudiumCookie%3DZorglub%3B expires%3D baf" ]);
  prtest("http_encode_cookie");
  return mapping_test(tst, _Caudium.http_encode_cookie);
}

int TEST_http_encode_string() {
  mapping tst = ([ " ":"%20", "\t":"%09", "\n":"%0A", "\r":"%0D",
                   "%":"%25", "'":"%27", "\"":"%22", "<":"%3C",
                   ">":"%3E", "@":"%40", "This is a test":"This%20is%20a%20test",
		   "http://elvira.linkeo.intra/(SessionID=7dae0552e4e9ad8fa7163dedd273dae3)/mail_camastemplates/Caudium%20WWW/images/ico-messageattachment.gif": "http://elvira.linkeo.intra/(SessionID=7dae0552e4e9ad8fa7163dedd273dae3)/mail_camastemplates/Caudium%2520WWW/images/ico-messageattachment.gif" ]);
  prtest("http_encode_string");
  return mapping_test(tst, _Caudium.http_encode_string);
}

int TEST_http_encode_url() {
  mapping tst = ([ " ":"%20", "\t":"%09", "\n":"%0A", "\r":"%0D",
                   "%":"%25", "'":"%27", "\"":"%22", "#":"%23",
                   "&":"%26", "?":"%3F", "=":"%3D", "/":"%2F",
                   ":":"%3A", "+":"%2B", "<":"%3C", ">":"%3E",
                   "@":"%40","http://caudium.net/":"http%3A%2F%2Fcaudium.net%2F",
                   "eaud.b@free.fr":"eaud.b%40free.fr"
  ]);
  prtest("http_encode_url");
  return mapping_test(tst, _Caudium.http_encode_url);
}

int TEST_http_decode_url() {
  mapping tst = ([ ]);
  int i;
  for(i = 0; i <= 255; i++)
    tst += ([ sprintf("%%%02x",i): String.int2char(i) ]);
  for(i = ' '; i <= 'z'; i++)
    if (String.int2char(i) == "+") 
      tst += ([ String.int2char(i): " " ]);
    else
      tst += ([ String.int2char(i): String.int2char(i) ]);
  prtest("http_decode_url");
  return mapping_test(tst, _Caudium.http_decode_url);
}

int TEST_http_decode() {
  mapping tst = ([ ]);
  int i;
  for(i = 0; i <= 255; i++)
    tst += ([ sprintf("%%%02x",i): String.int2char(i) ]);
  for(i = ' '; i <= 'z'; i++)
    tst += ([ String.int2char(i): String.int2char(i) ]);
  prtest("http_decode");
  return mapping_test(tst, _Caudium.http_decode);
}

int TEST_get_address() {
  mapping tst = ([ "127.0.0.1 12313":"127.0.0.1",
                   "192.168.255.1 0":"192.168.255.1",
                   "10.20.10.55 10":"10.20.10.55",
                   "zzzzzzzzz":"unknown", // Should never exist.
                   "12.5.2.5.2.1 80":"12.5.2.5.2.1",
                   "3ffe:200::1 6667":"3ffe:200::1", // IPv6 compatible :)
                  ]);
  prtest("get_address");
  return mapping_test(tst, _Caudium.get_address);
}

int TEST_get_port() {
  mapping tst = ([ "127.0.0.1 12313":"12313",
                   "192.168.255.1 0":"0",
                   "192.168.255.3 1234567890":"1234567890", // Don't exist in real life... :)
                   "10.20.10.55 10":"10",
                   "zzzzzzzzz":"0", // Should never exist.
                   "12.5.2.5.2.1 80":"80",
                   "3ffe:200::1 6667":"6667", // IPv6 compatible :)
                  ]);
  prtest("get_port");
  return mapping_test(tst, _Caudium.get_port);
}

int TEST__make_tag_attributes() {
  mapping tst = ([ ([
                    "href":"/mailmailindex--?mbox=INBOX&amp;msguid=3522&amp;actionread=1",
                    "target":"mailindex"
                   ]): ({ "href=\"/mailmailindex--?mbox=INBOX&amp;amp;msguid=3522&amp;amp;actionread=1\" target=\"mailindex\" ", "target=\"mailindex\" href=\"/mailmailindex--?mbox=INBOX&amp;amp;msguid=3522&amp;amp;actionread=1\" " }),
		   ([ "input": "test", "foo\"a": "bar&<>" ]): ({ "input=\"test\" foo&#34;a=\"bar&amp;&lt;&gt;\" ", "foo&#34;a=\"bar&amp;&lt;&gt;\" input=\"test\" " })
                 ]);
  prtest("_make_tag_attributes");
  return mapping_test(tst, _Caudium._make_tag_attributes, 1);
}

int TEST_parse_entities() {
  mapping tst = ([ 
                  "&gt;&gt;": "&gt;&gt;",
                  "&camas.login;": "&camas.login;",
                ]);
  prtest("parse_entities");
  return mapping_test(tst, _Caudium.parse_entities, ([ ]));
}

int TEST2_parse_entities() {
    class EmitScope(mapping v) {
    string name = "emit";

    string get(string entity) {
      return v[entity];
    }
  };

  mapping tst = ([ 
                    "\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<td class=\"loopprev\">\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<href action=\"gopage\" countpageloop=\"&navbar_loop_previous.number;\"><img src=\"/mail_camastemplates/Caudium%20WWW/images/page.gif\" alt=\"&navbar_loop_previous.number;\" border=\"0\"><br>&navbar_loop_previous.number;</href>\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t": "\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<td class=\"loopprev\">\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<href action=\"gopage\" countpageloop=\"27\"><img src=\"/mail_camastemplates/Caudium%20WWW/images/page.gif\" alt=\"27\" border=\"0\"><br>27</href>\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
                ]);
  prtest("parse_entities");
  mapping v = ([ 
    "number": "27"
    ]);
  return mapping_test(tst, _Caudium.parse_entities, ([ "navbar_loop_previous": EmitScope(v) ]));
}

int TEST3_parse_entities() {
  class scope
  {
    string get(string val)
    {
      if(val=="test2")
	return upper_case(val);
      else
	return 0;
    }
  };
 
  mapping tst = ([
                 "&nbsp; &test; &test.test2; &nbsp;": "&nbsp; &test; TEST2 &nbsp;",
		 "&nbsp; &nbsp; &test; &test.test2; &nbsp; 12345 &nbsp; 12345 &test; &test.test2;": "&nbsp; &nbsp; &test; TEST2 &nbsp; 12345 &nbsp; 12345 &test; TEST2"
                ]);
  prtest("parse_entities");
  return mapping_test(tst, _Caudium.parse_entities, ([ "test": scope() ]));
}

int TEST4_parse_entities()
{
  class scope2
  {
    string get(string val, mixed a)
    {
      return upper_case(val);
    }
  };
  mapping tst = ([
                   "entity that exists: &test.ent2; -- should be ENT2\n"
     "entity that exists: &test.blahblah; -- should be BLAHBLAH\n"
     "scope that doesn't exist: &see.wah; -- should be ampsee.wahsemi\n"
     "scope doesnt exit, but no subpart: &ent; -- should be ampentsemi\n\n"
     "scope exists, but no subpart: &blah; -- should be ampblahsemi\n\n": "entity that exists: ENT2 -- should be ENT2\nentity that exists: BLAHBLAH -- should be BLAHBLAH\nscope that doesn't exist: &see.wah; -- should be ampsee.wahsemi\nscope doesnt exit, but no subpart: &ent; -- should be ampentsemi\n\nscope exists, but no subpart: &blah; -- should be ampblahsemi\n\n"
                ]);
   prtest("parse_entities");
   return mapping_test(tst, _Caudium.parse_entities, ([ "test": scope2() ]));
}

int TEST_http_date() {
  int tmstmp = time();
  prtest("http_date");
  mapping tst = ([ tmstmp: Calendar.ISO_UTC.Second(tmstmp)->format_http() ]);

  return mapping_test(tst, _Caudium.http_date);
}

int TEST_cern_http_date() {
  int tmstmp = time();
  string a, c;
  mapping lt = localtime(tmstmp);
  // Do we have to take care of Day Light time ? I think no - XB.
  int tzh = lt->timezone/3600; // - lt->isdst;
  prtest("cern_http_date");

  if(tzh > 0)
    c = "-";
  else {
    tzh = -tzh;
    c = "+";
  }
  constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
  a = sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
              lt->mday, months[lt->mon], 1900+lt->year,
              lt->hour, lt->min, lt->sec, c, tzh);
  mapping tst = ([ tmstmp: a ]);
 
  return mapping_test(tst, _Caudium.cern_http_date);
}

int main() {
  int failtests = 0;
  int alltests = 0;
  float temps;
  write("Starting testsuite for _Caudium module...\n");
 
  temps = gauge { 
  foreach(indices(this_object()), string fun) {
    if(sscanf(fun, "TEST%*s_%*s") >= 1) {
      mixed err;
      alltests++;
      if (err = catch {
          failtests += this_object()[fun]();
      }) {
          write("Error in test %s: %s\n",fun, describe_backtrace(err));
          return 1;
         }
    }
  }
  };
  
  write("Functions tested (Successfull/Total) :\t%d/%d\n",
         alltests-failtests, alltests);
  write("Tests (individuals tests) :\t\t%d/%d\n",testsok,tests);
  write("Gauge time :\t\t\t\t%f s\n",temps);

  if (failtests != 0) return 1;
  else return 0;
}
