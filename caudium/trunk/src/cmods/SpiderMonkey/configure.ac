AC_INIT(Caudium, 1.3, bugs@caudium.net)
AC_CONFIG_HEADER(sm_config.h)

CAUDIUM_MODULE_INIT()

AC_ARG_WITH(smlib,
    AC_HELP_STRING([--with-smlib],[Compile with the specified SpiderMonkey library name (without the 'lib' prefix, defaults to 'js')]),
    caudium_cv_smlib=$withval,
    caudium_cv_smlib=js)

AC_CHECK_PROGS(perl, perl perl5, x)

if test x$perl != xx ; then
    PERL_LDFLAGS=`$perl -MExtUtils::Embed -e ldopts`
else
    PERL_LDFLAGS=""
fi

AC_CHECK_LIB(m, cos)
AC_CHECK_LIB(crypt, crypt)
AC_CHECK_LIB(dl, dlopen)

dnl this is required if SpiderMonkey is compiled in the thread safe mode
AC_CHECK_LIB(nspr4, PR_Malloc)

dnl SpiderMonkey _may_ be compiled with Perl support
AC_CHECK_LIB(perl, PL_gid)

OLD_LIBS="$LIBS"
LIBS="$PERL_LDFLAGS $LIBS"
SM_LIBS=""
AC_CHECK_LIB($caudium_cv_smlib, JS_NewContext,
    AC_DEFINE(HAVE_LIB_SMJS, 1, [Define if you have the SpiderMonkey library installed])
    SM_LIBS="$SM_LIBS -l$caudium_cv_smlib $PERL_LDFLAGS"
)
LIBS="$OLD_LIBS"

dnl try to find the jsapi.h file
SM_CFLAGS="-DXP_UNIX"
AC_MSG_CHECKING([the SpiderMonkey CFLAGS])
for d in $prefix/include/$caudium_cv_smlib $prefix/include ; do
    if test -f $d/jsapi.h ; then
        SM_CFLAGS="$SM_CFLAGS -I$d"
        break
    fi
done
AC_MSG_RESULT([$SM_CFLAGS])
AC_SUBST(SM_CFLAGS)
AC_SUBST(SM_LIBS)

AC_CONFIG_FILES(Makefile.pre, [make -f Makefile.pre depend])
AC_OUTPUT

dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
