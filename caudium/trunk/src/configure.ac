AC_INIT(Makefile.in)

# Restore CFLAGS to the initial value
if test "x$REALCFLAGS" = "x" ; then
  :
else
  CFLAGS="$REALCFLAGS"
  export CFLAGS
fi
if test x$with_oldfastcgi = xyes; then
  DIRS="cmods tools fast_cgi"
else
  DIRS="cmods tools"
fi

AC_SUBST(DIRS)

AC_SET_MAKE

AC_CONFIG_SUBDIRS($DIRS)

AC_OUTPUT(Makefile)
