AC_INIT(caudium.c)
AC_CONFIG_HEADER(caudium_machine.h)

CAUDIUM_MODULE_INIT()

AC_HAVE_HEADERS(sys/mman.h linux/mman.h sys/file.h)
AC_HAVE_FUNCS(mmap munmap)

AC_OUTPUT(Makefile.pre, [make -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
