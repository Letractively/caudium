/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
//    write(sprintf("     a = %O \n",a));
//    write(sprintf("     b = %O \n",b));
    return 1;
  }
}

// This retrun a ok or fail if test has fails
int returnok(int z) {
  if(z) {
    write(" fail\b");
    return 1;
  } else {
    write(" ok\n");
    return 0;
  }
}

// Write the test name ;-)
void prtest(string name) {
  write(sprintf("  Testing Caudium.%s()...\t",name));
}
  
int TEST_extension() {
  int out = 0;
  string a;
  mapping tst = ([ "caudium.c":"c",
                   "index.rxml":"rxml",
                   "foo.c~":"c",
                   "test.c#":"c",
                   "zorgl.php":"php",
                   "again.pof.rxml":"rxml" ]);
  prtest("extension");

  foreach(indices(tst), string foo) {
    out += result(tst[foo],Caudium.extension(foo)); 
  }

  return returnok(out);
}  

int TEST_http_date() {
  int tmstmp = time();
  string a, b;

  prtest("http_date");
  
  a = Calendar.ISO_UTC.Second(tmstmp)->format_http();
  b = Caudium.http_date(tmstmp);

  return returnok(result(a,b));
}

int TEST_cern_http_date() {
  int tmstmp = time();
  string a, b, c;
  mapping lt = localtime(tmstmp);
  int tzh = lt->timezone/3600 - lt->isdst;
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
  b = Caudium.cern_http_date(tmstmp);
 
  return returnok(result(a,b));
}

int main() {
  int failtests = 0;
  int alltests = 0;
  write("Starting testsuite for Caudium module...\n");
  
  foreach(indices(this_object()), string fun) {
    if(fun[..4]=="TEST_") {
      mixed err;
      alltests++;
      if (err = catch {
          failtests += this_object()[fun]();
      }) {
          write(sprintf("Error in test %s: %s\n",fun, describe_backtrace(err)));
          return 1;
         }
    }
  }
  
  write(sprintf("Tests (Successfull/Total) : %d/%d\n",
                alltests-failtests, alltests));

  if (failtests != 0) return 1;
  else return 0;
}
