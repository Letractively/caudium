/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

string cvs_version = "$Id$";

object           Now;
array(string)    months;
array(string)    months_short;
array(string)    days;
array(string)    days_short;
array(string)    the_words = ({
    "year", "month", "week", "day"
});

void initialize_months(object now)
{
    // workaround for a Pike Calendar module bug
    array(object)   cmonths = now->year()->months();
    months = allocate(12);
    months_short = allocate(12);
    
    for(int i = 0; i < 12; i++) {
        months[i] = cmonths[i]->month_name();
        months_short[i] = cmonths[i]->month_shortname();
    }    
}

void initialize_days(object now)
{
    // workaround for a Pike Calendar module bug
    array(object)   cdays = now->week()->days();
    days = allocate(7);
    days_short = allocate(7);

    for(int i = 0; i < 7; i++) {
        days[i] = cdays[i]->week_day_name();
        days[i] = cdays[i]->week_day_shortname();
    }
}

string month(int num)
{
    if (num > 0 && num <= sizeof(months))
        return months[num - 1];
    else
        return "?";
}

string month_short(int num)
{
    if (num > 0 && num <= sizeof(months_short))
        return months_short[num - 1];
    else
        return "?";
}

string ordered(int i)
{
    switch(i)
    {
        case 0:
            return "buggy";
        case 1:
            return "1st"; 
        case 2:
            return "2nd";
        case 3:
            return "3rd";
        default:
            if((i%100 > 10) && (i%100 < 14))
                return i+"th";
            if((i%10) == 1)  
                return i+"st";
            if((i%10) == 2) 
                return i+"nd";
            if((i%10) == 3)
                return i+"rd";
            return i+"th";
    }
}

string date(int timestamp, mapping|void m)
{
    object  target = Calendar.Second("unix", timestamp);
    object  now = Now;
    string  curtime = target->format_mod();
    string  curday = ordered(target->month_day());
    string  curmonth = month(target->month_no());
    string  curyear = target->year_name();
    
    if(!m) m=([]);

    if(!(m["full"] || m["date"] || m["time"]))
    {
        int dist;

        if (target > now)
            dist = -now->distance(target)->how_many(Calendar.Day);
        else
            dist = target->distance(now)->how_many(Calendar.Day);
      
        if (!dist)
            return "today, " + curtime;

        if (dist == -1)
            return "yesterday, " + curtime;

        if (dist == 1)
            return "tomorrow, " + curtime; 

        if (now->year_no() != target->year_no())
            return curmonth +  " " + curyear;

        return curmonth + " " + curday;
    }
  
    if(m["full"])
        return curtime + ", " + curmonth + " the " + curday + ", " + curyear;
  
    if(m["date"])
        return curmonth + " the "  + curday + " in the year of " + curyear;
  
    if(m["time"])
        return curtime;
}


string number(int num)
{
    if(num<0)
        return "minus "+number(-num);
    switch(num)
    {
        case 0:  return "";
        case 1:  return "one";
        case 2:  return "two";
        case 3:  return "three";
        case 4:  return "four";
        case 5:  return "five";
        case 6:  return "six";
        case 7:  return "seven";
        case 8:  return "eight";
        case 9:  return "nine";
        case 10: return "ten";
        case 11: return "eleven";
        case 12: return "twelve";
        case 13: return "thirteen";
        case 14: return "fourteen";
        case 15: return "fifteen";
        case 16: return "sixteen";
        case 17: return "seventeen";
        case 18: return "eighteen";
        case 19: return "nineteen";
        case 20: return "twenty";
        case 30: return "thirty";
        case 80: return "eighty";
        case 40:
            return "forty";
        case 60: case 70: case 90:
            return number(num/10)+"ty";
        case 50: return "fifty";
        case 21..29: case 31..39: 
        case 51..59: case 61..69: case 71..79: 
        case 81..89: case 91..99: case 41..49: 
            return number((num/10)*10)+number(num%10);
        case 100: case 200: case 300: case 400: case 500:
        case 600: case 700: case 800: case 900:
            return number(num/100)+" hundred";
        case 101..199: case 201..299: case 301..399: case 401..499:
        case 501..599: case 601..699: case 701..799: case 801..899:
        case 901..999:
            return number(num/100)+" hundred and "+number(num%100);
        case 1001..1099:
            return number(num/1000)+" thousand and "+number(num%1000);
        case 1000: case 1100..999999:
            return number(num/1000)+" thousand "+number(num%1000);
        case 1000001..1000099:
            return number(num/1000000)+" million and "+number(num%1000000);
        case 1000000: case 1000100..999999999:
            return number(num/1000000)+" million "+number(num%1000000);
        default:
            perror("foo\n"+ num +"\n");
            return "many";
    }
}

string day(int num)
{
    if (num > 0 && num <= sizeof(days))
        return days[num - 1];
    else
        return "?";
}

string day_short(int num)
{
    if (num > 0 && num <= sizeof(days_short))
        return days[num - 1];
    else
        return "?";
}

string day_really_short(int num)
{
    if (num > 0 && num <= sizeof(days))
        return days[num - 1][0..0];
    else
        return "?";
}

string words(int num)
{
    if (num >= 0 && num < sizeof(the_words))
        return the_words[num];
    else
        return "?";
}

array aliases()
{
    return ({ "en", "eng", "english" });
}

void create()
{
    Now = Calendar.now();
    
    initialize_months(Now);
    initialize_days(Now);
}
