# $Id$
AC_INIT(openssl.c)

AC_CONFIG_HEADER(config.h)

dnl AC_MODULE_INIT()
CAUDIUM_MODULE_INIT()

AC_ARG_WITH(openssl,  [  --with-openssl       enable the openssl-module],[],[with_openssl=yes])

if test x$with_openssl = xyes; then
  OLD_LDFLAGS=$LDFLAGS
  OLD_CPPFLAGS=$CPPFLAGS
  OLD_LIBS=$LIBS

  if test -d $with_root/usr/local/ssl/lib ; then
    echo Added $with_root/usr/local/ssl/lib to the library search path.
    LDFLAGS="-L$with_root/usr/local/ssl/lib ${LDFLAGS}"
    # link with libc first, so we get the right definition
    # of crypt()
    LDFLAGS="-lc ${LDFLAGS}"
  fi
  if test -d $with_root/usr/local/openssl/lib ; then
    echo Added $with_root/usr/local/openssl/lib to library search path.
    LDFLAGS="-L$with_root/usr/local/openssl/lib ${LDFLAGS}"
    # link with libc first, so we get the right definition
    # of crypt()
    LDFLAGS="-lc ${LDFLAGS}"
  fi

  if test -d $with_root/usr/local/ssl/include ; then
    echo Added $with_root/usr/local/ssl/include to the include search path.
    CPPFLAGS="-I$with_root/usr/local/ssl/include ${CPPFLAGS}"
  fi
  if test -d $with_root/usr/local/openssl/include ; then
    echo Added $with_root/usr/local/openssl/include to the include search path.
    CPPFLAGS="-I$with_root/usr/local/ssl/include ${CPPFLAGS}"
  fi
  if test -d $with_root/usr/include/openssl ; then
    echo Added $with_root/usr/include/openssl to the include search path.
    CPPFLAGS="-I$with_root/usr/include/openssl ${CPPFLAGS}"
  fi

  pike_cv_openssl="yes"

  AC_CHECK_LIB(crypto, ERR_print_errors_fp, [], [ pike_cv_openssl="no" ])
  AC_CHECK_LIB(ssl, SSL_use_PrivateKey_file, [], [ pike_cv_openssl="no" ])

  AC_MSG_CHECKING(Supported version of OpenSSL)

  AC_MSG_RESULT($pike_cv_openssl)

  if test x$pike_cv_openssl = xyes; then
    AC_DEFINE(HAVE_OPENSSL, 1, [Define if you have OpenSSL installed])
  else
    # Restore variables, so we don't link with unnessesary libs

    LIBS=$OLD_LIBS
    CPPFLAGS=$OLD_CPPFLAGS
    LDFLAGS=$OLD_LDFLAGS
  fi
fi

# reset it just in case
CAUDIUM_CPPFLAGS="$CAUDIUM_CPPFLAGS"
AC_SUBST(CAUDIUM_CPPFLAGS)
export CAUDIUM_CPPFLAGS
AC_OUTPUT(Makefile.pre,[${MAKE:-make} -f Makefile.pre depend] )
