#!/bin/bash
# build-all.sh - script to build all packages with a build order specified by buildorder.py

set -e -u -o pipefail

build_all_packages() {
	set -e -u -o pipefail
	package=`basename $1`
	# Check build status (grepping is a bit crude, but it works)
	if [ -e $BUILDSTATUS_FILE ] && grep "^$package$" $BUILDSTATUS_FILE >/dev/null; then
		echo "Skipping $package";
		continue;
	fi
	echo "Building $package... "
	BUILD_START=`date "+%s"`
	bash -x $BUILDSCRIPT -a $TERMUX_ARCH -s \
        	$TERMUX_DEBUG ${TERMUX_DEBDIR+-o $TERMUX_DEBDIR} $package \
		> $BUILDALL_DIR/${package}.out 2> $BUILDALL_DIR/${package}.err
	BUILD_END=`date "+%s"`
	BUILD_SECONDS=$(( $BUILD_END - $BUILD_START ))
	echo -e "\t$package done in $BUILD_SECONDS"
	# Update build status
	echo "$package" >> "$BUILDSTATUS_FILE"
}

export -f build_all_packages

# Read settings from .termuxrc if existing
test -f $HOME/.termuxrc && . $HOME/.termuxrc
: ${TERMUX_TOPDIR:="$HOME/.termux-build"}
: ${TERMUX_ARCH:="aarch64"}
: ${TERMUX_DEBUG:=""}

_show_usage () {
	echo "Usage: ./build-all.sh [-a ARCH] [-d] [-o DIR]"
	echo "Build all packages."
	echo "  -a The architecture to build for: aarch64(default), arm, i686, x86_64 or all."
	echo "  -d Build with debug symbols."
	echo "  -o Specify deb directory. Default: debs/."
	exit 1
}

while getopts :a:hdDso: option; do
case "$option" in
	a) TERMUX_ARCH="$OPTARG";;
	d) TERMUX_DEBUG='-d';;
	o) TERMUX_DEBDIR="$(realpath -m $OPTARG)";;
	h) _show_usage;;
esac
done
shift $((OPTIND-1))
if [ "$#" -ne 0 ]; then _show_usage; fi

if [[ ! "$TERMUX_ARCH" =~ ^(all|aarch64|arm|i686|x86_64)$ ]]; then
	echo "ERROR: Invalid arch '$TERMUX_ARCH'" 1>&2
	exit 1
fi

export BUILDSCRIPT="`dirname $0`/build-package.sh"
export BUILDALL_DIR="$TERMUX_TOPDIR/_buildall-$TERMUX_ARCH"
export BUILDORDER_FILE="$BUILDALL_DIR/buildorder.txt"
export BUILDSTATUS_FILE="$BUILDALL_DIR/buildstatus.txt"

export TERMUX_TOPDIR
export TERMUX_ARCH
export TERMUX_DEBUG
export TERMUX_DEBDIR

if [ -e $BUILDORDER_FILE ]; then
	echo "Using existing buildorder file: $BUILDORDER_FILE"
else
	mkdir -p $BUILDALL_DIR
	./scripts/buildorder.py > $BUILDORDER_FILE
fi
if [ -e $BUILDSTATUS_FILE ]; then
	echo "Continuing build-all from: $BUILDSTATUS_FILE"
fi

exec >  >(tee -a $BUILDALL_DIR/ALL.out)
exec 2> >(tee -a $BUILDALL_DIR/ALL.err >&2)
trap "echo ERROR: See $BUILDALL_DIR/\${package}.err" ERR

cat $BUILDORDER_FILE | while read line; do
	echo $line | xargs -n 1 -P $(($(nproc)/2)) bash -c 'build_all_packages $1' _
done

# Update build status
rm -f $BUILDSTATUS_FILE
echo "Finished"
