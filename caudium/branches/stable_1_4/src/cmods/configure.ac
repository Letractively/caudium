# $Id$
AC_INIT(Caudium, 1.3.3, bugs@caudium.net)

CAUDIUM_LOW_MODULE_INIT()

dirs=""
for a in `(cd $srcdir ; echo *)`
do
  if test "$a" != "CVS" -a "$a" != "RCS" -a "$a" != "autom4te.cache" ; then
    if test -d "$srcdir/$a" ; then
      yesno=`eval echo \\$with_$a`
      if test "${yesno-}" != "no" ; then
        dirs="$dirs $a"
      fi
    fi
  fi
done

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS

AC_CONFIG_SUBDIRS($dirs)

AC_OUTPUT(Makefile module_makefile)	
