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

// This test if result is ok or not...
int result(mixed a, mixed b) {
  if(a == b) {
    write("+");
    return 0;
  } else {
    write("-");
    return 1;
  }
}

// This retrun a ok or fail if test has fails
int returnok(int z) {
  if(z) {
    return 1;
  } else {
    return 0;
  }
}

// Do test with mapping in format "source":"destination" with function given
// in argument.
int mapping_test(mapping tst, function totest) {
  int out = 0;
  foreach(indices(tst), string foo) {
    out += result(tst[foo],totest(foo)); 
  }
  return returnok(out);
}
  
void TEST_extension() {
  mapping tst = ([ "caudium.c":"c",
                   "index.rxml":"rxml",
                   "foo.c~":"c",
                   "test.c#":"c",
                   "zorgl.php":"php",
                   "again.pof.rxml":"rxml" ]);
  mapping_test(tst, _Caudium.extension);
}  

void TEST_http_encode_cookie() {
  mapping tst = ([ "=":"%3D", 
                   ",":"%2C",
                   ";":"%3B",
                   "%":"%25",
                   ":":"%3A",
                   "CaudiumCookie=Zorglub; expires= baf":"CaudiumCookie%3DZorglub%3B expires%3D baf" ]);
  mapping_test(tst, _Caudium.http_encode_cookie);
}

void TEST_http_encode_string() {
  mapping tst = ([ " ":"%20", "\t":"%09", "\n":"%0A", "\r":"%0D",
                   "%":"%25", "'":"%27", "\"":"%22", "<":"%3C",
                   ">":"%3E", "@":"%40", "This is a test":"This%20is%20a%20test" ]);
  mapping_test(tst, _Caudium.http_encode_string);
}

void TEST_http_encode_url() {
  mapping tst = ([ " ":"%20", "\t":"%09", "\n":"%0A", "\r":"%0D",
                   "%":"%25", "'":"%27", "\"":"%22", "#":"%23",
                   "&":"%26", "?":"%3F", "=":"%3D", "/":"%2F",
                   ":":"%3A", "+":"%2B", "<":"%3C", ">":"%3E",
                   "@":"%40","http://caudium.net/":"http%3A%2F%2Fcaudium.net%2F" ]);
  mapping_test(tst, _Caudium.http_encode_url);
}

void TEST_http_decode_url() {
  mapping tst = ([ ]);
  int i;
  for(i = 0; i <= 255; i++)
    tst += ([ sprintf("%%%02x",i): String.int2char(i) ]);
  for(i = ' '; i <= 'z'; i++)
    if (String.int2char(i) == "+") 
      tst += ([ String.int2char(i): " " ]);
    else
      tst += ([ String.int2char(i): String.int2char(i) ]);
  mapping_test(tst, _Caudium.http_decode_url);
}

void TEST_http_decode() {
  mapping tst = ([ ]);
  int i;
  for(i = 0; i <= 255; i++)
    tst += ([ sprintf("%%%02x",i): String.int2char(i) ]);
  for(i = ' '; i <= 'z'; i++)
    tst += ([ String.int2char(i): String.int2char(i) ]);
  mapping_test(tst, _Caudium.http_decode);
}

void TEST_get_address() {
  mapping tst = ([ "127.0.0.1 12313":"127.0.0.1",
                   "192.168.255.1 0":"192.168.255.1",
                   "10.20.10.55 10":"10.20.10.55",
                   "zzzzzzzzz":"unknown", // Should never exist.
                   "12.5.2.5.2.1 80":"12.5.2.5.2.1",
                   "3ffe:200::1 6667":"3ffe:200::1", // IPv6 compatible :)
                  ]);
  mapping_test(tst, _Caudium.get_address);
}

void TEST_get_port() {
  mapping tst = ([ "127.0.0.1 12313":"12313",
                   "192.168.255.1 0":"0",
                   "192.168.255.3 1234567890":"1234567890", // Don't exist in real life... :)
                   "10.20.10.55 10":"10",
                   "zzzzzzzzz":"0", // Should never exist.
                   "12.5.2.5.2.1 80":"80",
                   "3ffe:200::1 6667":"6667", // IPv6 compatible :)
                  ]);
  mapping_test(tst, _Caudium.get_port);
}

         
void TEST_http_date() {
  int tmstmp = time();
  string a, b;

  a = Calendar.ISO_UTC.Second(tmstmp)->format_http();
  b = _Caudium.http_date(tmstmp);

  returnok(result(a,b));
}

void TEST_cern_http_date() {
  int tmstmp = time();
  string a, b, c;
  mapping lt = localtime(tmstmp);
  // Do we have to take care of Day Light time ? I think no - XB.
  int tzh = lt->timezone/3600; // - lt->isdst;

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
  b = _Caudium.cern_http_date(tmstmp);
 
  returnok(result(a,b));
}

int main() {
  write("Starting testsuite for _Caudium module...\n");
 
  for(int i; i < 500; i++) {
  foreach(indices(this_object()), string fun) {
    if(fun[..4]=="TEST_") {
      thread_create(this_object()[fun]());
    }
  }
  }
  
//  write("Functions tested (Successfull/Total) :\t%d/%d\n",
//         alltests-failtests, alltests);
//  write("Tests (individuals tests) :\t\t%d/%d\n",testsok,tests);
//  write("Gauge time :\t\t\t\t%f s\n",temps);

//  if (failtests != 0) return 1;
//  else return 0;
  while(sizeof(all_threads()) > 1) {
   write("Waiting for threads...\n");
   sleep(1);
  }
  return 0;
}
