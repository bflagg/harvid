#!/bin/sh
# this script creates a statically linked version
# of ffmpeg, ffprobe and harvid for GNU/Linux
#
# It is intended to run in a pristine chroot or VM of a minimal
# debian system. see http://wiki.debian.org/cowbuilder
#
# This script
#  - git clone the source to $SRC (default /usr/src)
#  - build and install ffmpeg to $PFX (default ~/local/)
#  - build harvid and bundle it to /tmp/harvid*.tgz
#    (/tmp/ is fixed set by x-static.sh )
#

#use environment variables if set for SRC and PFX
: ${SRC=/usr/src}
: ${PFX=$HOME/local}

if [ "$(id -u)" != "0" -a -z "$SUDO" ]; then
	echo "This script must be run as root in pbuilder" 1>&2
  echo "e.g sudo cowbuilder --architecture amd64 --distribution wheezy --bindmounts /tmp --execute $0"
	exit 1
fi

$SUDO apt-get -y install git build-essential yasm \
	libass-dev libbluray-dev libgmp3-dev \
	libbz2-dev libfreetype6-dev libgsm1-dev liblzo2-dev \
	libmp3lame-dev libopenjpeg-dev libopus-dev librtmp-dev \
	libschroedinger-dev libspeex-dev libtheora-dev \
	libvorbis-dev libvpx-dev libx264-dev \
	libxvidcore-dev zlib1g-dev zlib1g-dev \
	libpng12-dev libjpeg8-dev

cd $SRC
git clone -b release/2.0 --depth 1 git://source.ffmpeg.org/ffmpeg
git clone -b master git://github.com/x42/harvid.git

cd $SRC/harvid
VERSION=$(git describe --tags HEAD)
git archive --format=tar --prefix=harvid-${VERSION}/ HEAD | gzip -9 > /tmp/harvid-${VERSION}.tar.gz

cd $SRC/ffmpeg
FFVERSION=2.0
git archive --format=tar --prefix=ffmpeg-${FFVERSION}/ HEAD | gzip -9 > /tmp/ffmpeg-${FFVERSION}.tar.gz

./configure --enable-gpl \
	--enable-libmp3lame --enable-libx264 --enable-libxvid --enable-libtheora  --enable-libvorbis \
	--enable-libvpx --enable-libopenjpeg --enable-libopus --enable-libschroedinger \
	--enable-libspeex --enable-libbluray --enable-libgsm \
	--disable-vaapi --disable-x11grab \
	--disable-devices \
	--enable-shared --enable-static --prefix=$PFX $@

make -j4 || exit 1
make install || exit 1

cd $SRC/ffmpeg
LIBDEPS=" \
 libmp3lame.a \
 libspeex.a \
 libtheoraenc.a \
 libtheoradec.a \
 libogg.a \
 libvorbis.a \
 libvorbisenc.a \
 libvorbisfile.a \
 libschroedinger-1.0.a \
 liborc-0.4.a \
 libgsm.a \
 libbluray.a \
 libxvidcore.a \
 libopus.a \
 libbz2.a \
 libvpx.a \
 libopenjpeg.a \
 libx264.a \
 libz.a \
 "

SLIBS=""
for SLIB in $LIBDEPS; do
	echo -n "searching $SLIB.."
	SL=`find /usr/lib -name "$SLIB"`
	if test -z "$SL"; then
		echo " not found."
		exit 1
	else
		echo
	fi
	SLIBS="$SLIBS $SL"
done

LIBF=$PFX/lib

gcc -o ffmpeg_s ffmpeg_opt.o ffmpeg_filter.o ffmpeg.o cmdutils.o \
	${LIBF}/libavformat.a \
	${LIBF}/libavdevice.a \
	${LIBF}/libavfilter.a \
	${LIBF}/libavcodec.a \
	${LIBF}/libswscale.a \
	${LIBF}/libswresample.a \
	${LIBF}/libpostproc.a \
	${LIBF}/libavutil.a \
	\
	$SLIBS \
	-lrt -lm -ldl -pthread -lstdc++ \
|| exit

gcc -o ffprobe_s ffprobe.o cmdutils.o \
	${LIBF}/libavformat.a \
	${LIBF}/libavdevice.a \
	${LIBF}/libavfilter.a \
	${LIBF}/libavcodec.a \
	${LIBF}/libswscale.a \
	${LIBF}/libswresample.a \
	${LIBF}/libpostproc.a \
	${LIBF}/libavutil.a \
	\
	$SLIBS \
	-lrt -lm -ldl -pthread -lstdc++ \
|| exit

strip ffmpeg_s
strip ffprobe_s

install -m755  ffmpeg_s $PFX/bin/
install -m755  ffprobe_s $PFX/bin/

cd $SRC/harvid
./x-static.sh || exit 1

ls -l /tmp/harvid*.tgz
