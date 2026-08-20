#!/usr/bin/env bash
SCRIPTDIR="/opt/devkitpro"

# Drop -O<n> from the flags <platform>vars.sh gives us. They end up in the cross file's
# [built-in options], which meson puts after its own optimization flag, so the -O2 from
# wiiuvars.sh would override --buildtype and -Doptimization=. Let meson pick the level.
strip_opt_flags()
{
	local out="" f
	for f in $*; do
		case "$f" in
		-O*) ;;
		*) out="${out} ${f}" ;;
		esac
	done
	echo "${out}"
}

make_flag_list()
{
	local first=1
	while (( "$#" )); do
		if [ -n "$1" ]; then
			if [ $first -eq 0 ]; then
				echo -n ", "
			fi
			echo -n "'$1'"
			first=0
		fi
		shift
	done
}

if [ -z "$1" ]; then
	echo "No platform specified." 1>&2
	exit 1
fi

case "$1" in
"switch")
	PLAT_SYSTEM="horizon"
	PLAT_CPU_FAMILY="aarch64"
	PLAT_CPU="cortex-a57"
	PLAT_ENDIAN="little"
	if [ -f "${SCRIPTDIR}/switchvars.sh" ]; then source ${SCRIPTDIR}/switchvars.sh; fi
	;;
"3ds")
	PLAT_SYSTEM="horizon"
	PLAT_CPU_FAMILY="arm"
	PLAT_CPU="arm11mpcore"
	PLAT_ENDIAN="little"
	if [ -f "${SCRIPTDIR}/3dsvars.sh" ]; then source ${SCRIPTDIR}/3dsvars.sh; fi
	;;
"nds")
	PLAT_SYSTEM="bare"
	PLAT_CPU_FAMILY="arm"
	PLAT_CPU="arm946e-s"
	PLAT_ENDIAN="little"
	if [ -f "${SCRIPTDIR}/ndsvars.sh" ]; then source ${SCRIPTDIR}/ndsvars.sh; fi
	;;
"ppc")
	PLAT_SYSTEM="bare"
	PLAT_CPU_FAMILY="ppc"
	PLAT_CPU="ppc750"
	PLAT_ENDIAN="big"
	if [ -f "${SCRIPTDIR}/ppcvars.sh" ]; then source ${SCRIPTDIR}/ppcvars.sh; fi
	;;
"wiiu")
	PLAT_SYSTEM="cafeos"
	PLAT_CPU_FAMILY="ppc"
	PLAT_CPU="ppc750"
	PLAT_ENDIAN="big"
	if [ -f "${SCRIPTDIR}/wiiuvars.sh" ]; then
		source ${SCRIPTDIR}/wiiuvars.sh
	else
		TOOL_PREFIX="/opt/devkitpro/devkitPPC/bin/powerpc-eabi-"
		CPPFLAGS="-DESPRESSO -D__WIIU__ -D__WUT__ -I/opt/devkitpro/portlibs/wiiu/include -I/opt/devkitpro/portlibs/ppc/include -I/opt/devkitpro/wut/include"
		CFLAGS="-mcpu=750 -meabi -mhard-float -ffunction-sections -fdata-sections"
		CXXFLAGS="-mcpu=750 -meabi -mhard-float -ffunction-sections -fdata-sections"
		LDFLAGS="-L/opt/devkitpro/wut/lib -L/opt/devkitpro/portlibs/wiiu/lib -L/opt/devkitpro/portlibs/ppc/lib -specs=/opt/devkitpro/wut/share/wut.specs"
		LIBS="-lwut -lm"
	fi
	;;
*)
	echo "Unsupported platform." 1>&2
	exit 1
	;;
esac

# Build the library without exceptions, RTTI and unwind tables. Mesa's only throw is
# ASSERT_OR_THROW in src/gallium/drivers/r600/sfn/sfn_virtualvalues.h, which upstream already
# guards with __cpp_exceptions and is not on the GX2 compile path. This took about 200 KB off
# a consumer's RPX at no measurable runtime cost. Appended last so they win over the flags
# wiiuvars.sh and meson put in front of them.
SIZE_CFLAGS="-fno-asynchronous-unwind-tables -fno-unwind-tables"
SIZE_CXXFLAGS="${SIZE_CFLAGS} -fno-exceptions -fno-rtti"

echo "[binaries]"
echo "c = '${TOOL_PREFIX}gcc'"
echo "cpp = '${TOOL_PREFIX}g++'"
echo "ar = '${TOOL_PREFIX}gcc-ar'"
echo "strip = '${TOOL_PREFIX}strip'"
echo "pkg-config = '${TOOL_PREFIX}pkg-config'"
echo ""
echo "[built-in options]"
c_args_str=$(make_flag_list $CPPFLAGS $(strip_opt_flags $CFLAGS) $SIZE_CFLAGS)
if [ -n "$c_args_str" ]; then c_args_str="$c_args_str, "; fi
echo "c_args = [${c_args_str}'-fno-pic', '-fno-pie']"

c_link_str=$(make_flag_list $LDFLAGS $LIBS)
echo "c_link_args = [${c_link_str}]"

cpp_args_str=$(make_flag_list $CPPFLAGS $(strip_opt_flags $CXXFLAGS) $SIZE_CXXFLAGS)
if [ -n "$cpp_args_str" ]; then cpp_args_str="$cpp_args_str, "; fi
echo "cpp_args = [${cpp_args_str}'-fno-pic', '-fno-pie']"

cpp_link_str=$(make_flag_list $LDFLAGS $LIBS)
echo "cpp_link_args = [${cpp_link_str}]"
echo ""
echo "[host_machine]"
echo "system = '${PLAT_SYSTEM}'"
echo "cpu_family = '${PLAT_CPU_FAMILY}'"
echo "cpu = '${PLAT_CPU}'"
echo "endian = '${PLAT_ENDIAN}'"
echo ""
echo "[target_machine]"
echo "system = '${PLAT_SYSTEM}'"
echo "cpu_family = '${PLAT_CPU_FAMILY}'"
echo "cpu = '${PLAT_CPU}'"
echo "endian = '${PLAT_ENDIAN}'"
