# $Id$
AC_INIT(Caudium, 1.3.3, bugs@caudium.net)

CAUDIUM_LOW_MODULE_INIT()

# We want an absolute path to the source-dir.
case "$srcdir" in
    /*)
    ;;
    *)
        oldsrcdir="$srcdir"
        srcdir="`cd \"$srcdir\";pwd`"
        AC_MSG_WARN([ Converted $oldsrcdir to $srcdir,
If this does not work, please use an absolute path to the configure script. ])
    ;;
esac

dirs=""
for a in `(cd $srcdir ; echo *)`
do
  if test "$a" != "CVS" -a "$a" != "RCS" -a "$a" != "autom4te.cache" -a "$a" != "autom4te253.cache" ; then
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
