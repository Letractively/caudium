AC_INIT(pcre.c)
AC_CONFIG_HEADER(pcre_config.h)

CAUDIUM_MODULE_INIT([PCRE])

AH_BOTTOM([
#include <pcre.h>
#define THIS ((PCRE_Regexp *)Pike_fp->current_storage)

typedef struct
{
  pcre *regexp;
  pcre_extra *extra;
  struct pike_string *pattern;
} PCRE_Regexp;

void f_pcre_create(INT32);
void f_pcre_match(INT32);
void f_pcre_split(INT32);
void pike_module_init(void);
void pike_module_exit(void);
static void free_regexp(struct object *);
])

AC_CHECK_HEADERS(  locale.h)
AC_CHECK_FUNCS( setlocale )
dnl AC_CONFIG_SUBDIRS(pcrelib)

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS

AC_OUTPUT(Makefile.pre, [make -f Makefile.pre depend])

dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
