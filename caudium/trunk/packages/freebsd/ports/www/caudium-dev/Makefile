# New ports collection makefile for:	pike
# Date created:		05 Sep 2001
# Whom:			kiwi@oav.net
#
# $FreeBSD$
#

PORTNAME=	caudium
PORTVERSION=	1.3.1
CATEGORIES=	www
MASTER_SITES=	ftp://ftp.oav.net/caudium/snapshot/1.3/	\
		ftp://ftp.caudium.net/caudium/snapshots/caudium/1.3/ \
		ftp://ftp.oav.net/pkg_freebsd/distfiles/ \
		http://grendel.firewall.com/caudium-pkg/
DISTNAME=	Caudium-${PORTVERSION}-20020129-cvs

MAINTAINER=	kiwi@oav.net

BUILD_DEPENDS=	pike:${PORTSDIR}/lang/pike72cvs/
LIB_DEPENDS=	sablot.67:${PORTSDIR}/textproc/sablotron/ \
		js.0:${PORTSDIR}/lang/njs/
DEPENDS=	${PORTSDIR}/lang/pexts/

WRKSRC=		${WRKDIR}/${DISTNAME}

GNU_CONFIGURE=  yes
CONFIGURE_ARGS+= --without-debug --with-PiXSL

USE_GMAKE=	yes

pre-configure:
	@${ECHO} ${CONFIGURE_ARGS}

post-configure:
	@cd ${WRKSRC}/src/cmods; \
	(for a in Caudium PiXSL UltraLog;do cd $$a; ${SED} s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; ${MV} -f Makefile.tmp Makefile; cd ..; done)
	@cd ${WRKSRC}/src/tools; ${SED} s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; ${MV} -f Makefile.tmp Makefile
	@cd ${WRKSRC}/src/fast_cgi; ${SED} s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; ${MV} -f Makefile.tmp Makefile

post-build:
	@${SED} 's,@@PREFIX@@,${PREFIX},g' ${FILESDIR}/caudium.sh >${WRKDIR}/caudium.sh

post-install:
	@${INSTALL_SCRIPT} ${WRKDIR}/caudium.sh ${PREFIX}/etc/rc.d/caudium.sh.sample
	@${CAT} ${PKGMESSAGE}

.include <bsd.port.mk>
