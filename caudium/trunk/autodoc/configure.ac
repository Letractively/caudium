#
# $Id$
#
AC_INIT(Makefile.in)

AC_SET_MAKE

AC_PROG_INSTALL
AC_PROG_LN_S

if test "$LN_S" = "ln"; then
  LN_S="cp -p"
fi

PIKE_SRC_DIR="notgiven"
PIKE_REFDOC_DIRS="refdoc/bin refdoc/presentation"
PIKE_BIN="pike"

AC_ARG_WITH(pikesrc,
  AC_HELP_STRING([--with-pikesrc], [location of the toplevel directory of the Pike 7.3+ source]),
  [PIKE_SRC_DIR="$withval"], 
  AC_MSG_ERROR([You must specify the Pike 7.3+ source directory], 1))

AC_ARG_WITH(pike,
  AC_HELP_STRING([--with-pike], [use the specified pike binary to extract the documentation]),
  [PIKE_BIN=$withval])

AC_MSG_CHECKING([Pike 7.3 sources])
if test ! -d $PIKE_SRC_DIR; then
  AC_MSG_ERROR([not found])
else
  # check whether all the required dirs exist
  for d in $PIKE_REFDOC_DIRS; do
    if test ! -d $PIKE_SRC_DIR/$d; then
      AC_MSG_ERROR([missing the $d subdir])
    fi
  done

  # check whether the sources really are for 7.3+
  PIKE_MAJOR_VERSION=0
  PIKE_MINOR_VERSION=0
  PIKE_BUILD_VERSION=0

  if test ! -f $PIKE_SRC_DIR/src/version.h; then
    AC_MSG_ERROR([no version.h - cannot check the pike version])
  fi

  PIKE_MAJOR_VERSION=`cat $PIKE_SRC_DIR/src/version.h | grep '^#define PIKE_MAJOR_VERSION' | cut -d ' ' -f 3`
  PIKE_MINOR_VERSION=`cat $PIKE_SRC_DIR/src/version.h | grep '^#define PIKE_MINOR_VERSION' | cut -d ' ' -f 3`
  PIKE_BUILD_VERSION=`cat $PIKE_SRC_DIR/src/version.h | grep '^#define PIKE_BUILD_VERSION' | cut -d ' ' -f 3`

  if test $PIKE_MAJOR_VERSION -lt 7 -a $PIKE_MINOR_VERSION -lt 3; then
    AC_MSG_ERROR([failed - need 7.3+, found $PIKE_MAJOR_VERSION.$PIKE_MINOR_VERSION.$PIKE_BUILD_VERSION])
  fi

  # now symlink all the pike progs from there to our bin/
  rm -f bin/.deleteus >& /dev/null
  for d in $PIKE_REFDOC_DIRS; do
    for f in $PIKE_SRC_DIR/$d/*; do
      if test -f $f; then
        $LN_S $f bin/`basename $f` >& /dev/null
        echo `basename $f` >> bin/.deleteus
      fi
    done
  done

  AC_MSG_RESULT([ok - $PIKE_MAJOR_VERSION.$PIKE_MINOR_VERSION.$PIKE_BUILD_VERSION])
fi

AC_MSG_CHECKING([version of the Pike binary])

PIKE_VERSION="`$PIKE_BIN -e 'string v; int rel;sscanf(version(), \"Pike v%s release %d\", v, rel); write(v+\".\"+rel);'`"
PIKE_MAJOR=`echo $PIKE_VERSION | cut -d '.' -f 1`
PIKE_MINOR=`echo $PIKE_VERSION | cut -d '.' -f 2`
PIKE_BUILD=`echo $PIKE_VERSION | cut -d '.' -f 3`

if test $PIKE_MAJOR -lt 7 -a $PIKE_MINOR -lt 2; then
  AC_MSG_ERROR([you need at least Pike 7.2])
else
  AC_MSG_RESULT([ok - $PIKE_MAJOR.$PIKE_MINOR.$PIKE_BUILD])
fi

AC_SUBST(PIKE_BIN)

AC_OUTPUT(Makefile)
