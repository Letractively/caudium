# New ports collection makefile for:	pike
# Date created:		05 Sep 2001
# Whom:			kiwi@oav.net
#
# $FreeBSD$
#

PORTNAME=	caudium
PORTVERSION=	1.1.3-20010905-cvs
CATEGORIES=	www
MASTER_SITES=	ftp://ftp.oav.net/caudium/snapshot/1.1/	\
		ftp://ftp.caudium.net/caudium/snapshots/caudium/1.1/ \
		ftp://ftp.oav.net/caudium/pkg/FreeBSD/distfiles/ 
DISTNAME=	Caudium-${PORTVERSION}

MAINTAINER=	kiwi@oav.net

WRKSRC=		${WRKDIR}/${DISTNAME}

BUILD_DEPENDS=	pike:${PORTSDIR}/lang/pike/

IS_INTERACTIVE=	yes
GNU_CONFIGURE=  yes
.if exists(${WRKDIRPREFIX}${.CURDIR}/Makefile.inc)
.include "${WRKDIRPREFIX}${.CURDIR}/Makefile.inc"
.else
CONFIGURE_ARGS?= \
	--without-PiXSL
.endif
CONFIGURE_ARGS+= --without-debug

pre-fetch:
.if !defined(BATCH)
	@${SETENV} ${SCRIPTS_ENV} ${SH} ${SCRIPTDIR}/configure.caudium
.endif

pre-configure:
	@${ECHO} ${CONFIGURE_ARGS}

pre-clean:
	@${RM} -f ${WRKDIRPREFIX}${.CURDIR}/Makefile.inc

post-configure:
	@cd ${WRKSRC}/src/cmods; \
	(for a in Caudium PiXSL UltraLog;do cd $$a; sed s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; mv -f Makefile.tmp Makefile; cd ..; done)
	@cd ${WRKSRC}/src/tools; sed s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; mv -f Makefile.tmp Makefile
	@cd ${WRKSRC}/src/fast_cgi; sed s/"INSTALL=..\/"/"INSTALL=\/usr\/bin\/install -c"/ Makefile > Makefile.tmp; mv -f Makefile.tmp Makefile


.include <bsd.port.mk>
