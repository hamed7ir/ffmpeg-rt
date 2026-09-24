#!/bin/sh
set -u
export PATH="$FF_ROOT/cross/bin:/usr/bin:$PATH"
export TMP="$MSYS2/tmp" TEMP="$MSYS2/tmp"

# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
X=$FF_ROOT/cross
B=$FF_ROOT/build/msys2-shared
S=$FF_ROOT/deps/ffmpeg-8.1.2
P=$FF_ROOT/build/probe
rm -rf "$P"; mkdir -p "$P"; cd "$P"
echo "=== compile h264probe.c (ARM32, MSVC ABI) ==="
"$X/cc-arm32.sh" -c $FF_ROOT/probe/h264probe.c -Foh264probe.obj "-I$B" "-I$S" -W3 2>&1 | head -25
[ -f h264probe.obj ] || { echo "COMPILE FAILED"; exit 1; }
"$RT2/llvm-readobj.exe" --file-headers h264probe.obj | grep -m1 -i Machine
echo "=== link against the built import libs ==="
"$RT2/lld-link.exe" h264probe.obj \
  "$B/libavcodec/avcodec.lib" "$B/libavformat/avformat.lib" \
  "$B/libavutil/avutil.lib" "$B/libswresample/swresample.lib" \
  @$FF_ROOT_W/cross/arm32-link.rsp \
  -out:h264probe.exe -subsystem:console,6.03 -osversion:6.03 \
  -defaultlib:libcmt -defaultlib:libvcruntime -defaultlib:libucrt \
  -defaultlib:kernel32 -defaultlib:user32 -defaultlib:ole32 2>&1 | head -20
ls -la h264probe.exe 2>/dev/null || { echo "LINK FAILED"; exit 1; }
"$RT2/llvm-readobj.exe" --file-headers h264probe.exe | \
  grep -E 'Machine|MajorOperatingSystemVersion|MinorOperatingSystemVersion|MajorSubsystemVersion|MinorSubsystemVersion|Subsystem:'
