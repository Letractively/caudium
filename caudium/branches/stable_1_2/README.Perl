Some notes for Perl support for the Caudium Webserver
-----------------------------------------------------

1- Blurb

 mod_perl embedded Perl support for the Caudium webserver. Written by
 Leif Stensson for the Roxen Webserver. First ported to Caudium by Jan
 Legengausen. Additional porting by David Hedbor etc.

2- Requirements

 To run perl or mod_perl-like support for the Caudium Webserver, you
 will need :

 o A working Caudium
 o A perl 5.8 or more recent.
 o Some script with perl inside.

3- How this works ?

 Perl support / mod_perl is working with a perl super server that handle 
 request on the OS Perl used. It is not really a fork, it not also an
 extensive usage of ePerl like the original mod_perl from Apache.

4- Where Can I store some of my lib / includes for Caudium Perl support ?

 The server/perl/lib/ directory will contain Perl modules, and should
 be added to @INC for Caudium-related Perl scripts.

5- Some examples :

 Inside a rxml file :

 <perl>
   printf("Hello world");
 </perl>


