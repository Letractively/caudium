define([CAUDIUM_LOW_MODULE_INIT],
[
# $Id$

AC_PROG_CC

# The AC_PROG_INSTALL test is broken if $INSTALL is specified by hand.
# The FreeBSD ports system does this...
# Workaround:
if test "x$INSTALL" = "x"; then :; else
  # $INSTALL overrides ac_cv_path_install anyway...
  ac_cv_path_install="$INSTALL"
fi

AC_PROG_INSTALL

AC_SUBST(PIKE_INCLUDE_DIRS)
AC_SUBST(PIKE_VERSION)
AC_SUBST(CLIBRARY_LINK)
AC_SUBST(PIKE)
AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(CC)
AC_SUBST(LDFLAGS)
AC_SUBST(LDSHARED)
AC_SUBST(SO)
AC_SUBST(LIBGCC)

AC_DEFINE(POSIX_SOURCE)
])


define([CAUDIUM_MODULE_INIT],
[
  CAUDIUM_LOW_MODULE_INIT()
  AC_MSG_CHECKING([for the Caudium cmod base directory])

  module_makefile=../module_makefile

  counter=.

  while test ! -f "$module_makefile"
  do
    counter=.$counter
    if test $counter = .......... ; then
      AC_MSG_RESULT(failed)
      exit 1
    else
      :
    fi
    module_makefile=../$module_makefile
  done
  AC_MSG_RESULT(found)
  AC_SUBST_FILE(module_makefile)
])

])

