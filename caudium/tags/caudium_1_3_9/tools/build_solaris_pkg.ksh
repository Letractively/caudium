PACKAGENAME=CDMcaudm
PKGBUILDIR=/tmp/caudiumbuildpkg$$
PKGDIR=/tmp/pkg$$  
if [ -f pkginfo ] ;
then
  rm -f pkginfo
fi
if [ -f prototype ] ;
then
  rm -f prototype
fi
if [ -d $PKGBUILDIR ] ;
then
  rm -rf $PKGBUILDIR
fi
if [ -d $PKGDIR ] ;
then
  rm -rf $PKGDIR
fi
mkdir $PKGBUILDIR
mkdir $PKGDIR

VR=$1
PIKE=$2
ACH=`uname -p`
PIKEMINORVER=`$PIKE -e 'write((version()/"release ")[1])'`
PIKEMAJORVER=`$PIKE -e 'write((version()/" ")[1]-"v")'`
echo "PKG=$PACKAGENAME" >> pkginfo
echo "NAME=Caudium Webserver" >> pkginfo
echo "BASEDIR=/usr/local" >> pkginfo
echo "CATEGORY=application" >> pkginfo
echo "ARCH=$ACH" >> pkginfo
echo "VENDOR=The Caudium Group" >> pkginfo
echo "EMAIL=general@caudium.info" >> pkginfo
echo "VERSION=$VR" >> pkginfo

echo "P CDMpike The Pike Programming Language" >> depend
echo "  ($ACH) $PIKEMAJORVER.$PIKEMINORVER" >> depend
make prefix=$PKGBUILDIR install
cp tools/caudium-rc_script $PKGBUILDIR/bin/caudiumctl
CD=`pwd`
cd $PKGBUILDIR
find . -exec chown root {} \; -exec chgrp bin {} \;
cd $CD
echo 'i pkginfo' > prototype
echo 'i depend' >> prototype
pkgproto $PKGBUILDIR= >> prototype
# for some reason we get BASEDIR + PREFIX when we install pkg, so let's 
# get rid of PREFIX in the prototype

#sed -e 's/usr\/local\///' < prototype > prototype.1
if [ -f prototype.1 ] ;
then
  mv prototype.1 prototype
fi
pkgmk -o -d $PKGDIR
pkgtrans -s $PKGDIR CDMcaudm.pkg $PACKAGENAME
cp $PKGDIR/CDMcaudm.pkg $PACKAGENAME-$VR-$ACH.pkg
gzip $PACKAGENAME-$VR-$ACH.pkg
echo cleaning up...
ls -l *.pkg.gz
rm -rf $PKGBUILDIR
rm -rf $PKGDIR
rm -f prototype
rm -f pkginfo
rm -f depend
