/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

//
//! module: Countdown
//!  Defines the &lt;countdown&gt; tag.
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
//! tag: countdown
//!  This tag counts the time to or from a specified date.
//
//! attribute: [day = number|weekday]
//!  Sets the weekday.
//
//! attribute: [hour = number]
//!  Sets the hour.
//
//! attribute: [iso = year-month-day]
//!  Sets the year, month and day, all at once, in the ISO format.
//
//! attribute: [mday = number]
//!  Sets the day of month.
//
//! attribute: [min = number]
//!  Sets the minute.
//
//! attribute: [month = number|month]
//!  Sets the month.
//
//! attribute: [sec = number]
//!  Sets the second.
//
//! attribute: [year = number]
//!  Sets the year.
//
//! attribute: [combined]
//!  Shows an English text describing the time period. Example: 2
//!  days, 1 hour and 5 seconds. You may use the prec attribute to
//!  limit how precise the description should be. You can also use
//!  the month attribute if you want to see years/months/days
//!  instead of years/weeks/days.
//
//! attribute: [days]
//!  Prints the number of days until the time.
//
//! attribute: [dogyears]
//!  Prints the number of dog years until the time, with one decimal.
//
//! attribute: [hours]
//!  Prints the number of hours until the time.
//
//! attribute: [lang = ca|es_CA|hr|cs|nl|en|fi|fr|de|hu|it|jp|mi|no|pt|ru|sr|si|es|sv
//!  Will print the result as words in the chosen language if used
//!  together with type=string. Available languages are ca, es_CA
//!  (Catalan), hr (Croatian), cs (Czech), nl (Dutch), en (English),
//!  fi (Finnish), fr (French), de (German), hu (Hungarian), it
//!  (Italian), jp (Japanese), mi (Maori), no (Norwegian), pt
//!  (Portuguese), ru (Russian), sr (Serbian), si (Slovenian), es
//!  (Spanish) and sv (Swedish).
//
//! attribute: [minutes]
//!  Prints the number of minutes until the time.
//
//! attribute: [months]
//!  Prints the number of month until the time.
//
//! attribute: [nowp]
//!  Returns 1 if the specified time is now, otherwise 0. How
//!  precise now should be interpreted is defined by the prec
//!  attributes. The default precision is one day.
//
//! attribute: [prec = year|month|week|day|hour|minute|second]
//!  A modifier for the nowp and combined attributes. Sets the
//!  precision for these attributes.
//
//! attribute: [seconds]
//!  Prints how many seconds until the time.
//          
//! attribute: [since]
//!  Counts from a time rather than towards it.
//          
//! attribute: [type = string|number|ordered]
//!  How to present the result.
//
//! attribute: [weeks]
//!  Prints the number of weeks until the time.
//
//! attribute: [when]
//!  Prints when the time will occur. All valid &lt;date> tag
//!  attributes can be used.
//
//! attribute: [years]
//!  Prints the number of years until the time.
//
/* Countdown tag. Counts down to the specified data */

constant cvs_version="$Id$";
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER; 
constant module_name = "Countdown";
constant module_doc  = "This module adds a new tag, when enabled, see "
	    "&lt;countdown help&gt; for usage information.";
constant module_unique = 1;
class Date 
{
  int unix_time;
  mapping split;

