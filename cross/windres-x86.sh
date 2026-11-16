#!/bin/sh
# ffmpeg-rt: resource compiler wrapper for desktop Windows x86. The x86 twin of windres-arm32.sh:
# the include folders for <windows.h>, and an explicit --target (llvm-windres would emit the
# host's machine type otherwise).
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

M="$VCTOOLS"
S="$WINSDK/Include/$WINSDKINCVER"
exec "$RT2/llvm-windres.exe" \
  --target=i686 \
  --preprocessor-arg=--target=i686-pc-windows-msvc \
  "--preprocessor-arg=-I$M/include" \
  "--preprocessor-arg=-I$S/ucrt" \
  "--preprocessor-arg=-I$S/um" \
  "--preprocessor-arg=-I$S/shared" \
  "$@"
