#!/bin/sh
# ffmpeg-rt :: expand cross/*.rsp.in into cross/*.rsp using config.sh.
#
# Response files are handed verbatim to a native Windows tool, so they cannot contain shell
# variables -- the paths have to be real by the time the compiler reads them. The .in files
# are tracked; the .rsp files they produce are generated and gitignored.
#
# Run this once after cloning, and again if you change config.sh.
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"

n=0
for t in "$FF_ROOT"/cross/*.rsp.in; do
  [ -f "$t" ] || continue
  o=${t%.in}
  sed -e "s|@VCTOOLS@|$VCTOOLS|g"       -e "s|@WINSDK@|$WINSDK|g"       -e "s|@WINSDKVER@|$WINSDKVER|g"       -e "s|@RT2@|$RT2|g"       -e "s|@ROOT@|$FF_ROOT_W|g" "$t" > "$o" || exit 1
  echo "  $(basename "$o")"
  n=$((n+1))
done
echo "generated $n response file(s) from config.sh"
