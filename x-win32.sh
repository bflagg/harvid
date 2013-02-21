#!/bin/sh
## cross-compile and package win32 version of harvid ##

# requires mingw and a working wine install with NSIS
# and dependent libraries installed in wine C:\x-prefix\
# x-compiled ffmpeg, libpng, pthread,.. with
# 'configure prefix=~/.wine/drive_c/x-prefix host=i586-mingw32msvc-gcc ...'

VERSION=$(git describe --tags HEAD || echo "X.X.X")
WINEROOT=$HOME/.wine/drive_c/x-prefix
NSISEXE=$HOME/.wine/drive_c/Program\ Files/NSIS/makensis.exe


NSIDIR=/tmp/harvid-build-nsi/

make clean
make ARCH=mingw WINEROOT=${WINEROOT} CFLAGS="-DNDEBUG -O2" || exit

# NSI package

rm -rf $NSIDIR
mkdir -p $NSIDIR
echo $NSIDIR

WINEBIN=${WINEROOT}/bin/
cp -v src/harvid $NSIDIR/harvid.exe
i686-w64-mingw32-strip $NSIDIR/harvid.exe

dllssrc="avformat avcodec avdevice avutil swscale swresample avfilter avresample postproc jpeg"
for fname in $dllssrc; do
	cp -v `readlink -f ${WINEROOT}/bin/lib${fname}.dll` $NSIDIR
done

cp -v $WINEBIN/zlib1.dll $NSIDIR
cp -v $WINEBIN/pthreadGC2.dll $NSIDIR
cp -v $WINEBIN/cygwin1.dll $NSIDIR

sed 's/@VERSION@/'${VERSION}'/' pkg/win/harvid.nsi > $NSIDIR/harvid.nsi
wine "$NSISEXE" "Z:/$NSIDIR/harvid.nsi"

echo "--- DONE ---"
ls -l $NSIDIR/*exe

test -d site/releases/ || exit
cp $NSIDIR/harvid_installer-*exe site/releases/
