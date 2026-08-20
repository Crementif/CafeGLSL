#!/usr/bin/env bash
SCRIPTDIR="${BASH_SOURCE%/*}"

if [ -z "$1" ]; then
	echo "No platform specified." 1>&2
	exit 1
fi

if [ -z "$2" ]; then
	echo "No cross file output filename specified." 1>&2
	exit 1
fi

PLATFORM="$1"
CROSSFILE="$2"
shift 2

# <platform>vars.sh puts the toolchain on PATH, but only inside the meson-toolchain.sh
# subprocess, so meson itself would not find the compiler. Re-derive PATH here. Take PATH
# only: the CFLAGS/LDFLAGS in those scripts are for the host machine and must not reach the
# build machine compiler.
if [ -f "/opt/devkitpro/${PLATFORM}vars.sh" ]; then
	PATH="$(DEVKITPRO=${DEVKITPRO:-/opt/devkitpro}; export DEVKITPRO; . "/opt/devkitpro/${PLATFORM}vars.sh" >/dev/null 2>&1; echo "$PATH")"
	export PATH
fi

if [ -x "/opt/devkitpro/portlibs_prefix.sh" ]; then
	PORTLIBS_PREFIX=$(/opt/devkitpro/portlibs_prefix.sh ${PLATFORM})
else
	PORTLIBS_PREFIX="/opt/devkitpro/portlibs/wiiu"
fi

${SCRIPTDIR}/meson-toolchain.sh ${PLATFORM} > ${CROSSFILE} || exit 1
meson setup --buildtype=plain --cross-file="${CROSSFILE}" --default-library=static --prefix="${PORTLIBS_PREFIX}" --libdir=lib "$@"
