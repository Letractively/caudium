define([CAUDIUM_LOW_MODULE_INIT],
[
# $Id$

AC_PROG_CC

# The AC_PROG_INSTALL test is broken if $INSTALL is specified by hand.
# The FreeBSD ports system does this...
# Workaround:
if test "x$INSTALL" = "x"; then :; else
  # $INSTALL overrides ac_cv_path_install anyway...
  ac_cv_path_install="$INSTALL"
fi

AC_PROG_INSTALL

AC_SUBST(PIKE_INCLUDE_DIRS)
AC_SUBST(PIKE_VERSION)
AC_SUBST(CLIBRARY_LINK)
AC_SUBST(PIKE)
AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(CC)
AC_SUBST(LDFLAGS)
AC_SUBST(LDSHARED)
AC_SUBST(SO)
AC_SUBST(LIBGCC)

AC_DEFINE(POSIX_SOURCE)
])


define([CAUDIUM_MODULE_INIT],
[
  CAUDIUM_LOW_MODULE_INIT()
  AC_MSG_CHECKING([for the Caudium cmod base directory])

  module_makefile=../module_makefile

  counter=.

  while test ! -f "$module_makefile"
  do
    counter=.$counter
    if test $counter = .......... ; then
      AC_MSG_RESULT(failed)
      exit 1
    else
      :
    fi
    module_makefile=../$module_makefile
  done
  AC_MSG_RESULT(found)
  AC_SUBST_FILE(module_makefile)
])

])


