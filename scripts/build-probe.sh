#!/bin/sh
# ffmpeg-rt :: build probe/h264probe.c against an installed build, the way an application uses the
# release: only dist/<arch>-<variant>/include and the import libraries, nothing from the build
# tree. h264probe prints the build's configuration, CPU flags and hwaccels, then decodes a file
# and reports frames per second. An x86 probe also runs right here if you give it a file.
#
# Usage: sh scripts/build-probe.sh <arch> <variant> [video file to decode (x86 only)]
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
ARCH=${1:-}; VARIANT=${2:-}
w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
u() { cygpath -u "$1" 2>/dev/null || echo "$1"; }
D=$(w "$DIST/$ARCH-$VARIANT")
[ -f "$(u "$D")/bin/avcodec.lib" ] || { echo "no $D: run sh scripts/build.sh $ARCH $VARIANT"; exit 1; }
case "$ARCH" in arm32) SUB=6.03 ;; x86) SUB=6.00 ;; *) echo "usage: sh scripts/build-probe.sh <arm32|x86> <variant> [file]"; exit 1 ;; esac
P=$(u "$BUILD")/probe-$ARCH-$VARIANT
rm -rf "$P"; mkdir -p "$P"; cd "$P" || exit 1
export MSYS2_ARG_CONV_EXCL='*'
echo "=== compile h264probe.c ($ARCH)"
"$(w "$RT2")/clang-cl.exe" "@$FF_ROOT_W/cross/$ARCH-msvc.rsp" -MT -O2 -W3 -nologo -c "$FF_ROOT_W/probe/h264probe.c" \
  -Foh264probe.obj "-I$D/include" || { echo "COMPILE FAILED"; exit 1; }
echo "=== link against the import libraries"
"$(w "$RT2")/lld-link.exe" -nologo h264probe.obj "$D/bin/avcodec.lib" "$D/bin/avformat.lib" "$D/bin/avutil.lib" \
  "$D/bin/swresample.lib" "@$FF_ROOT_W/cross/$ARCH-link.rsp" -out:h264probe.exe -subsystem:console,$SUB \
  -osversion:$SUB || { echo "LINK FAILED"; exit 1; }
"$(w "$RT2")/llvm-readobj.exe" --file-headers h264probe.exe | grep -E 'Machine:|MajorSubsystemVersion|MinorSubsystemVersion'
if [ "$ARCH" = x86 ] && [ -n "${3:-}" ]; then
  echo "=== run on $3"
  PATH="$(u "$D")/bin:$PATH" ./h264probe.exe "$(w "$3")" || { echo "PROBE RUN FAILED"; exit 1; }
fi
echo "PROBE DONE: $P/h264probe.exe"
