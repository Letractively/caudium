Caudium and PHP
---------------

1. Introduction

   There are two ways to run PHP with Caudium. Each way has its
   advantages and drawbacks.
   PHP can be run:
     * As a CGI; using Caudium Uniscript module.
     * As a FastCGI; using Caudium FastUniscript module.
       
   Both methods are similar, simply compile your PHP with support for
   FastCGI to use the second option and replace FastUniscript in the
   instructions.

2. PHP using Uniscript
 
  2.1. Introduction to Uniscript Mode
  
   Uniscript mode is in fact using PHP in CGI mode. Caudium has a module
   named Universal Script Parser that allows you to wrap any special
   extensions inside a webserver to a CGI. Eg .php to /usr/local/bin/php.
   This is the way PHP will be run.
   
  2.2. Drawbacks

     * A php interpreter is forked on each page called. This can be
       ressource consuming.
     * Some PHP options and some security options maybe considered. See
       the PHP manual about PHP install as a CGI manual.
       
  2.3. Benefits

     * Since it is in a CGI, when PHP crashes Caudium doesn't :).
     * You can run PHP as an other user than Caudium.
     * You can give some limitation to the size of processes and
       resources usage.
     * You can have several PHP interpreters with different php.ini files
       and compilations.
       
  2.4. Software requirements

   Before considering installing PHP4 support as a CGI for Caudium, you
   will need the following:
     * An OS supported by PHP4 and Caudium.
     * Caudium installed (you don't need Pike development headers).
     * PHP4 sources (we recommend PHP 4.3.2RC2)
     * An ANSI C compiler and all libraries needed for compiling PHP.

   We consider that you have successfully installed Pike and Caudium on
   your machine.
   2.5. Compilation and installation of PHP
   NOTE: in this example, we assume that we will install all PHP in
   /usr/local/php-4.3.2RC-cgi/.
   Extract PHP4 source somewhere and do the following :
    $ cd php-4.3.2RC2
    $ ./configure --prefix=/usr/local/php-4.3.2RC-cgi/ --enable-force-cgi-redirect
 \
               --enable-discard-path --enable-fastcgi --without-pear --enable-s
afe-mode \
               --enable-sigchild --enable-magic-quotes --disable-rpath \
               --with-other-php-options
 $ make
   
   
   Now the PHP interpreter is fully compiled and can be installed.
    $ make install
   
   
  2.6. Configuring Caudium

   Log into the graphical configuration interface and go to the virtual  
   server where you want to add PHP support.
   Click on "Add Module", locate and add PATH_INFO support module and
   Universal Script parser module.
   Then configure the Universal Script Parser module with the following
   options :
     * interpreter path : /usr/local/php-4.3.2RC-cgi/bin/php or the place
       where where you have installed php.
     * script extensions : php or comma separated extensions you'd like
       to handle with that php cgi.
     * Also you can configure the Run script as : option if you want that
       php runs with a different user as default nobody.
       
   Then create a test page with :
    <? phpinfo(); ?>
       
   
   Then you will get the PHP Info page.

  2.7. Hints
   To use sessions in CGI mode you will need to save them on disk instead
   of memory. To do that, you will need to change/add option in you
   /usr/local/php-4.3.2RC-cgi/lib/php.ini:

[Session]
; Handler used to store/retrieve data.
session.save_handler = files
   
; Argument passed to save_handler.  In the case of files, this is the path
; where data files are stored. Note: Windows users have to change this
; variable in order to use PHP's session functions.
; As of PHP 4.0.1, you can define the path as:
;     session.save_path = "N;/path"
; where N is an integer.  Instead of storing all the session files in
; /path, what this will do is use subdirectories N-levels deep, and
; store the session data in those directories.  This is useful if you
; or your OS have problems with lots of files in one directory, and is
; a more efficient layout for servers that handle lots of sessions.
; NOTE 1: PHP will not create this directory structure automatically.
;         You can use the script in the ext/session dir for that purpose.
; NOTE 2: See the section on garbage collection below if you choose to
;         use subdirectories for session storage
session.save_path = /var/sessions
 
; Whether to use cookies.
session.use_cookies = 1
   
; This option enables administrators to make their users invulnerable to 
; attacks which involve passing session ids in URLs; defaults to 0.
; session.use_only_cookies = 1
   
; Name of the session (used as cookie name).
session.name = PHPSESSID
     
; Initialize session on request startup.
session.auto_start = 0
       
; Lifetime in seconds of cookie or, if 0, until browser is restarted.
session.cookie_lifetime = 0
       
; The path for which the cookie is valid.
session.cookie_path = /
       
; The domain for which the cookie is valid.
session.cookie_domain =
   
; Handler used to serialize data.  php is the standard serializer of PHP.
session.serialize_handler = php
   
; Define the probability that the 'garbage collection' process is started
; on every session initialization.
; The probability is calculated by using gc_probability/gc_divisor,
; e.g. 1/100 means there is a 1% chance that the GC process starts
; on each request.

session.gc_probability = 1
session.gc_divisor     = 100

; After this number of seconds, stored data will be seen as 'garbage' and
; cleaned up by the garbage collection process.
session.gc_maxlifetime = 1440

; NOTE: If you are using the subdirectory option for storing session files
;       (see session.save_path above), then garbage collection does *not*
;       happen automatically.  You will need to do your own garbage
;       collection through a shell script, cron entry, or some other method.
;       For example, the following script would is the equivalent of
;       setting session.gc_maxlifetime to 1440 (1440 seconds = 24 minutes):
;          cd /path/to/sessions; find -cmin +24 | xargs rm
; PHP 4.2 and less have an undocumented feature/bug that allows you to
; to initialize a session variable in the global scope, albeit register_globals
; is disabled.  PHP 4.3 and later will warn you, if this feature is used.
; You can disable the feature and the warning seperately. At this time,  
; the warning is only displayed, if bug_compat_42 is enabled.

session.bug_compat_42 = 1
session.bug_compat_warn = 1

; Check HTTP Referer to invalidate externally stored URLs containing ids.
; HTTP_REFERER has to contain this substring for the session to be
; considered as valid.
session.referer_check =

; How many bytes to read from the file.
session.entropy_length = 12

; Specified here to create the session id.
session.entropy_file = /dev/urandom

;session.entropy_length = 16
   
;session.entropy_file = /dev/urandom
; Set to {nocache,private,public,} to determine HTTP caching aspects
; or leave this empty to avoid sending anti-caching headers.
session.cache_limiter = nocache

; Document expires after n minutes.
session.cache_expire = 180

; trans sid support is disabled by default.
; Use of trans sid may risk your users security.
; Use this option with caution.
; - User may send URL contains active session ID
;   to other person via. email/irc/etc.
; - URL that contains active session ID may be stored
;   in publically accessible computer.
; - User may access your site with the same session ID
;   always using URL stored in browser's history or bookmarks.
session.use_trans_sid = 0

   Please check you PHP manual for more information about this
   parameters.

 3. Conclusion

   At the time of writing this document, the most stable way to use PHP
   is the CGI one.
   Is it up to you to decide between stability and speed. But the
   difference between them is not so big only stability may be an issue.

4. About the author

   Xavier Beaudouin is the current maintainer of Caudium. He currently
   run some big websites (more than 60.000 pages) with PHP and uniscript,
   with a single PII650 and FreeBSD.
