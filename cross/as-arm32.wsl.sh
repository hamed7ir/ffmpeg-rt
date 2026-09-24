#!/bin/sh
# ffmpeg-rt: assembler wrapper. clang GCC-driver + integrated assembler, which
# CAN consume FFmpeg's GAS-syntax ARM .S files. This substitution -- replacing
# --toolchain=msvc's armasm.exe -- is the entire reason this port can carry NEON.
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

exec /mnt"$RT2/clang.exe" \
     --target=armv7-pc-windows-msvc "$@"
