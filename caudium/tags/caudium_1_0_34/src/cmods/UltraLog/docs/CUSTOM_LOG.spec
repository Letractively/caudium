UltraLog allows you to customize the log format to be able to parse
all different kinds of logs. Please note that for the statistics to be
usable you need the year/month/date fields, and preferable also the
time fields (if the time fields aren't present, hourly based stats
will be incorrect). You also need the requested file field.

%H 	Host/IP
%R	Referrer
%U	User Agent
%D	Day of month
%M	Month, as two digit number (01) or three letter english abbr. (Jan etc)
%Y	Year, 4 digits (if you use 2 - get Y2K-safe right now!)
%h	Hour
%m	Minute
%s	Second
%z	Time zone, [-/+]HHMM, for example -0700
%e	Method (GET, POST etc)
%f	Requested file
%u	Auth User (or maybe a unique user cookie)
%P	Protocol (HTTP/1.0 etc)
%c	Return code
%b	Bytes transferred (sent data)
%j	Junk Field (speeds up parsing when there are fields you don't need)
\o	Make all following fields / characters optional.

The following standard characters are also allowed as separator

"	Quote
[ ]	Brackets
/	Slash
:	Colon
-	Hyphen
+	Plus
?	Question mark
space   white space (tab or space)

ALL OTHER CHARACTERS ARE INVALID AND WILL CAUSE LOG FORMAT PARSING TO FAIL!



Currently these fields aren't used in statisticsi summaries:

Time Zone (what to do with it anyway?)
Method
Protocol
Auth User / Unique Cookie

Specifying the above fields as %j might make log parsing somewhat
faster. 