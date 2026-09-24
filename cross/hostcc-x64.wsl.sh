#!/bin/sh
# ffmpeg-rt: HOST compiler wrapper. Builds the x64 tools FFmpeg runs during the
# build. WSL has no gcc and no passwordless sudo to install one, so rt2's clang-cl
# targets x64 Windows instead; WSL interop executes the results.
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

exec /mnt"$RT2/clang-cl.exe" \
     "@$FF_ROOT_W/cross/x64-msvc.rsp" -MT "$@"
