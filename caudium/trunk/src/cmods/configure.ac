# $Id: configure.ac,v 1.8 2005-05-24 07:30:52 kiwi Exp $
AC_INIT(Caudium, 1.3.3, bugs@caudium.net)

CAUDIUM_LOW_MODULE_INIT()

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS

AC_CONFIG_SUBDIRS(_Caudium UltraLog Mhash PCRE PiXSL)

AC_OUTPUT(Makefile module_makefile)	
