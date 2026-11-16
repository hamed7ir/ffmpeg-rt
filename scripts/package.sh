#!/bin/sh
# ffmpeg-rt :: the release zips: dist/ffmpeg-9.0.2-rt-arm32.zip (from dist/arm32-use) and
# dist/ffmpeg-9.0.2-rt-x86.zip (from dist/x86-plain), each with a .sha256 (scripts/package.py).
# Run verify-build.sh on both first: its results go into the zips.
#
# Usage: sh scripts/package.sh [arm32 dist folder] [x86 dist folder]
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
A=${1:-$DIST/arm32-use}; X=${2:-$DIST/x86-plain}
for d in "$A" "$X"; do
  [ -f "$(cygpath -u "$d" 2>/dev/null || echo "$d")/bin/avcodec-63.dll" ] || { echo "no build in $d"; exit 1; }
done
export MSYS2_ARG_CONV_EXCL='*'
"$PYTHON" -I "$FF_ROOT_W/scripts/package.py" "$(w "$DEPS")" "$(w "$DIST")" "$FFMPEG_VER" \
  "arm32=$(w "$A")" "x86=$(w "$X")"
