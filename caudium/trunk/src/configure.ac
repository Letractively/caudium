AC_INIT(Makefile.in)

# Restore CFLAGS to the initial value
if test "x$REALCFLAGS" = "x" ; then
  :
else
  CFLAGS="$REALCFLAGS"
  export CFLAGS
fi
DIRS="cmods tools fast_cgi"
AC_SUBST(DIRS)

AC_SET_MAKE

AC_CONFIG_SUBDIRS($DIRS)

AC_OUTPUT(Makefile)
