#!/bin/sh
# ffmpeg-rt :: check an installed build in dist/<arch>-<variant>/bin against the Windows RT 8.1 rules
# (scripts/check-dlls.py: machine, OS/subsystem version, imports, static CRT, PDBs, NEON) and, for
# arm32, rt2.x bug 0031 (scripts/pdata-calls.py: no call whose return address leaves its .pdata
# function). Results in dist/<arch>-<variant>/checks/.
#
# Usage: sh scripts/verify-build.sh <arch> <variant>
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
ARCH=${1:-}; VARIANT=${2:-}
w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
u() { cygpath -u "$1" 2>/dev/null || echo "$1"; }
DU=$(u "$DIST")/$ARCH-$VARIANT
[ -d "$DU/bin" ] || { echo "no $DU/bin: run sh scripts/build.sh $ARCH $VARIANT"; exit 1; }
mkdir -p "$DU/checks"
export MSYS2_ARG_CONV_EXCL='*'          # every path handed to a native tool below is F:/... already
OBJDUMP=$(w "$RT2")/llvm-objdump.exe
"$PYTHON" -I "$FF_ROOT_W/scripts/check-dlls.py" "$(w "$DU")/bin" "$ARCH" "$(w "$DU")/checks" "$ARCH-$VARIANT" \
  "$(w "$VCTOOLS")/bin/Hostx64/x64/dumpbin.exe" "$OBJDUMP"
fail=$?
if [ "$ARCH" = arm32 ]; then
  echo "-- rt2.x bug 0031 --"
  R=$DU/checks/$ARCH-$VARIANT-0031.txt
  : > "$R"
  t=0
  for f in "$DU"/bin/*.dll "$DU"/bin/*.exe; do
    t=$((t+1))
    "$PYTHON" -I "$FF_ROOT_W/scripts/pdata-calls.py" "$OBJDUMP" "$(w "$f")" >> "$R" 2>&1 \
      || { echo "  pdata-calls failed on $f"; fail=1; }
  done
  n=$(grep -c "calls whose return address leaves their function: 0 " "$R")
  echo "  files with no such call: $n of $t"
  [ "$n" -eq "$t" ] || { grep "leaves their function" "$R"; fail=1; }
fi
[ $fail -eq 0 ] && echo "VERIFY PASS ($ARCH $VARIANT)" || echo "VERIFY FAIL ($ARCH $VARIANT)"
exit $fail
