A note for PHP4 and Caudium
---------------------------

(taken and adapted from a PHP4 manual)

Caudium Server installs

PHP4 can be build as a Pike module for the Caudium webserver. Note that this is 
not supported with PHP3. Follow the simple instructions below to install PHP4 for
Caudium. 

Example Caudium Installation Instructions

 1.  Make sure you have Caudium installed prior to attempting to
     install PHP4. For PHP4 to work correctly, you will need Pike
     7.0.268 or newer. For the sake of this example we assume that
     Caudium is installed in /opt/caudium/server/.
     Make also sure that you have php4 4.1.0 or more recent, the
     4.0 branch was not releable for production usage on other
     OS than Linux.
 2.  cd ../php-x.x.x
 3.  ./configure --with-caudium=/opt/caudium/server --enable-track-vars --other-php-options
 4.  make
 5.  make install (or make install-sapi if you have allready installed php4 
     on the system for other usage).
 6.  Restart Caudium if it's currently running.
 7.  Log into the graphical configuration interface and go to the
     virtual server where you want to add PHP4 support.
 8.  Click Add Module and locate and add the PHP4 Script Support module.
 9.  If the documentation says that the 'PHP4 interpreter isn't
     available', make sure that you restarted the server. If you did
     check /opt/caudium/logs/debug/default.1 for any errors related to
     PHP4.so.  Also make sure that caudium/server/lib/[pike-version]/PHP4.so
     is present.
 10. Configure the PHP Script Support module if needed.
     

You can of course compile your Caudium module with support for the various extension
modules available in PHP4. See the complete list of configure options for an
exhaustive rundown. 

Note: When compiling PHP4 with MySQL support you must make sure that the normal
      MySQL client code is used. Otherwise there might be conflicts if your Pike
      already has MySQL support. You do this by specifying a MySQL install 
      directory the --with-mysql option


