# New ports collection makefile for:	caudium_php4
# Date created:		Tue May  7 19:46:30 CEST 2002
# Whom:			Xavier Beaudouin <kiwi@oav.net>
#
# $FreeBSD$
#

PORTNAME=	caudium_php4
PORTVERSION=	4.2.0
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

CONFIGURE_ARGS=	--with-config-file-path=${PREFIX}/etc/php.standalone \
		--disable-pear \
		--enable-discard-path \
		--with-tsrm-pth \
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

AP_LIBEXEC=	${PREFIX}/libexec/apache

PLIST_SUB=	AP_LIBEXEC=${AP_LIBEXEC:S/^${PREFIX}\///}

pre-fetch:
	@${SETENV} ${SCRIPTS_ENV} ${SH} ${SCRIPTDIR}/configure.php
	@${ECHO_CMD} ""
.endif

post-install:
.if !defined(STANDALONE)
	@${INSTALL_DATA} ${WRKSRC}/php.ini-dist ${PREFIX}/etc
.else
	@${MKDIR} ${PREFIX}/etc/php.standalone
	@${INSTALL_DATA} ${WRKSRC}/php.ini-dist ${PREFIX}/etc/php.standalone
.endif

.if !defined(STANDALONE)
	@${ECHO_CMD} "*****************************************************************************"
	@${ECHO_CMD} "Make sure the mime.types are connected to the php module properly and"
	@${ECHO_CMD} "index.php is part of your DirectoryIndex."
	@${ECHO_CMD} ""
	@${ECHO_CMD} "The following should be in your Apache configuration file:"
	@${ECHO_CMD} "[...]"
	@${ECHO_CMD} "DirectoryIndex index.php index.html"
	@${ECHO_CMD} "[...]"
	@${ECHO_CMD} "AddType application/x-httpd-php .php"
	@${ECHO_CMD} "AddType application/x-httpd-php-source .phps"
	@${ECHO_CMD} "[...]"
	@${ECHO_CMD} "*****************************************************************************"
.endif

post-clean:
	@${RM} -f ${WRKDIRPREFIX}${.CURDIR}/Makefile.inc

.if exists(${WRKDIRPREFIX}${.CURDIR}/Makefile.inc)
.include "${WRKDIRPREFIX}${.CURDIR}/Makefile.inc"
.endif

.include <bsd.port.mk>
