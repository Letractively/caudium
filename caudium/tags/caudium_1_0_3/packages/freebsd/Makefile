# New ports collection makefile for:	caudium
# Date created:				Mon Oct  9 23:22:40 CEST 2000

# Whom:					iMil <imil@gcu-squad.org>
#
# $FreeBSD$
#

PORTNAME=	caudium
PORTVERSION=	1.00.20001009
CATEGORIES=	www
MASTER_SITES=	http://www.oav.net/caudium/

MAINTAINER=	imil@gcu-squad.org

GNU_CONFIGURE=	yes

WRKSRC=		${WRKDIR}/${PORTNAME}


pre-configure:
	@cd ${WRKSRC}; cp tools/smartlink .

post-configure:
	@cd ${WRKSRC}/src/cmods; \
	(for a in Caudium PiXSL UltraLog;do cd $$a; sed s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; mv -f Makefile.tmp Makefile; cd ..; done)
	@cd ${WRKSRC}/src/tools; sed s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; mv -f Makefile.tmp Makefile

.include <bsd.port.mk>

