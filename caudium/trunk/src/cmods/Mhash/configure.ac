AC_INIT(mhash.c)
AC_CONFIG_HEADER(mhash_config.h)

CAUDIUM_MODULE_INIT()

AH_BOTTOM([
#if defined(HAVE_MHASH_H) && defined(HAVE_LIBMHASH)
#define HAVE_MHASH
#include <mhash.h>
#include "mhash_defs.h"
#endif

void pike_module_init(void);
void pike_module_exit(void);
])

AC_CHECK_HEADERS( mhash.h )
AC_CHECK_LIB(mhash, mhash)

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS
AC_OUTPUT(Makefile.pre, [${MAKE:-make} -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
