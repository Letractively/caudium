AC_REVISION("$Id")

AC_INIT(Makefile.in)

AC_CONFIG_HEADER(config.h)

AC_PROG_CC
# The AC_PROG_INSTALL test is broken if $INSTALL is specified by hand.
# The FreeBSD ports system does this...
# Workaround:

if test "x$INSTALL" = "x"; then :; else
  # $INSTALL overrides ac_cv_path_install anyway...
  ac_cv_path_install="$INSTALL"
fi

AC_PROG_INSTALL

AC_CHECK_HEADERS(unistd.h signal.h crypt.h)

AC_CHECK_LIB(crypt,crypt)
AC_CHECK_FUNCS(crypt)
AC_SUBST(LDFLAGS)
AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_OUTPUT(Makefile)
