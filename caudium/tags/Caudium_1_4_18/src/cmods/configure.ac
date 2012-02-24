# $Id$
AC_INIT(Caudium, 1.3.3, bugs@caudium.net)

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
INSTALLDIR="$prefix/caudium/server/lib/$PIKE_VERSION"
AC_SUBST(CAUDIUM_CPPFLAGS)
AC_SUBST(INSTALLDIR)
AC_SUBST(PIKE)
export CAUDIUM_CPPFLAGS

MODULE_SUBDIRS="_Caudium"
#MODULE_SUBDIRS="_Caudium UltraLog Mhash PCRE PiXSL"

for x in $MODULE_SUBDIRS ; do
 cd $x
 $PIKE -x module --automake
 $PIKE -x module --autoheader
 $PIKE -x module --configure
 cd ..
done

AC_OUTPUT(Makefile module_makefile)	