dnl AM_PATH_NJS([MINIMUM-VERSION, [ACTION-IF-FOUND [, ACTION-IF-NOT-FOUND]]])
dnl Test for NJS Javascript interpreter, and define NJS_CFLAGS and NJS_LIBS
dnl
AC_DEFUN(AM_PATH_NJS,
[dnl 
dnl Get the cflags and libraries from the sdl-config script
dnl
AC_ARG_WITH(njs-prefix,[  --with-njs-prefix=PFX   Prefix where NJS is installed (optional)],
            njs_prefix="$withval", njs_prefix="")
AC_ARG_WITH(njs-exec-prefix,[  --with-njs-exec-prefix=PFX Exec prefix where NJS is installed (optional)],
            njs_exec_prefix="$withval", njs_exec_prefix="")
AC_ARG_ENABLE(njstest, [  --disable-njstest       Do not try to compile and run a test NJS program],
		    , enable_njstest=yes)

  if test x$njs_exec_prefix != x ; then
     njs_args="$njs_args --exec-prefix=$njs_exec_prefix"
     if test x${NJS_CONFIG+set} != xset ; then
        NJS_CONFIG=$njs_exec_prefix/bin/njs-config
     fi
  fi
  if test x$njs_prefix != x ; then
     njs_args="$njs_args --prefix=$njs_prefix"
     if test x${NJS_CONFIG+set} != xset ; then
        NJS_CONFIG=$njs_prefix/bin/njs-config
     fi
  fi

  AC_PATH_PROG(NJS_CONFIG, njs-config, no)
  min_njs_version=ifelse([$1], ,0.3.0,$1)
  AC_MSG_CHECKING(for NJS - version >= $min_njs_version)
  no_njs=""
  if test "$NJS_CONFIG" = "no" ; then
    no_njs=yes
  else
    NJS_CFLAGS=`$NJS_CONFIG $njsconf_args --cflags`
    NJS_LIBS="-R`$NJS_CONFIG $njs_args --prefix`/lib/ `$NJS_CONFIG $njsconf_args --libs`"
    njs_major_version=`$NJS_CONFIG $njs_args --version | \
           sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\1/'`
    njs_minor_version=`$NJS_CONFIG $njs_args --version | \
           sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\2/'`
    njs_micro_version=`$NJS_CONFIG $njs_args --version | \
           sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\3/'`
    if test "x$enable_njstest" = "xyes" ; then
      ac_save_CFLAGS="$CFLAGS"
      ac_save_LIBS="$LIBS"
      CFLAGS="$CFLAGS $NJS_CFLAGS"
      LIBS="$LIBS $NJS_LIBS"
dnl
dnl Now check if the installed NJS is sufficiently new. (Also sanity
dnl checks the results of njs-config to some extent
dnl
      rm -f conf.njstest
      AC_TRY_RUN([
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "njs/njs.h"

char*
my_strdup (char *str)
{
  char *new_str;
  
  if (str)
    {
      new_str = (char *)malloc ((strlen (str) + 1) * sizeof(char));
      strcpy (new_str, str);
    }
  else
    new_str = NULL;
  
  return new_str;
}

int main (int argc, char *argv[])
{
  int major, minor, micro;
  char *tmp_version;

  /* This hangs on some systems (?)
  system ("touch conf.njstest");
  */
  { FILE *fp = fopen("conf.njstest", "a"); if ( fp ) fclose(fp); }

  /* HP/UX 9 (%@#!) writes to sscanf strings */
  tmp_version = my_strdup("$min_njs_version");
  if (sscanf(tmp_version, "%d.%d.%d", &major, &minor, &micro) != 3) {
     printf("%s, bad version string\n", "$min_njs_version");
     exit(1);
   }

   if (($njs_major_version > major) ||
      (($njs_major_version == major) && ($njs_minor_version > minor)) ||
      (($njs_major_version == major) && ($njs_minor_version == minor) && ($njs_micro_version >= micro)))
    {
      return 0;
    }
  else
    {
      printf("\n*** 'njs-config --version' returned %d.%d.%d, but the minimum version\n", $njs_major_version, $njs_minor_version, $njs_micro_version);
      printf("*** of NJS required is %d.%d.%d. If njs-config is correct, then it is\n", major, minor, micro);
      printf("*** best to upgrade to the required version.\n");
      printf("*** If njs-config was wrong, set the environment variable NJS_CONFIG\n");
      printf("*** to point to the correct copy of njs-config, and remove the file\n");
      printf("*** config.cache before re-running configure\n");
      return 1;
    }
}

],, no_njs=yes,[echo $ac_n "cross compiling; assumed OK... $ac_c"])
       CFLAGS="$ac_save_CFLAGS"
       LIBS="$ac_save_LIBS"
     fi
  fi
  if test "x$no_njs" = x ; then
     AC_MSG_RESULT(yes)
     ifelse([$2], , :, [$2])     
  else
     AC_MSG_RESULT(no)
     if test "$NJS_CONFIG" = "no" ; then
       echo "*** The njs-config script installed by NJS could not be found"
       echo "*** If NJS was installed in PREFIX, make sure PREFIX/bin is in"
       echo "*** your path, or set the NJS_CONFIG environment variable to the"
       echo "*** full path to njs-config."
     else
       if test -f conf.njstest ; then
        :
       else
          echo "*** Could not run NJS test program, checking why..."
          CFLAGS="$CFLAGS $NJS_CFLAGS"
          LIBS="$LIBS $NJS_LIBS"
          AC_TRY_LINK([
#include <stdio.h>
#include "njs/njs.h"
],      [ return 0; ],
        [ echo "*** The test program compiled, but did not run. This usually means"
          echo "*** that the run-time linker is not finding NJS or finding the wrong"
          echo "*** version of NJS. If it is not finding NJS, you'll need to set your"
          echo "*** LD_LIBRARY_PATH environment variable, or edit /etc/ld.so.conf to point"
          echo "*** to the installed location  Also, make sure you have run ldconfig if that"
          echo "*** is required on your system"
	  echo "***"
          echo "*** If you have an old version installed, it is best to remove it, although"
          echo "*** you may also be able to get things to work by modifying LD_LIBRARY_PATH"],
        [ echo "*** The test program failed to compile or link. See the file config.log for the"
          echo "*** exact error that occured. This usually means NJS was incorrectly installed"
          echo "*** or that you have moved NJS since it was installed. In the latter case, you"
          echo "*** may want to edit the njs-config script: $NJS_CONFIG" ])
          CFLAGS="$ac_save_CFLAGS"
          LIBS="$ac_save_LIBS"
       fi
     fi
     NJS_CFLAGS=""
     NJS_LIBS=""
     ifelse([$3], , :, [$3])
  fi
  AC_SUBST(NJS_CFLAGS)
  AC_SUBST(NJS_LIBS)
  rm -f conf.njstest
])
