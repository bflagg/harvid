#!/bin/bash

#environment variables
: ${OSXMACHINE:=priroda.local}
: ${COWBUILDER:=opendaw.local}

NEWVERSION=$1

if test -n "$(echo "$NEWVERSION" | sed 's/^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$//')"; then
	NEWVERSION=""
fi

if test -z "$NEWVERSION"; then
	echo -n "No X.X.X version given as argument. Do a binary build only? [y/N] "
	read -n1 a
	echo
	if test "$a" != "y" -a "$a" != "Y"; then
		exit 1
	fi
fi

if test -n "$NEWVERSION"; then

	echo "commit pending changes.."
	git commit -a

	dch --newversion "${NEWVERSION}-0.1" --distribution unstable || exit
	vi ChangeLog
	make VERSION="v${NEWVERSION}" clean man || exit

	git status -s
	echo " - Version v${NEWVERSION}"

	echo -n "git commit and tag? [Y/n]"
	read -n1 a
	echo
	if test "$a" == "n" -o "$a" == "N"; then
		exit 1
	fi

	git commit -m "finalize changelog" debian/changelog ChangeLog doc/harvid.1
	git tag "v${NEWVERSION}"

	echo -n "git push and build? [Y/n] "
	read -n1 a
	echo
	if test "$a" == "n" -o "$a" == "N"; then
		exit 1
	fi

	git push origin && git push origin --tags
	git push rg42 && git push rg42 --tags

fi

VERSION=$(git describe --tags HEAD)
test -n "$VERSION" || exit


/bin/ping -q -c1 ${OSXMACHINE} &>/dev/null \
	&& /usr/sbin/arp -n ${OSXMACHINE} &>/dev/null
ok=$?
if test "$ok" != 0; then
	echo "OSX build host can not be reached."
	exit
fi

/bin/ping -q -c1 ${COWBUILDER} &>/dev/null \
	&& /usr/sbin/arp -n ${COWBUILDER} &>/dev/null
ok=$?
if test "$ok" != 0; then
	echo "Linux cowbuild host can not be reached."
	exit
fi

echo "building win32 ..."
./x-win32.sh || exit
echo "building linux static ..."
ssh $COWBUILDER ~/bin/build-harvid.sh

ok=$?
if test "$ok" != 0; then
	echo "remote build failed"
	exit
fi

rsync -Pa $COWBUILDER:/tmp/harvid-i386-linux-gnu-${VERSION}.tgz site/releases/ || exit
rsync -Pa $COWBUILDER:/tmp/harvid-x86_64-linux-gnu-${VERSION}.tgz site/releases/ || exit

echo "building osx package on $OSXMACHINE ..."
ssh $OSXMACHINE << EOF
exec /bin/bash -l
cd src/harvid || exit 1
git pull || exit 1
git fetch --tags || exit 1
./x-macosx.sh
EOF

ok=$?
if test "$ok" != 0; then
	echo "remote build failed"
	exit
fi

rsync -Pa $OSXMACHINE:Desktop/mydmg/harvid-${VERSION}.pkg site/releases/ || exit
rsync -Pa $OSXMACHINE:Desktop/mydmg/harvid-${VERSION}.dmg site/releases/ || exit
rsync -Pa $OSXMACHINE:Desktop/mydmg/harvid-${VERSION}.tgz tmp/ || exit

echo -n "${VERSION}" > site/releases/harvid_version.txt

echo "preparing website"

# git clone --single-branch -b gh-pages site

sed 's/@VERSION@/'$VERSION'/g;s/@DATE@/'"`date -R`"'/g;' site/index.tpl.html > site/index.html || exit
groff -m mandoc -Thtml doc/harvid.1 > site/harvid.1.html


cd site || exit
git add harvid.1.html releases/harvid_version.txt
git add releases/*-${VERSION}.* || exit
rm -f $(ls releases/* | grep -v "${VERSION}\." | grep -v harvid_version.txt | tr '\n' ' ')
git commit -a --amend -m "website $VERSION" || exit
git reflog expire --expire=now --all
git gc --prune=now
git gc --aggressive --prune=now


echo -n "git upload site and binaries? [Y/n] "
read -n1 a
echo
if test "$a" == "n" -o "$a" == "N"; then
	exit 1
fi

echo "uploading to github.."
git push --force

echo "uploading to ardour.org"
rsync -Pa \
	tmp/harvid-${VERSION}.tgz \
	releases/harvid-${VERSION}.dmg \
	releases/harvid-${VERSION}.pkg \
	releases/harvid-i386-linux-gnu-${VERSION}.tgz \
	releases/harvid-x86_64-linux-gnu-${VERSION}.tgz  \
	releases/harvid_installer-${VERSION}.exe \
	releases/harvid_version.txt \
		ardour.org:/persist/community.ardour.org/files/video-tools/
