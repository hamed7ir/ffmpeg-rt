#!/bin/sh
set -u
export PATH="$FF_ROOT/cross/bin:/usr/bin:/usr/local/bin:$PATH"
cd $FF_ROOT/build/msys2-shared
export TMPDIR=.
export TMP="$MSYS2/tmp" TEMP="$MSYS2/tmp"

# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
export NM="$RT2/llvm-nm.exe"
echo "=== make -j12 ==="
make -j12 2>&1 | tail -80
echo "===MAKE EXIT=${PIPESTATUS[0]}==="
