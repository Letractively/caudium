# New ports collection makefile for:	pike
# Date created:		05 Sep 2001
# Whom:			kiwi@oav.net
#
# $FreeBSD$
#

PORTNAME=	pike72cvs
PORTVERSION=	7.2.316
PORTREVISION=	1
CATEGORIES=	lang
MASTER_SITES=	ftp://ftp.oav.net/pkg_freebsd/distfiles/ \
		http://ftp.oav.net/pkg_freebsd/distfiles/ \
		ftp://ftp.oav.net/pike/7.2/unofficial/ \
		http://ftp.oav.net/pike/7.2/unofficial/ \
		http://grendel.firewall.com/caudium-pkg/ \
		ftp://ftp.caudium.net/caudium/snapshots/pike/7.2/unofficial/ \
		http://ftp.caudium.net/caudium/snapshots/pike/7.2/unofficial/
DISTNAME=	pike-${PORTVERSION}

MAINTAINER=	kiwi@oav.net

BUILD_DEPENDS=	bison:${PORTSDIR}/devel/bison/
.if (${MACHINE} == "i386")
BUILD_DEPENDS+=	nasm:${PORTSDIR}/devel/nasm/
.endif

LIB_DEPENDS=	gmp.4:${PORTSDIR}/math/libgmp3 \
		jpeg.9:${PORTSDIR}/graphics/jpeg \
		tiff.4:${PORTSDIR}/graphics/tiff \
		gdbm.2:${PORTSDIR}/databases/gdbm \
		mird.1:${PORTSDIR}/databases/mird \
		pdf.4:${PORTSDIR}/print/pdflib

WRKSRC=		${WRKDIR}/${DISTNAME}/src/

GNU_CONFIGURE=  yes

CONFIGURE_ARGS+= --without-debug \
		 --with-double-precision \
		 --with-long-double-precision \
		 --disable-rpath \
		 --without-rtldebug \
		 --without-cdebug \
		 --without-copt \
		 --without-shared-nodes \
		 --without-security \
		 --with-oob \
		 --with-poll \
		 --with-max-fd=60000 \
		 --without-relocatable-dumped-modules \
		 --without-libpanda \
		 --without-perl \
		 --with-gmp \
		 --with-zlib \
		 --with-threads \
		 --with-readline \
		 --with-jpeg=${PREFIX} \
		 --with-tiff \
		 --with-gdbm=${PREFIX} \
		 --with-ssleay \
		 --with-libpdf

.include <bsd.port.pre.mk>

.if exists(${LOCALBASE}/lib/libttf.so.4)
WITH_TTF=	yes
.endif

.if exists(${LOCALBASE}/lib/libfreetype.so.9)
WITH_FREETYPE=	yes
.endif

.if exists(${LOCALBASE}/lib/libmysqlclient.so.10)
WITH_MYSQL=	yes
.endif

.if exists(${LOCALBASE}/lib/libpq.so.2)
WITH_POSTGRES=	yes
.endif

.if exists(${LOCALBASE}/lib/libodbc.so.1)
WITH_UNIXODBC=	yes
.endif

.if exists(${LOCALBASE}/lib/libsane.so.1)
WITH_SANE=	yes
.endif

.if defined(WITH_TTF)
LIB_DEPENDS+=	ttf.4:${PORTSDIR}/print/freetype
CONFIGURE_ARGS+= --with-ttflib
.else
CONFIGURE_ARGS+= --without-ttflib
.endif

.if defined(WITH_FREETYPE)
LIB_DEPENDS+=	freetype.9:${PORTSDIR}/print/freetype2
CONFIGURE_ARGS+= --with-freetype
.else
CONFIGURE_ARGS+= --without-freetype
.endif

.if defined(WITH_MYSQL)
LIB_DEPENDS+=	mysqlclient.10:${PORTSDIR}/databases/mysql323-client
CONFIGURE_ARGS+= --with-mysql=${PREFIX}
.else
CONFIGURE_ARGS+= --without-mysql
.endif

.if defined(WITH_POSTGRES)
LIB_DEPENDS+=	pq.2:${PORTSDIR}/databases/postgresql7
CONFIGURE_ARGS+= --with-pgsql=${PREFIX}
.else
CONFIGURE_ARGS+= --without-pgsql
.endif

.if defined(WITH_MSQL)
BUILD_DEPENDS+=	msql:${PORTSDIR}/databases/msql
CONFIGURE_ARGS+= --with-msql=${PREFIX}
.else
CONFIGURE_ARGS+= --without-msql
.endif

.if defined(WITH_UNIXODBC)
LIB_DEPENDS+=	odbc.1:${PORTSDIR}/databases/unixODBC
CONFIGURE_ARGS+= --with-odbc
.endif

.if defined(WITH_IODBC)
LIB_DEPENDS+=	iodbc.3:${PORTSDIR}/databases/libiodbc
CONFIGURE_ARGS+= --with-odbc
.endif

.if !defined(WITH_UNIXODBC) && !defined(WITH_IODBC)
CONFIGURE_ARGS+= --without-odbc
.endif

.id defined(WITH_SANE)
LIB_DEPENDS+=	sane.1:${PORTSDIR}/graphics/sane-backends
CONFIGURE_ARGS+= --with-sane
.else
CONFIGURE_ARGS+= --without-sane
.endif

.if (${MACHINE} == "i386")
CONFIGURE_ARGS+= --with-poll
.else
# Alpha seems to have problems with poll() with pike... :/
CONFIGURE_ARGS+= --without-poll
.endif

USE_GMAKE=	yes

#pre-fetch:
#.if !defined(BATCH)
#	@${SETENV} ${SCRIPTS_ENV} ${SH} ${SCRIPTDIR}/configure.pike
#.endif

pre-configure:
	@${ECHO} ${CONFIGURE_ARGS}

pre-clean:
	@${RM} -f ${WRKDIRPREFIX}${.CURDIR}/Makefile.inc

post-install:
	${INSTALL_PROGRAM} ${WRKSRC}pike ${PREFIX}/bin
	${INSTALL_SCRIPT} ${WRKSRC}hilfe ${PREFIX}/bin

.include <bsd.port.post.mk>
