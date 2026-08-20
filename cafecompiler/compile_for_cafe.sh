#!/usr/bin/env bash
SCRIPTDIR="${BASH_SOURCE%/*}"
ROOTDIR="${SCRIPTDIR}/.."

export DEVKITPRO=${DEVKITPRO:-/opt/devkitpro}

"${SCRIPTDIR}/meson-cross.sh" wiiu ppccross "${ROOTDIR}/build-cafe" \
  -Db_sanitize=none \
  -Dtools= \
  -Dvulkan-drivers= \
  -Dgallium-drivers=r600 \
  -Db_lundef=false \
  -Db_staticpic=false \
  -Dglx=disabled \
  -Degl=disabled \
  -Dplatforms= \
  -Dllvm=disabled \
  --buildtype=release \
  -Db_lto=false

# Cafe consumers link the compiler archive directly. Host-only tools are built
# by compile_for_host.sh instead.
ninja -C "${ROOTDIR}/build-cafe" cafecompiler/libcafeglsl.a
