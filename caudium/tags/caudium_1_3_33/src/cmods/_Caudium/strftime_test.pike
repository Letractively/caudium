


string strftime(string fmt, int t)
{
  mapping lt = localtime(t);
  array a = fmt/"%";
  int i;
  for (i=1; i < sizeof(a); i++) {
    if (!sizeof(a[i])) {
      a[i] = "%";
      i++;
      continue;
    }
    string res = "";
    switch(a[i][0]) {
    case 'a':	// Abbreviated weekday name
      res = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" })[lt->wday];
      break;
    case 'A':	// Weekday name
      res = ({ "Sunday", "Monday", "Tuesday", "Wednesday",
	       "Thursday", "Friday", "Saturday" })[lt->wday];
      break;
    case 'b':	// Abbreviated month name
    case 'h':	// Abbreviated month name
      res = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
	       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" })[lt->mon];
      break;
    case 'B':	// Month name
      res = ({ "January", "February", "March", "April", "May", "June",
	       "July", "August", "September", "October", "November", "December" })[lt->mon];
      break;
    case 'c':	// Date and time
      res = strftime(sprintf("%%a %%b %02d  %02d:%02d:%02d %04d",
			     lt->mday, lt->hour, lt->min, lt->sec, 1900 + lt->year), t);
      break;
    case 'C':	// Century number; 0-prefix
      res = sprintf("%02d", 19 + lt->year/100);
      break;
    case 'd':	// Day of month [1,31]; 0-prefix
      res = sprintf("%02d", lt->mday);
      break;
    case 'D':	// Date as %m/%d/%y
      res = strftime("%m/%d/%y", t);
      break;
    case 'e':	// Day of month [1,31]; space-prefix
      res = sprintf("%2d", lt->mday);
      break;
    case 'H':	// Hour (24-hour clock) [0,23]; 0-prefix
      res = sprintf("%02d", lt->hour);
      break;
    case 'I':	// Hour (12-hour clock) [1,12]; 0-prefix
      res = sprintf("%02d", 1 + (lt->hour + 11)%12);
      break;
    case 'j':	// Day number of year [1,366]; 0-prefix
      res = sprintf("%03d", lt->yday);
      break;
    case 'k':	// Hour (24-hour clock) [0,23]; space-prefix
      res = sprintf("%2d", lt->hour);
      break;
    case 'l':	// Hour (12-hour clock) [1,12]; space-prefix
      res = sprintf("%2d", 1 + (lt->hour + 11)%12);
      break;
    case 'm':	// Month number [1,12]; 0-prefix
      res = sprintf("%02d", lt->mon + 1);
      break;
    case 'M':	// Minute [00,59]
      res = sprintf("%02d", lt->min);
      break;
    case 'n':	// Newline
      res = "\n";
      break;
    case 'p':	// a.m. or p.m.
      if (lt->hour < 12) {
	res = "a.m.";
      } else {
	res = "p.m.";
      }
      break;
    case 'r':	// Time in 12-hour clock format with %p
      res = strftime("%l:%M %p", t);
      break;
    case 'R':	// Time as %H:%M
      res = sprintf("%02d:%02d", lt->hour, lt->min);
      break;
    case 'S':	// Seconds [00,61]
      res = sprintf("%02", lt->sec);
      break;
    case 't':	// Tab
      res = "\t";
      break;
    case 'T':	// Time as %H:%M:%S
      res = sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'u':	// Weekday as a decimal number [1,7], Sunday == 1
      res = sprintf("%d", lt->wday + 1);
      break;
    case 'w':	// Weekday as a decimal number [0,6], Sunday == 0
      res = sprintf("%d", lt->wday);
      break;
    case 'x':	// Date
      res = strftime("%a %b %d %Y", t);
      break;
    case 'X':	// Time
      res = sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'y':	// Year [00,99]
      // FIXME: Does this handle negative years.
      res = sprintf("%02d", lt->year % 100);
      break;
    case 'Y':	// Year [0000.9999]
      res = sprintf("%04d", 1900 + lt->year);
      break;

    case 'U':	/* FIXME: Week number of year as a decimal number [00,53],
		 * with Sunday as the first day of week 1
		 */
      break;
    case 'V':	/* Week number of the year as a decimal number [01,53],
		 * with  Monday  as  the first day of the week.  If the
		 * week containing 1 January has four or more  days  in
		 * the  new  year, then it is considered week 1; other-
		 * wise, it is week 53 of the previous  year,  and  the
		 * next week is week 1
		 */
      break;
   case 'W':	/* FIXME: Week number of year as a decimal number [00,53],
		 * with Monday as the first day of week 1
		 */
      break;
    case 'Z':	/* FIXME: Time zone name or abbreviation, or no bytes if
		 * no time zone information exists
		 */
      break;
    default:
      // FIXME: Some kind of error indication?
      break;
    }
    a[i] = res + a[i][1..];
  }
  return(a*"");
}


int main()
{
  array a = ({ "a", "A", "b", "h", "c", "C", "d", "D", "e", "H", "I",
             "J", "k", "l", "m", "m", "n", "p", "r", "R", "S", "t",
             "T", "u", "w", "x", "X", "y", "Y" });
  foreach(a, string foo) {
   string stst = "%"+foo;
   write("Testing : %s\n", stst);
   write("Caudium: ");
   write("%O",_Caudium.strftime(stst,time()));
   write("\n");
   write("Legacy:  ");
   catch {
   write("%O",strftime(stst,time()));
   };
   write("\n");
  }
  return 0;
}       
