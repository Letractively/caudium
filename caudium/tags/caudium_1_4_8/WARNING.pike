Here is some Warning about Pike and Caudium
-------------------------------------------


Caudiums needs pike and C to run. 90% of webserver is done in Pike and some
code is done in C to get fast low level function that can also be done in
pike but the result function will be slower than in C.

Caudium needs also a Pike with threads *EVEN* if you start Caudium with
the --without-thread parameter, some low level modules and core function
*WILL* use threads.

Pike is maintained by IDA (http://pike.ida.liu.se/), even if IDA does
very good work, some testing on special platforms are not 100% stable as
main operating system used at IDA.

Caudium and Pike will surely running on Linux and Solaris but on other
Unix this is not sure.

Caudium maintainer has lots of problems with Pike 7.6 and FreeBSD, mostly
because Pike team doesn't have the time or the experience on FreeBSD.
So if you use FreeBSD you can EXPECT problems with threads.

In this case you should consider using Caudium 1.2 instead that is far more
stable than Caudium 1.4/Pike 7.6.

The Caudium Group is sorry about the fact that Pike 7.6 isn't so stable
than previous version. We encourage users and administrator to fill bugs
and send patchs to IDA to fix that.

$Id$
