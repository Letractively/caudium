#!/bin/sh

if [ -f ${WRKDIRPREFIX}${CURDIR}/Makefile.inc ]; then
	exit
fi

/usr/bin/dialog --title "configuration options" --clear \
	--checklist "\n\
Please select desired options:" -1 -1 11 \
FreeType	"TrueType 1 font rendering" OFF \
FreeType2	"TrueType 2 font rendering" OFF \
JPEG		"JPEG image support" OFF \
TIFF		"TIFF image support" OFF \
threads		"threads support" ON \
GDBM		"GNU database manager support" OFF \
zlib		"zlib library support" ON \
gmp		"support bignums" ON \
readline	"support for command line editing" ON \
MySQL		"MySQL database support" OFF \
PostgreSQL	"PostgreSQL database support" OFF \
mSQL		"mSQL database support" OFF \
unixODBC	"unixODBC database support" OFF \
Mird		"Mird file database support" ON \
ssl	        "SSL support" OFF \
PDF	        "PDF support through PDFlib" OFF \
sane		"SANE support" OFF \
MesaGL		"MesaGL + GLUT support" OFF \
GTK		"GTK + GNOME support" OFF \
2> /tmp/checklist.tmp.$$
retval=$?

if [ -s /tmp/checklist.tmp.$$ ]; then
	set `cat /tmp/checklist.tmp.$$`
fi
rm -f /tmp/checklist.tmp.$$

case $retval in
	0)	if [ -z "$*" ]; then
			echo "Nothing selected"
		fi
		;;
	1)	echo "Cancel pressed."
		exit 1
		;;
esac

mkdir -p ${WRKDIRPREFIX}${CURDIR}
> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc

while [ "$1" ]; do
	case $1 in
		\"FreeType\")
			echo "LIB_DEPENDS+=	ttf.4:\${PORTSDIR}/print/freetype" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-ttflib" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			FreeType=1
			;;
		\"FreeType2\")
			echo "LIB_DEPENDS+=	freetype.7:\${PORTSDIR}/print/freetype2" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-freetype" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			FreeType2=1
			;;
		\"threads\")
			threads=1
			;;
		\"gmp\")
			echo "CONFIGURE_ARGS+=	--with-gmp" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			gmp=1
			;;
		\"readline\")
			echo "CONFIGURE_ARGS+=	--with-readline" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			readline=1
			;;
		\"JPEG\")
			echo "LIB_DEPENDS+=		jpeg.9:${PORTSDIR}/graphics/jpeg" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-jpeg=\${PREFIX}" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			JPEG=1
			;;
		\"TIFF\")
			echo "LIB_DEPENDS+=		tiff.4:${PORTSDIR}/graphics/tiff" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-tiff" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			TIFF=1
			;;
		\"GDBM\")
			echo "LIB_DEPENDS+=	gdbm.2:${PORTSDIR}/databases/gdbm" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc 
			echo "CONFIGURE_ARGS+=	--with-gdbm=\${PREFIX}" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			GDBM=1
			;;
		\"zlib\")
			echo "CONFIGURE_ARGS+=	--with-zlib" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			zlib=1
			;;
		\"MySQL\")
			echo "LIB_DEPENDS+=	mysqlclient.10:\${PORTSDIR}/databases/mysql323-client" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-mysql=\${PREFIX}" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			MySQL=1
			;;
		\"PostgreSQL\")
			echo "BUILD_DEPENDS+=		\${PREFIX}/pgsql/bin/psql:\${PORTSDIR}/databases/postgresql7" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-pgsql=\${PREFIX}/pgsql" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			PostgresSQL=1
			;;
		\"mSQL\")
			echo "BUILD_DEPENDS+=		msql:\${PORTSDIR}/databases/msql" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-msql=\${PREFIX}" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			mSQL=1
			;;
		\"unixODBC\")
			echo "LIB_DEPENDS+=		odbc.1:\${PORTSDIR}/databases/unixODBC" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+=	--with-odbc" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			unixODBC=1
			;;
		\"ssl\")
			echo "CONFIGURE_ARGS+= --with-ssleay" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			ssl=1
			;;
		\"Mird\")
			echo "LIB_DEPENDS+=		mird.1:\${PORTSDIR}/databases/mird" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			mird=1
			;;
		\"PDF\")
			echo "LIB_DEPENDS+=		pdf.3:\${PORTSDIR}/print/pdflib3" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+= --with-libpdf" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			pdf=1
			;;
		\"sane\")
			echo "LIB_DEPENDS+=		sane.1:\${PORTSDIR}/graphics/sane-backends" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+= --with-sane" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			sane=1
			;;
		\"MesaGL\")
			echo "USE_MESA=yes" 	>> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+= --with-GL --with-GLUT" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			mesa=1
			;;
		\"GTK\")
			echo "WANT_GTK=yes" 	>> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "WANT_GNOME=yes" 	>> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "WANT_GLIB=yes" 	>> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			echo "CONFIGURE_ARGS+= --with-GTK --with-gnome --with-glade" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc
			gtk=1
			;;
	esac
	shift
done
if [ -z "$FreeType" ]; then
	echo "CONFIGURE_ARGS+=  --without-ttflib" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$FreeType2" ]; then
	echo "CONFIGURE_ARGS+=  --without-freetype" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$threads" ]; then
	echo "CONFIGURE_ARGS+=  --without-threads" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$GDBM" ]; then
	echo "CONFIGURE_ARGS+=  --without-gdbm" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$zlib" ]; then
	echo "CONFIGURE_ARGS+=  --without-zlib" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$MySQL" ]; then
	echo "CONFIGURE_ARGS+=  --without-mysql" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$PostgreSQL" ]; then
	echo "CONFIGURE_ARGS+=  --without-postgresql" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$mSQL" ]; then
	echo "CONFIGURE_ARGS+=  --without-msql" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$unixODBC" ]; then
	echo "CONFIGURE_ARGS+=  --without-odbc" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$gmp" ]; then
	echo "CONFIGURE_ARGS+=  --without-gmp --without-bignums" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$JPEG" ]; then
	echo "CONFIGURE_ARGS+=  --without-jpeg" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$TIFF" ]; then
	echo "CONFIGURE_ARGS+=  --without-tiff" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$readline" ]; then
	echo "CONFIGURE_ARGS+=  --without-readline" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
if [ -z "$ssl" ]; then
	echo "CONFIGURE_ARGS+=  --without-ssl" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$pdf" ]; then
	echo "CONFIGURE_ARGS+=  --without-libpdf" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$sane" ]; then
	echo "CONFIGURE_ARGS+=  --without-sane" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$mesa" ]; then
	echo "CONFIGURE_ARGS+=  --without-GL --without-GLUT" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi
if [ -z "$gtk" ]; then
	echo "CONFIGURE_ARGS+=  --without-GTK" >> ${WRKDIRPREFIX}${CURDIR}/Makefile.inc  
fi

fi
