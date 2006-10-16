AC_REVISION("$Id")

AC_INIT(Makefile.in)

AC_CONFIG_HEADER(config.h)

BUILDDIR="`pwd`/../../"

# Strip smartlink from cached CC if it's there.
if test ! -z "$ac_cv_prog_CC"; then
 ac_cv_prog_CC="`echo $ac_cv_prog_CC|sed -e 's/.*smartlink //'`"
 export ac_cv_prog_CC
fi

if test ! -z "$caudium_cv_prog_CC" -a ! -z "$CC" -a "$CC" != "$caudium_cv_prog_CC"
then
  AC_MSG_WARN([CC is different than last time Caudium was compiled,
It is probably best to delete ./config.cache before proceeding])
fi

#
# NOTE: These tests must be before AC_PROG_CC
# since AC_PROG_CC sets CFLAGS by itself.
#

if test "x${CFLAGS-}" = "x" ; then
  cflags_is_set=no
else
  cflags_is_set=yes
fi

if test "x${CPPFLAGS-}" = "x" ; then
  cppflags_is_set=no
else
  cppflags_is_set=yes
fi

if test "x${LDFLAGS-}" = "x" ; then
  ldflags_is_set=no
else
  ldflags_is_set=yes
fi

caudium_cv_prog_CC="$CC"

AC_PROG_CC
# The AC_PROG_INSTALL test is broken if $INSTALL is specified by hand.
# The FreeBSD ports system does this...
# Workaround:

if test "x$INSTALL" = "x"; then :; else
  # $INSTALL overrides ac_cv_path_install anyway...
  ac_cv_path_install="$INSTALL"
fi

# Fix a smartlink
SMARTLINK="$BUILDDIR/smartlink"

AC_MSG_CHECKING(if $SMARTLINK exists is up to date and works)
if ls -1tr "$SMARTLINK" "$srcdir/tools/smartlink.c" 2>/dev/null | head -1 | grep "smartlink" >/dev/null 2>&5 && "$SMARTLINK" -v >/dev/null 2>&5; then
  AC_MSG_RESULT(yes)
else
  AC_MSG_RESULT(no)
  rm -f "$SMARTLINK"
  AC_MSG_CHECKING(whether smartlink compiles)

  link_cmd='${CC} -o smartlink $CFLAGS -I. $CPPFLAGS $LDFLAGS $srcdir/tools/smartlink.c $LIBS 2>&5'
   if { (eval echo Compiling smartlink: \"$link_cmd\") 1>&5; (eval $link_cmd) 2>&5; } && "$BUILDDIR/smartlink" -v >/dev/null 2>&5; then
      AC_MSG_RESULT(yes)
  else
    AC_MSG_RESULT(no - use the sh script)
    SMARTLINK="$srcdir/tools/smartlink" 
 fi
fi
CC="$SMARTLINK $CC"
ac_cv_prog_CC="$CC"

AC_PROG_INSTALL

AC_CHECK_HEADERS(unistd.h signal.h crypt.h)

AC_CHECK_LIB(crypt,crypt)
AC_CHECK_FUNCS(crypt)


AC_SUBST(LDFLAGS)
AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)

AH_TOP([
#ifndef CONFIG_H
#define CONFIG_H
])

AH_BOTTOM([
#endif
])

AC_OUTPUT(Makefile)
