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

#do-install:
#.if !exists(${FONTDIR})
#	@${ECHO} "*********************************************************"
#	@${ECHO} "If you want to use these fonts from X, install"
#	@${ECHO} "one of X-TT servers(x11-servers/Xtt*) and add ${FONTDIR}"
#	@${ECHO} "to your font path in /etc/XF86Config."
#	@${ECHO} "If you want to use these fonts from ghostscript,"
#	@${ECHO} "install korean/ftghostscript5 and edit"
#	@${ECHO} "${LOCALBASE}/share/ghostscript/5.10ft/hangul/hconfig.ps"
#	@${ECHO} "See examples in ${FONTDIR}"
#	@${ECHO} "*********************************************************"
#	${MKDIR} ${FONTDIR}
#.endif
.for FONTNAME in ${FONTLIST}
	${INSTALL_DATA} ${WRKSRC}/${FONTNAME}.ttf ${FONTDIR}
.endfor
#	${INSTALL_DATA} ${FILESDIR}/fonts.dir ${FONTDIR}/fonts.dir.baekmuk
#	${INSTALL_DATA} ${FILESDIR}/fonts.alias ${FONTDIR}/fonts.alias.baekmuk
#	${INSTALL_DATA} ${FILESDIR}/hconfig.ps ${FONTDIR}/hconfig.ps.baekmuk
#	${SETENV} PKG_PREFIX=${PREFIX} ${SH} ${PKGINSTALL} ${PKGNAME} POST-INSTALL

.include <bsd.port.post.mk>
