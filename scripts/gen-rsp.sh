#!/bin/sh
# ffmpeg-rt :: expand the templates in cross/ (*.rsp.in, *.ini.in, *.cmake.in) using config.sh.
#
# Response files, meson cross files and CMake toolchain files are read by native Windows tools,
# so they cannot contain shell variables -- the paths have to be real by the time the tool reads
# them. The .in files are tracked; the files they produce are generated and gitignored.
#
# Run this once after cloning, and again if you change config.sh.
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"

w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }   # native tools need F:/... paths, never /f/...
_VC=$(w "$VCTOOLS"); _SDK=$(w "$WINSDK"); _RT=$(w "$RT2")

n=0
for t in "$FF_ROOT"/cross/*.rsp.in "$FF_ROOT"/cross/*.ini.in "$FF_ROOT"/cross/*.cmake.in; do
  [ -f "$t" ] || continue
  o=${t%.in}
  sed -e "s|@VCTOOLS@|$_VC|g" -e "s|@WINSDK@|$_SDK|g" -e "s|@WINSDKVER@|$WINSDKVER|g" \
      -e "s|@WINSDKINCVER@|$WINSDKINCVER|g" -e "s|@RT2@|$_RT|g" -e "s|@ROOT@|$FF_ROOT_W|g" "$t" > "$o" || exit 1
  if grep -q '@[A-Z0-9]*@' "$o"; then echo "  $(basename "$o"): unexpanded placeholder left"; exit 1; fi
  echo "  $(basename "$o")"
  n=$((n+1))
done
echo "generated $n file(s) from config.sh"
