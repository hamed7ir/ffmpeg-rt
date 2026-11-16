#!/bin/sh
# ffmpeg-rt :: build and install one configured target into dist/<arch>-<variant>:
#   bin/      the six DLLs, ffmpeg.exe, and their PDBs (make install leaves the PDBs behind)
#   bin/*.lib the import libraries (FFmpeg's install puts them next to the DLLs)
#   lib/      the .def files, include/ the headers
# Run from an MSYS2 shell (GNU make), after gate-config.sh passed.
#
# Usage: sh scripts/build.sh <arch> <variant>
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
ARCH=${1:-}; VARIANT=${2:-}
B=$(cygpath -u "$BUILD" 2>/dev/null || echo "$BUILD")/$ARCH-$VARIANT
D=$(cygpath -u "$DIST" 2>/dev/null || echo "$DIST")/$ARCH-$VARIANT
[ -f "$B/ffbuild/config.mak" ] || { echo "not configured: sh scripts/configure.sh $ARCH $VARIANT"; exit 1; }
sh "$FF_ROOT/scripts/gate-config.sh" "$ARCH" "$VARIANT" > "$B/gate.log" 2>&1 \
  || { cat "$B/gate.log"; echo "the gate fails: not building"; exit 1; }
export PATH="$FF_ROOT/cross/bin:/usr/bin:/usr/local/bin:$PATH"
cd "$B" || exit 1
export TMPDIR=.
export TMP="${TMP:-$MSYS2/tmp}" TEMP="${TEMP:-$MSYS2/tmp}"
export NM="$RT2/llvm-nm.exe"
echo "=== make -j$JOBS ($ARCH $VARIANT) $(date '+%T')"
make -j"$JOBS" > make.log 2>&1 || { tail -40 make.log; echo "MAKE FAILED ($B/make.log)"; exit 1; }
echo "  warnings: $(grep -c 'warning:' make.log)"
rm -rf "$D"
make install > install.log 2>&1 || { tail -20 install.log; echo "INSTALL FAILED ($B/install.log)"; exit 1; }
for p in $(find . -maxdepth 2 -name '*.pdb'); do cp -f "$p" "$D/bin/"; done
ls -la "$D/bin" | sed 's/^/  /'
echo "BUILD DONE $(date '+%T'): $D"
echo "next: sh scripts/verify-build.sh $ARCH $VARIANT"
