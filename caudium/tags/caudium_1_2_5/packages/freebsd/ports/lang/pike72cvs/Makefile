# New ports collection makefile for:	pike
# Date created:		05 Sep 2001
# Whom:			kiwi@oav.net
#
# $FreeBSD$
#

PORTNAME=	pike72cvs
PORTVERSION=	7.2.296
CATEGORIES=	lang
MASTER_SITES=	ftp://ftp.oav.net/pkg_freebsd/distfiles/ \
		http://ftp.oav.net/pkg_freebsd/distfiles/ \
		http://grendel.firewall.com/caudium-pkg/
DISTNAME=	pike-${PORTVERSION}

MAINTAINER=	kiwi@oav.net

BUILD_DEPENDS=	bison:${PORTSDIR}/devel/bison/
.if (${MACHINE} == "i386")
BUILD_DEPENDS+=	nasm:${PORTSDIR}/devel/nasm/
.endif

WRKSRC=		${WRKDIR}/${DISTNAME}/src/

IS_INTERACTIVE=	yes
GNU_CONFIGURE=  yes
.if exists(${WRKDIRPREFIX}${.CURDIR}/Makefile.inc)
.include "${WRKDIRPREFIX}${.CURDIR}/Makefile.inc"
.else
CONFIGURE_ARGS?= \
	--without-ttflib \
	--without-gdbm \
	--without-mysql \
	--without-postgresql \
	--without-msql \
	--without-odbc \
	--without-libpdf \
	--without-sane \
	--without-freetype \
	--without-tifflib \
	--without-GL \
	--without-GLUT \
	--without-GTK \
	--without-glade \
	--without-gnome \
	--without-jpeg
.endif

CONFIGURE_ARGS+= --without-debug \
		 --with-oob \
		 --with-max-fds=10000 \
		 --without-libpanda \
		 --without-perl

.if (${MACHINE} == "i386")
CONFIGURE_ARGS+= --with-poll
.else
# Alpha seems to have problems with poll() with pike... :/
CONFIGURE_ARGS+= --without-poll
.endif

USE_GMAKE=	yes

pre-fetch:
.if !defined(BATCH)
	@${SETENV} ${SCRIPTS_ENV} ${SH} ${SCRIPTDIR}/configure.pike
.endif

pre-configure:
	@${ECHO} ${CONFIGURE_ARGS}

pre-clean:
	@${RM} -f ${WRKDIRPREFIX}${.CURDIR}/Makefile.inc

post-install:
	${INSTALL_PROGRAM} ${WRKSRC}pike ${PREFIX}/bin
	${INSTALL_SCRIPT} ${WRKSRC}hilfe ${PREFIX}/bin

.include <bsd.port.mk>
