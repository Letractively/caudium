AC_INIT(sablot.c)
AC_CONFIG_HEADER(sablot_config.h)

CAUDIUM_MODULE_INIT()

AC_PROG_INSTALL

dnl Solaris have math functions in libm
dnl so this is needed to linking libsablot
AC_CHECK_LIB(m, floor)
if test "$ac_cv_lib_m_floor" != "yes"; then 
  AC_CHECK_LIB(m, ceil)
fi

dnl FreeBSD of Sablot + Expart uses iconv lib 
dnl when linking
AC_CHECK_LIB(iconv, iconv)
dnl There is also another call in libiconv that can
dnl be used
AC_CHECK_LIB(iconv, libiconv)

dnl Check if libexpat exist (some calls)
AC_CHECK_LIB(expat, XML_Parse)
AC_CHECK_LIB(expat, XML_SetBase)
AC_CHECK_LIB(expat, XML_SetEncoding)

AC_CHECK_HEADERS( sablot.h )
dnl  if we need this, use em.
dnl No need to continue unless the header is found...
if test "$ac_cv_header_sablot_h" = "yes"; then
    unset ac_cv_lib_sablot_SablotProcess
    OLDLIBS="$LIBS"
    LIBS=""
    AC_CHECK_LIB(sablot, SablotProcess,
    [
      AC_DEFINE(HAVE_LIBSABLOT)
  	  LIBS="-lsablot $OLDLIBS"
  	], [
  	  unset ac_cv_lib_sablot_SablotProcess
  	  AC_CHECK_LIB(sablot, SablotProcess,
  	  [
  		AC_DEFINE(HAVE_LIBSABLOT)
  		LIBS="-lsablot -lexpat $OLDLIBS"
  	  ], [
  		unset ac_cv_lib_sablot_SablotProcess
  		AC_CHECK_LIB(sablot, SablotProcess,
  		[
  		  AC_DEFINE(HAVE_LIBSABLOT)
  		  LIBS="-lsablot -lxmlparse -lxmltok $OLDLIBS"
  		],[], -lxmlparse -lxmltok $OLDLIBS)
  	  ], -lexpat  $OLDLIBS)
  	], $OLDLIBS)
fi

if test "$ac_cv_header_sablot_h" != "yes" -o \
	    "$ac_cv_lib_sablot_SablotProcess" != "yes"; then
cat << EOF
*************************************************************
**** The Sablotron XSLT processing library couldn't be found.
**** PiXSL will not be built. You can get Sablotron from
**** http://www.gingerall.com/
*************************************************************
EOF
fi

AC_OUTPUT(Makefile.pre pixsl, [make -f Makefile.pre depend])


dnl ## Local Variables:
dnl ## tab-width: 4
dnl ## End:
	
