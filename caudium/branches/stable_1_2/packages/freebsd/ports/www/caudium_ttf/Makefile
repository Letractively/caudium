# New ports collection makefile for:	Caudium TrueType fonts
# Date created:		01 Jul 2002
# Whom:			Xavier Beaudouin <kiwi@caudium.net>
#
# $FreeBSD$
#

PORTNAME=	caudium_ttf
PORTVERSION=	1.0
CATEGORIES=	www
MASTER_SITES=	ftp://ftp.oav.net/caudium/ttf/       \
		ftp://ftp.oav.net/pkg_freebsd/distfiles/ \
		http://grendel.firewall.com/caudium-pkg/
DISTNAME=	ttffonts

MAINTAINER=	kiwi@caudium.net

NO_BUILD=	yes
NO_WRKSUBDIR=	yes

.include <bsd.port.pre.mk>

do-install:
	@${FIND} ${WRKSRC} -name '*.[tT][tT][fF]' | ${XARGS} -n1 ${SH} \
	-c '${INSTALL_DATA} $$0 ${PREFIX}/caudium/server/fonts/ttf; \
	${CHOWN} www:www ${PREFIX}/caudium/server/fonts/ttf/$$0'

.include <bsd.port.post.mk>
