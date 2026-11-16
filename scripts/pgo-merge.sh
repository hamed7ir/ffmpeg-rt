#!/bin/sh
# ffmpeg-rt :: turn a training run's results into the profile the "arm32 use" build reads:
#   llvm-profdata merge <results>/prof/*.profraw  ->  pgo/ffshared-arm32.profdata
# and record the configuration the counting build had (pgo/arm32-config.sha256, the same
# normalisation as scripts/gate-config.sh), so the gate can tell when the profile stops fitting.
# The counting build cuts the source folder off static-function names (scripts/configure.sh), so
# the merged profile fits any checkout.
#
# Usage: sh scripts/pgo-merge.sh <results folder>
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
u() { cygpath -u "$1" 2>/dev/null || echo "$1"; }
R=$(u "${1:-}")
[ -n "${1:-}" ] && ls "$R"/prof/*.profraw > /dev/null 2>&1 || { echo "usage: sh scripts/pgo-merge.sh <results folder with prof/*.profraw>"; exit 1; }
I=$(u "$BUILD")/arm32-instr
[ -f "$I/config.h" ] || { echo "no $I/config.h: the counting build's configuration is needed"; exit 1; }
export MSYS2_ARG_CONV_EXCL='*'
list=""
for f in "$R"/prof/*.profraw; do list="$list $(w "$f")"; done
"$(w "$RT2")/llvm-profdata.exe" merge -o "$FF_ROOT_W/pgo/ffshared-arm32.profdata" $list || { echo "MERGE FAILED"; exit 1; }
"$(w "$RT2")/llvm-profdata.exe" show "$FF_ROOT_W/pgo/ffshared-arm32.profdata" | tail -6
if "$(w "$RT2")/llvm-profdata.exe" show --all-functions "$FF_ROOT_W/pgo/ffshared-arm32.profdata" | grep -qE '^  [A-Za-z]:/.*;'; then
  echo "warning: the profile names static functions by absolute path: was the counting build made by scripts/configure.sh?"
fi
h=$(cat "$I/config.h" "$I/config_components.h" | tr -d '\r' \
    | grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|CONFIG_THIS_YEAR' | sha256sum | cut -c1-64)
printf '%s  arm32 config.h + config_components.h of the build the profile counted, without the lines matching FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|CONFIG_THIS_YEAR (scripts/gate-config.sh)\n' "$h" \
  > "$FF_ROOT/pgo/arm32-config.sha256"
echo "pgo/ffshared-arm32.profdata and pgo/arm32-config.sha256 written. Next: configure.sh arm32 use."