  int `<(object|int q)
  {
    if(objectp(q)) return unix_time < q->unix_time;
    else return unix_time < q;
  }

  int `>(object|int q)
  {
    return !`<(q);
  }

  int year(int|void y)
  {
    if(y) split->year = y-1900;
    return split->year+1900;
  }
  
  int month(int|void m)
  {
    if(m) split->mon = m-1;
    return split->mon;
  }

  int set_to_easter()
  {
    int year = (split->year+1900);
    int t = unix_time;
    int G = year % 29;
    int C = year / 1000;
    int H = (C - C/4 - (8*C+13)/25 + 19*G + 15) % 30;
    int I = H - (H/28) * (1 - (H/28)*(29/(H+1))) * ((21 - G)/11);
    int J = (year + year/4 + 1 + 2 - C + C/4)%7;
    int L = I-J;

    m_delete(split, "wday");
    m_delete(split, "yday");

    split->mon = (3 + (L + 40)/44) - 1;
    split->mday = L + 28 - 31*(((3 + (L + 40)/44))/4);
    split = localtime(unix_time = mktime(split));

    if(unix_time < t)
    {
      split->year++;
      set_to_easter();
    }
  }
  
  int day(int|void d)
  {
    if(d) split->wday = d-1;
    return split->wday;
  }
  
  int mday(int|void d)
  {
    if(d) split->mday = d;
    return split->mday;
  }

  int yday()
  {
    return split->yday;
  }
  
  int leapyearp(int|void yea)
  {
    if(!yea) yea=year();
    if(!(yea%4000)) return 0;
    if(!(yea%100) && (yea%400)) return 0;
    if(!(yea%4)) return 1;
  }

  void create(mixed what)
  {
    if(intp(what)) unix_time = what;
    if(mappingp(what)) unix_time = mktime( what );
    split = localtime( unix_time );
  }
};

// Special events.
object event = class
{
#define S_EVENT(E,D,M) mapping E = ([ "mday":(D), "mon":((M)-1) ])
  private static inherit Date;

  S_EVENT(christmas_eve, 24, 12);
  S_EVENT(christmas_day, 25, 12);
  mapping christmas = christmas_day;
  mapping year2000 = ([ "mday":1, "mon":0, "hour":0, "min":0, "year":100 ]);

  void easter(mapping m)
  {
    object t = Date(localtime(time())|m);
    t->set_to_easter();
    m->year = t->year()-1900;
    m->mon = t->month()-1;
    m->mday = t->mday();
  }
}();


// :-) This code is not exactly conforming to the Roxen API, since it
// uses a rather private mapping the language object (which you are
// not even supposed to know the existence of). But I wanted some nice
// month->number code that did not depend on a static mapping.
// Currently, this means that you can enter the name of the month or day in
// your nativ language, if it is supported by roxen.
constant language = caudium->language;
int find_a_month(string which)
{
  which = lower_case(which);
  foreach(indices(caudium->languages), string lang)
    for(int i=1; i<13; i++)
      catch {
      if(which == lower_case(language(lang,"month")(i))[..strlen(which)])
	return i-1;
    };
  return 1;
}

int find_a_day(string which)
{
  which = lower_case(which);
  foreach(indices(caudium->languages), string lang)
    for(int i=1; i<8; i++)
      if(which == lower_case(language(lang,"day")(i))[..strlen(which)])
	return i;
  return 1;
}


string show_number(int n,mapping m)
{
  return number2string(n,m,language(m->lang,m->ordered?"ordered":"number"));
}

void apply_event(mapping ct, function|mapping evnt, mapping m)
{
  //  perror("apply event %O\n", evnt);
  if(mappingp(evnt))
    foreach(indices(evnt), string q)
      ct[q] = evnt[q];
  else
    evnt(ct,m);
}

string describe_events()
{
  string res="<tr><td><br><b>Special events:</b></td>";
  foreach(sort(indices(event)), string s)
    if(s[0]!='_')
      res += "<tr><td>"+s+"</td></tr>\n";
  return res;
}

string describe_example(array a)
{
  return ("<b><font size=+1>"+a[0]+"</font></b><br>"
	  "<b>Source:</b> "+replace(a[1], ({ "<", ">", "&" }), 
				   ({ "&lt;", "&gt;", "&amp"}))
	  +"<br><b>Result:</b> "+a[1]+"<p>");
				   
}

#define E(X,Y) ({ X, Y })

constant examples = 
({
  E("The age of something", "Per Hedbor is <countdown iso=1973-01-16 since years type=string> years old"),

//   E("When is the next easter?", "The next easter will be <countdown easter when date>, which is a <countdown easter when date part=day type=string>"),

//   E("When is easter year 2000?", "<countdown easter year=2000 when date>, which is a <countdown easter when date part=day type=string>"),

  E("How many days are left to year 2000?", "There are <countdown year2000 days> days left until year 2000"),

  E("Which date is the first monday in January 1998?",
    "<countdown month=january day=monday year=1998 date when part=date type=ordered>"),

  E("Is this a Sunday?",
    "<if eval='<countdown day=sunday nowp>'>This is indeed a Sunday</if><else>Nope</else>."),

  E("On which day will the next christmas eve be?",
    "It will be a <countdown christmas_eve lang=en when date part=day type=string>"),

  E("How old Fredrik & Monica Hübinette's dog Sadie?",
    "She is <countdown iso=1998-03-29 prec=day since months combined> old or <countdown iso=1998-03-29 prec=day since dogyears> dog years."),
});

string describe_examples()
{
  return "</b><p>"+Array.map(examples, describe_example)*"";
}

string usage()
{
  return ("<h1>The &lt;countdown&gt; tag.</h1>\n"
	  "This tag can count days, minutes, months, etc. from a specified date or time. It can also "
	  "give the time to or from a few special events. See below for a full list."
	  "<p>\n\n"
	  "<b>Time:</b>\n"
	  "<table border=0 cellpadding=0 cellspacing=0>\n"
	  "<tr valign=top><td>year=int</td><td><i>sets the year</i></td></tr>\n"
	  "<tr valign=top><td>month=int|month_name&nbsp;</td><td><i>sets the month</i></td></tr>\n"
	  "<tr valign=top><td>day=int|day_name</td><td><i>sets the weekday</i></td></tr>\n"
	  "<tr valign=top><td>mday=int</td><td><i>sets the day of the month</i></td></tr>\n"
	  "<tr valign=top><td>hour=int</td><td><i>sets the hour. Might be useful, perhaps..</i></td></tr>\n"
	  "<tr valign=top><td>min=int</td><td><i>sets the minute.</i></td></tr>\n"
	  "<tr valign=top><td>sec=int</td><td><i>sets the second.</i></td></tr>\n"
	  "<tr valign=top><td>iso=year-month-day</td><td><i>Sets the year, month and day all at once</i></td></tr>\n"
	  +describe_events()+
	  "<tr valign=top><td><br><b>Presentation:</b></tr></tr>"
	  "<tr valign=top><td>when</td><td><i>Shows when the time will occur. All arguments that are valid in a &lt;date&gt; tag can be used to modify the display</i></td></tr>\n"
	  "<tr valign=top><td>years</td><td><i>How many years until the time</i></td></tr>\n"
	  "<tr valign=top><td>months</td><td><i>How many months until the time</i></td></tr>\n"
	  "<tr valign=top><td>weeks</td><td><i>How many weeks until the time</i></td></tr>\n"
	  "<tr valign=top><td>days</td><td><i>How many days until the time</i></td></tr>\n"
	  "<tr valign=top><td>hours</td><td><i>How many hours until the time</i></td></tr>\n"
	  "<tr valign=top><td>minutes</td><td><i>How many minutes until the time</i></td></tr>\n"
	  "<tr valign=top><td>seconds</td><td><i>How many seconds until the time</i></td></tr>\n"
	  "<tr valign=top><td>combined</td><td><i>Shows an english text describing the time period. Example: 2 days, 1 hour and 5 seconds. You may use the 'prec' tag to limit how precise the description is. Also, you can use the 'month' tag if you want to see years/months/days instead of years/weeks/days.</i></td></tr>\n"
	  "<tr valign=top><td>dogyears</td><td><i>How many dog-years until the time. (With one decimal)</i></td></tr>\n"
	  "<tr valign=top><td>type=type, lang=language </td><td><i>As for 'date'. Useful values for type include string, number and ordered.</i></td></tr>\n"
	  "<tr valign=top><td>since</td><td><i>Negate the period of time (replace 'until' with 'since' in the above sentences to see why it is named 'since') </i></td></tr>\n"
	  "<tr valign=top><td>nowp</td><td><i>Return 1 or 0, depending on if the time is _now_ or not. The fuzziness of 'now' is decided by the 'prec' option. By default, this is set to 'day'</td></tr>"
	  "<tr valign=top><td>prec</td><td><i>modifier for 'nowp' and 'combined'. Can be one of "
	  "year, month, week, day, hour minute of second.</td></tr></table>"+
	  "<p><b>Examples</b>"+
	  describe_examples());
  
}


// This function should be fixed to support different languages.
// Possibly even implemented in the language module itself.
// Hubbe
string time_period(int t,
		   int|void noseconds,
		   mapping m)
{
  int i;
  array(string) tmp = ({});
  if(!t)
    return "zero seconds";
  if(!noseconds)
    if(i=t%60) tmp=({i+ " second"+(i==1?"":"s") });

  t/=60;
  if(i=t%60) tmp=({i+ " minute"+(i==1?"":"s") })+tmp;
  t/=60;
  if(i=t%24) tmp=({i+ " hour"+(i==1?"":"s") })+tmp;
  t/=24;

  if(!m->months)
  {
    if(i<365)
    {
      if(i=t%7) tmp=({i+ " day"+(i==1?"":"s") })+tmp;
      if(i=t/7) tmp=({i+ " week"+(i==1?"":"s") })+tmp;
    } else {
      if(i=t%365) tmp=({i+ " day"+(i==1?"":"s") })+tmp;
      if(i=t/365) tmp=({i+ " year"+(i==1?"":"s") })+tmp;
    }
  }else{
#define MONTHS_DAY (365.25/12)
    if(i=(int)floor(t%MONTHS_DAY))  tmp=({i+ " day"+(i==1?"":"s") })+tmp;
    t=(int)floor(t/MONTHS_DAY);
    if(i=t%12) tmp=({i+ " month"+(i==1?"":"s") })+tmp;
    t/=12;
    if(i=t) tmp=({i+ " year"+(i==1?"":"s") })+tmp;
  }
  return String.implode_nicely(tmp);
}

string tag_countdown(string t, mapping m, object id)
{
  string|int prec;
  mapping time_args = ([]);

  CACHE(10);

  if(m->help) return usage();
  
  foreach(indices(m), string q)
  {
    switch(q)
    {
     case "year":
       time_args->year = ((int)m->year-1900);
       if(time_args->year < -1800)
	 time_args->year += 1900;
       prec="year";
       m_delete(m, "year");
       break;
     case "iso":
       if(sscanf(m->iso, "%d-%d-%d", 
		 time_args->year, time_args->mon, time_args->mday)==3)
       {
	 m_delete(m, "iso");
	 prec="day";
	 time_args->mon--;
	 if(time_args->year>1900) time_args->year-=1900;
       }
       break;
     case "month":
       if(!(int)m->month) m->month = find_a_month(m->month)+1;
       prec="month";
       time_args->mon = (int)m->month-1;
       m_delete(m, "month");
       break;
     case "day":
       if(!(int)m->day) m->day = find_a_day(m->day);
       prec="day";
       time_args->wday = (int)m->day-1;
       m_delete(m, "day");
       break;
     case "mday":
       prec="day";
       time_args->mday = (int)m->date;  
       m_delete(m, "mday");
       break;
    }
  }

  foreach(indices(m), string q)
  {  
    if(event[q]) { apply_event(time_args, event[q], m); break; }
    if((int)m->q) time_args[q] = (int)m->q;
  }

  int when;
  mapping tmp = localtime(time());

  if(time_args->wday && zero_type(time_args->mon))
  {
    int offset = (time_args->wday - tmp->wday);
    if(offset < 0) offset += 7;
    time_args->mday = tmp->mday + offset;
    m_delete(time_args, "wday");
  }
  if(zero_type(time_args->year)) time_args->year = tmp->year;  
  if(zero_type(time_args->mon))  time_args->mon = tmp->mon;  

  if(catch {
    when = mktime(time_args);
  })
    return "Invalid time.";
  if(!zero_type(time_args->wday)) {
    int weeks = time_args->wday/7;
    if (time_args->wday < 0) {
      weeks--;
    }
    weeks *= 7;
    when += weeks * 3600*24;
    time_args->wday -= weeks;
    while((localtime(when)->wday) != (time_args->wday))
      when += 3600*24;
  }
  if(m->prec) prec = m->prec; // Must be done after the above test for events.
  switch(prec)
  {
   case "year": prec=(int)(3600*24*365.25); break;
   case "month": prec=(int)(3600*24*(365.25/12.0)); break;
   case "week": prec=3600*24*7; break;
   case "day": prec=3600*24; break;
   case "hour": prec=3600; break;
   case "minute": prec=60; break;
   case "min": prec=60; break;
   default: prec=1; break;
  }
  if(prec >= 3600*24)
    tmp->hour = tmp->min = 0;
  if(m->when)
  {
    m->unix_time = (string)when;
    return make_tag("date", m);
  }

  int delay = when-time(1);
  if(m->since || m->age) delay = -delay;

  // Real countdown stuff.
  if(m->combined)
  {
    delay+=prec/2;
    delay-=delay%prec;
    return time_period( delay, 0, m); // Hubbe
  }
  if(m->dogyears)
  {
    return sprintf("%1.1f",(delay/(3600*24*365.25/7)));
  }
  if(m->years) return  show_number((int)(delay/(3600*24*365.25)),m);
  if(m->months) return show_number((int)(delay/((3600*24*365.25)/12)),m);
  if(m->weeks) return  show_number(delay/(3600*24*7),m);
  if(m->days) return   show_number(delay/(3600*24),m);
  if(m->hours) return  show_number(delay/3600, m);
  if(m->minutes) return show_number(delay/60,m);
  if(m->seconds) return show_number(delay,m);


  // 1 or 0, for use with <if eval=...></if>
  if(m->nowp) return (string)((when/prec) == (mktime(tmp)/prec));
  return usage();
}

mapping query_tag_callers()
{
  return ([ "countdown":tag_countdown, ]);
}
