#!/bin/sh
# ffmpeg-rt :: a training kit for the Surface RT, from the counting build (dist/arm32-instr):
#   <kit>/ffmpeg/          the instrumented DLLs and ffmpeg.exe
#   <kit>/clips/           put the training clips here (pgo/README.md lists the release's set)
#   <kit>/run-ffpgo.cmd    the training run: double-click it on the device
# The run writes results\prof\ff-<module>.profraw, one per DLL; bring the results folder back and
# merge it with scripts/pgo-merge.sh.
#
# Usage: sh scripts/pgo-kit.sh [kit folder]        (default: build/pgo-kit)
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
u() { cygpath -u "$1" 2>/dev/null || echo "$1"; }
I=$(u "$DIST")/arm32-instr/bin
K=${1:-$(u "$BUILD")/pgo-kit}
[ -f "$I/ffmpeg.exe" ] || { echo "no $I/ffmpeg.exe: configure, build and verify arm32 instr first"; exit 1; }
[ -e "$K" ] && { echo "$K exists already; move it away first"; exit 1; }
mkdir -p "$K/ffmpeg" "$K/clips" || exit 1
cp "$I"/*.dll "$I"/ffmpeg.exe "$K/ffmpeg/" || exit 1
cp "$FF_ROOT/pgo/run-ffpgo.cmd" "$K/"
cat > "$K/clips/README.txt" <<'EOF'
Put the training clips here: every file in this folder is used.
The release's profile was trained on the seven clips in ffmpeg-rt's pgo/README.md.
EOF
cat > "$K/README.txt" <<'EOF'
ffmpeg-rt PGO training run

A counting ("instrumented") build of the shared FFmpeg DLLs and ffmpeg.exe. It decodes the clips
in clips\ four ways and writes down which code runs; that profile makes the release build faster
on exactly that code.

1. Put the clips into clips\ and copy this folder to the Surface RT.
2. Double-click run-ffpgo.cmd. Each file is decoded four ways for 40 seconds each (short files
   loop), a few minutes per file.
3. Bring back the results folder it names at the end (results\ with log.txt and prof\*.profraw).

Nothing is installed and nothing outside this folder is changed.
EOF
printf 'kit ready: %s\n' "$K"
ls -la "$K" "$K/ffmpeg" | sed 's/^/  /'
