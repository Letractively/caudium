
constant month_names = ({ "January", "February", "March",
			 "April", "May", "June",
			 "July", "August", "September",
			 "October", "November", "December" });

constant day_names = ({ "Monday", "Tuesday", "Wednesday",
			"Thursday", "Friday", "Saturday", "Sunday" });

int lastdayofmonth(int year, int month)
{
  object|int day = Calendar.ISO.Month(year, month)->days()[-1];
  if(objectp(day)) return day->month_day();
  return day;
}

array weekdays(int year, int week)
{
  object w = Calendar.ISO.Week(year, week);
#if constant(Calendar.Islamic)
  array(Calendar.ISO.Day) days = w->days();
#else
  array(Calendar.ISO.Day) days = map(w->days(), w->day);
#endif
  return Array.transpose(({ days->week_day_name(), days->month_day() }));
}

array(Calendar.ISO.Day) weekday_objs(Calendar.ISO.Week w) {
  array days = w->days();
#if !constant(Calendar.Islamic)
  days = map(days, w->day);
#endif
  return days;
}
#if constant(Calendar.Islamic)
#define monthname(X) ((X)->month_name())
#else
#define monthname(X) ((X)->name())
#endif

