#!/bin/sh
# ffmpeg-rt: C compiler wrapper. clang-cl driver, MSVC ABI, ARM32, static CRT.
# Exists because (a) -vctoolsdir's value contains a space and cannot survive
# configure's word splitting, and (b) FFmpeg's configure feeds --extra-cflags to
# the ASSEMBLER as well (configure:5509), where clang's GCC driver would read a
# bare -MT as "dependency target name" and eat the next argument.
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

exec /mnt"$RT2/clang-cl.exe" \
     "@$FF_ROOT_W/cross/arm32-msvc.rsp" -MT "$@"
