AC_INIT(Makefile.in)

# Restore CFLAGS to the initial value
if test "x$REALCFLAGS" = "x" ; then
  :
else
  CFLAGS="$REALCFLAGS"
  export CFLAGS
fi
if test "x$with_oldfastcgi" = "x"; then
  with_oldfastcgi = "no"
fi

if test "x$with_oldfastcgi" = "xno"; then
  DIRS="cmods tools"
else
  DIRS="cmods tools fast_cgi"
fi

AC_SUBST(DIRS)

AC_SET_MAKE

AC_CONFIG_SUBDIRS($DIRS)

AC_OUTPUT(Makefile)
