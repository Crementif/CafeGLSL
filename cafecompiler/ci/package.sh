#!/usr/bin/env bash

set -euo pipefail

usage()
{
	echo "usage: ${0##*/} <host|wiiu> <builddir> <stagedir>" 1>&2
	exit 1
}

[ $# -eq 3 ] || usage

MODE="$1"
BUILDDIR="$2"
STAGEDIR="$3"

SRCDIR="$(cd "${BASH_SOURCE%/*}/../.." && pwd)"
CAFEDIR="${SRCDIR}/cafecompiler"

if [ ! -d "${BUILDDIR}" ]; then
	echo "no such build directory: ${BUILDDIR}" 1>&2
	exit 1
fi
BUILDDIR="$(cd "${BUILDDIR}" && pwd)"

VERSION="$("${CAFEDIR}/ci/version.sh")"

rm -rf "${STAGEDIR}"
mkdir -p "${STAGEDIR}/include/cafeglsl" "${STAGEDIR}/lib"

install -m 644 "${CAFEDIR}/CafeGLSLCompiler.h" "${STAGEDIR}/include/cafeglsl/"
install -m 644 "${CAFEDIR}/cafe_gx2.h" "${STAGEDIR}/include/cafeglsl/"
install -m 644 "${BUILDDIR}/cafecompiler/libcafeglsl.a" "${STAGEDIR}/lib/"
install -m 644 "${SRCDIR}/licenses/MIT" "${STAGEDIR}/LICENSE"

case "${MODE}" in
host)
	mkdir -p "${STAGEDIR}/bin"
	# meson appends .exe to the target name, which already ends in .elf.
	if [ -f "${BUILDDIR}/cafecompiler/glslcompiler.elf.exe" ]; then
		install -m 755 "${BUILDDIR}/cafecompiler/glslcompiler.elf.exe" \
			"${STAGEDIR}/bin/glslcompiler.exe"
		BINARY="bin/glslcompiler.exe"
	else
		install -m 755 "${BUILDDIR}/cafecompiler/glslcompiler.elf" \
			"${STAGEDIR}/bin/glslcompiler.elf"
		BINARY="bin/glslcompiler.elf"
	fi
	;;
wiiu)
	mkdir -p "${STAGEDIR}/lib/pkgconfig" "${STAGEDIR}/lib/cmake/cafeglsl"
	install -m 644 "${BUILDDIR}/meson-private/cafeglsl.pc" \
		"${STAGEDIR}/lib/pkgconfig/cafeglsl.pc"
	install -m 644 "${BUILDDIR}/cafecompiler/cafeglslConfig.cmake" \
		"${STAGEDIR}/lib/cmake/cafeglsl/"
	install -m 644 "${BUILDDIR}/cafecompiler/cafeglslConfigVersion.cmake" \
		"${STAGEDIR}/lib/cmake/cafeglsl/"
	BINARY=""
	;;
*)
	usage
	;;
esac

write_host_readme()
{
	cat <<-README
	# CafeGLSL ${VERSION} - standalone compiler

	A GLSL to GX2 shader compiler for the Wii U (Latte) GPU, built from Mesa.
	This archive holds the build for the machine that produced it.

	    ${BINARY} -vs shader.vert -ps shader.frag -o shaders.gsh

	Options:

	    -vs <file>  compile a vertex shader
	    -ps <file>  compile a pixel shader
	    -o  <file>  write the results to a GFD (.gsh) file
	    -v          print the R600 disassembly

	\`lib/libcafeglsl.a\` and \`include/cafeglsl/\` are the same compiler as a static
	library, for host tools that want to link it directly. Include it as
	\`<cafeglsl/CafeGLSLCompiler.h>\`. To build for the Wii U itself, use the
	wiiu archive instead - it carries a PowerPC library and the devkitPro
	pkg-config and CMake files to go with it.

	Licensed under the MIT license, as Mesa is. See LICENSE, and docs/license.rst
	in the source tree for the full third-party breakdown.
	README
}

write_wiiu_readme()
{
	cat <<-README
	# CafeGLSL ${VERSION} - Wii U library

	A GLSL to GX2 shader compiler for the Wii U (Latte) GPU, built from Mesa,
	cross-compiled for CafeOS with devkitPPC and wut.

	The tree is laid out as a devkitPro portlib, so it can be extracted straight
	over the wiiu portlibs prefix:

	    tar -xf <this-archive> -C /opt/devkitpro/portlibs/wiiu --strip-components=1

	From there, either build system finds it. With CMake:

	    find_package(cafeglsl REQUIRED)
	    target_link_libraries(myapp PRIVATE cafeglsl::cafeglsl)

	With pkg-config:

	    powerpc-eabi-pkg-config --cflags --libs cafeglsl

	Then include it as \`<cafeglsl/CafeGLSLCompiler.h>\`. The final link needs
	\`-Wl,--gc-sections\`; wut.specs already passes it, and the CMake package sets
	it as well.

	Licensed under the MIT license, as Mesa is. See LICENSE, and docs/license.rst
	in the source tree for the full third-party breakdown.
	README
}

if [ "${MODE}" = "host" ]; then
	write_host_readme > "${STAGEDIR}/README.md"
else
	write_wiiu_readme > "${STAGEDIR}/README.md"
fi

echo "staged ${MODE} tree for ${VERSION} in ${STAGEDIR}"
