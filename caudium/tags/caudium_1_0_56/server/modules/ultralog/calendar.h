
constant month_names = ({ "January", "February", "March",
			 "April", "May", "June",
			 "July", "August", "September",
			 "October", "November", "December" });

constant smonth_names = ({ "Jan", "Feb", "Mar", "Apr",
			  "May", "Jun", "Jul", "Aug",
			  "Sep", "Oct", "Nov", "Dec" });

constant day_names = ({ "Monday", "Tuesday", "Wednesday",
			"Thursday", "Friday", "Saturday", "Sunday" });

constant sday_names = ({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" });

int lastdayofmonth(int year, int month)
{
  object m = Calendar.ISO.Month(year, month);
  return m->days()[-1];
}

array weekdays(int year, int week)
{
  object w;
  array days = Array.map((w=Calendar.ISO.Week(year, week))->days(), w->day);
  return Array.transpose(({ days->week_day_name(), days->month_day() }));
}
