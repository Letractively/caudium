Here are some Warnings about Pike and Caudium
---------------------------------------------

Caudiums needs pike and C to run. 90% of Caudium is written in Pike and 
some code is C to get fast low level function that can also be done in
pike would be slower than in C.

Caudium also requires a Pike with thread support *EVEN* if you start 
Caudium with the --without-thread parameter, some low level modules and 
core function *WILL* use threads.

Caudium and Pike are known to run on Linux, Solaris and MacOS X (Darwin). 
Other Unix platforms should work, however they receive less testing and 
you may encounter difficulties. In this situation, please feel free to 
post on the caudium-general mailing list for assistance.
