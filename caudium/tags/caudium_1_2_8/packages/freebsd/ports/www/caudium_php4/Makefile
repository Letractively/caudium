# New ports collection makefile for:	caudium_php4
# Date created:		Tue May  7 19:46:30 CEST 2002
# Whom:			Xavier Beaudouin <kiwi@oav.net>
#
# $FreeBSD$
#

PORTNAME=	caudium_php4
PORTVERSION=	4.2.1
PORTREVISION=	0
CATEGORIES=	www
MASTER_SITES=	http://us.php.net/${PHP_DISTDIR}/ \
		http://php.he.net/${PHP_DISTDIR}/ \
		http://www.php3.de/${PHP_DISTDIR}/ \
		http://au.php.net/${PHP_DISTDIR}/ \
		http://at.php.net/${PHP_DISTDIR}/ \
		http://br.php.net/${PHP_DISTDIR}/ \
		http://php.easydns.com/${PHP_DISTDIR}/ \
		http://www.php.cz/${PHP_DISTDIR}/ \
		http://php3.globe.de/${PHP_DISTDIR}/
DISTNAME=	php-${PORTVERSION}

MAINTAINER=	kiwi@oav.net

BUILD_DEPENDS=	${LOCALBASE}/bin/caudiumctl:${PORTSDIR}/www/caudium12
RUN_DEPENDS=	${LOCALBASE}/bin/caudiumctl:${PORTSDIR}/www/caudium12

PHP_DISTDIR=	distributions

USE_SUBMAKE=	yes
USE_AUTOCONF_VER=213

CONFIGURE_ARGS=	--with-config-file-path=${PREFIX}/etc/php.caudium \
		--disable-pear \
		--enable-discard-path \
		--with-caudium=/usr/local/caudium/server \
		--enable-track-vars \
		--enable-memory-limit \
		--enable-force-cgi-redirect \
		--with-pcre \
		--enable-session \
		--enable-xml \
		--enable-discard-path \
		--enable-posix \
		--with-readline=/usr

CONFIGURE_ARGS+=--enable-versioning \
		--with-regex=system \
		--without-gd \
		--without-mysql

CFLAGS+=	-I${PREFIX}/include

SCRIPTS_ENV=	WRKDIRPREFIX="${WRKDIRPREFIX}" \
		TOUCH="${TOUCH}" \
		MKDIR="${MKDIR}" \
		CAT="${CAT}" \
		PHP4_OPTIONS="${PHP4_OPTIONS}" \
		REALCURDIR="${.CURDIR}"

INSTALL_TARGET=	install-sapi

pre-fetch:
	@${SETENV} ${SCRIPTS_ENV} ${SH} ${SCRIPTDIR}/configure.php
	@${ECHO_CMD} ""

post-install:
	@${MKDIR} ${PREFIX}/etc/php.caudium
	@${INSTALL_DATA} ${WRKSRC}/php.ini-dist ${PREFIX}/etc/php.caudium

post-clean:
	@${RM} -f ${WRKDIRPREFIX}${.CURDIR}/Makefile.inc

.if exists(${WRKDIRPREFIX}${.CURDIR}/Makefile.inc)
.include "${WRKDIRPREFIX}${.CURDIR}/Makefile.inc"
.endif

.include <bsd.port.mk>
