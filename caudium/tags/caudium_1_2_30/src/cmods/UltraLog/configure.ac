AC_INIT(ultraparse.c)
#AC_CONFIG_HEADER(ultraparse.h)

CAUDIUM_MODULE_INIT()

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS

AC_OUTPUT(Makefile.pre ultrasum, [chmod +x ultrasum; make -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
