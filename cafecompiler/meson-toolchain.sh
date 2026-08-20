#!/usr/bin/env bash
SCRIPTDIR="/opt/devkitpro"

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

echo "[binaries]"
echo "c = '${TOOL_PREFIX}gcc'"
echo "cpp = '${TOOL_PREFIX}g++'"
echo "ar = '${TOOL_PREFIX}gcc-ar'"
echo "strip = '${TOOL_PREFIX}strip'"
echo "pkg-config = '${TOOL_PREFIX}pkg-config'"
echo ""
echo "[built-in options]"
c_args_str=$(make_flag_list $CPPFLAGS $CFLAGS)
if [ -n "$c_args_str" ]; then c_args_str="$c_args_str, "; fi
echo "c_args = [${c_args_str}'-fno-pic', '-fno-pie']"

c_link_str=$(make_flag_list $LDFLAGS $LIBS)
echo "c_link_args = [${c_link_str}]"

cpp_args_str=$(make_flag_list $CPPFLAGS $CXXFLAGS)
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
