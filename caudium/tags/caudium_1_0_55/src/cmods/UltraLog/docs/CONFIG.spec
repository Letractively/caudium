Specification of the config file format

# Save directory for all parsed statistics - a global variable,
<savedir path="/path/to/save/directory">

# The maximum number of entries to store in a table. Default is 10000.
# Depending on the entries it might start to get get really slow after 20-50k
# 10000 should be enough for most and should also be pretty fast.
#
# Please note that this option only affects daily tables. Table size
# for weekly, monthly and yearly views are configured in the UltraLog
# Roxen module.
#
<table maxsize="maximum entries in table">


# Profile is how you specify a log profile. ISPs or larger installations might
# want to take a look at the ispprofile syntax below this.
<profile [name="profile name"]>

# File path to log file. Multiple <file> can be specified if more than
# one logfile is to be parsed. If the "restore" argument is present in
# the file tag, a position info will be stored for this file to do
# incremental parsing. When using the special characters below to
# automatically handle rotated log files, the position will be stored
# for the "parsed" filename.
#
# *NEW*   When doing incremental parsing on a file that has been rotated
# the parsing will now start from the beginning of the file iff the new file
# is smaller than the previous file. 
# IF IT'S LARGER, PARSING WILL INCORRECTLY START AT THE SAVED LOCATION!
#
# *NEW*   Now UltraLog supports globbing in the path arguments. The
# syntax is standard glob. '*' means zero or more characters and '?'
# matches any one character (no more, no less). An example path could
# be:
#		/usr/www/server/logs/*/1999????.gz
#
# That would match all files which begins with 1999 followed by 4
# characters and .gz (for example 19991101.gz) in any subdirectory of
# /usr/www/server/logs/. 
#
# Recognised automatically decompressed file extensions are:
# gz, z -> gunzip
# Z 	-> uncompress (or gunzip)
# bz2   -> bunzip2 (please note that bzip2 generally is too slow to be used
#		    for log compression)
#
# If the file needs to be filtered through some other program (I filter one
# log file through sed to fix broken, unquoted user-agent logging for example),
# you can use the filter option. "$f" will be replaced with the filename of the
# log that is being parsed. The filter should write the output on stdout.
# NO DATA WILL BE WRITTEN TO STDIN OF THE FILTER EVEN IF $f IS LEFT OUT.
#
# If you want to you can customize the log format on a per-file basis. The
# default format is: %H %R %U [%D/%M/%Y:%h:%m:%s %j] \"%j %f %j\" %c %b
#
# Format and Filter are optional arguments.

 <file path="/path/to/logfile/log.file" restore
       format='CUSTOM FORMAT (see CUSTOM_LOG.spec)"
       filter='/path/to/filter $f'>

# Don't summarize referrers from sites matching this substring. Please not
# that this is a string without patterns and that it can be only one string.
 <noref for="myhost.com">

# A list with extensions to identify a page. Defaults are html, htm
# and cgi. Requests ending with '/' or which don't start with '/' will
# be counted as pages as well.
 <extensions list="html htm rxml shtml cgi">
</profile>


# When using UltraLog with an ISP, it can be nice to use the ISP
# hosting syntax to automatically parse logs from all user accounts
# without having to have a profile for each user. The <ispprofile> </>
# tag uses the same syntax as the normal profile with a couple of
# additions.  
#
# The name and body of the tag will get all occurences of #user#
# replaced with the current user name and #homedir# will be replaced with
# the users home directory.
#
# By default all users in the system will be included. You can control
# this with the include/exclude arguments to <ispprofile> as shown below.
#
# In the future, support for inclusion/exclusion of groups might be
# added, as well as loading lists from files.

<ispprofile name="virthost_#user#"
	    [include="john, doe, user, [...]"]
	    [exclude="root, adm, [...]"]>
  <file path="#homedir#/logs/www.log" [...]>
  [.. All other profile syntax ...]	    
</ispprofile>




