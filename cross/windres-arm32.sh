#!/bin/sh
# ffmpeg-rt: resource compiler wrapper. Two separate defects to fix here.
#
# (1) FFmpeg's .rc rule (common.mak:117) passes only $(IFLAGS), so the resource
#     preprocessor cannot find <windows.h>: the include folders go in here.
#
# (2) llvm-windres defaults the OUTPUT COFF MACHINE TO THE HOST. Without --target
#     it silently emits IMAGE_FILE_MACHINE_AMD64 (0x8664) into an ARM32 build --
#     measured, not theoretical. --target=arm gives ARMNT (0x1C4).
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

M="$VCTOOLS"
S="$WINSDK/Include/$WINSDKINCVER"
exec "$RT2/llvm-windres.exe" \
  --target=arm \
  --preprocessor-arg=--target=armv7-pc-windows-msvc \
  "--preprocessor-arg=-I$M/include" \
  "--preprocessor-arg=-I$S/ucrt" \
  "--preprocessor-arg=-I$S/um" \
  "--preprocessor-arg=-I$S/shared" \
  "$@"
