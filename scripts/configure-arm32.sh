#!/bin/sh
set -u
# ---- configuration ---------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root; the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
export PATH="$FF_ROOT/cross/bin:/usr/bin:/usr/local/bin:$PATH"
X=$FF_ROOT/cross
B=$FF_ROOT/build/msys2-shared
rm -rf "$B"; mkdir -p "$B"; cd "$B"
export TMPDIR=.
export TMP="${TMP:-$MSYS2/tmp}" TEMP="$TMP"
export NM="$RT2/llvm-nm.exe"
# -----------------------------------------------------------------------------------------
# WHY THERE IS NO "png" IN --enable-decoder BELOW. Measured 2026-09-23; not an oversight.
#
# scrcpy's app/src/icon.c:109 decodes app/data/scrcpy.png through libavformat + libavcodec on
# EVERY startup (screen.c:624) and on every disconnect (disconnect.c:12), so the png decoder is
# genuinely on scrcpy's DEFAULT path -- BATCH-SCRCPY-2 section 3 found this.
#
# Adding ",png" here does not work, and does not fail either. configure prints:
#     WARNING: Disabled png_decoder because some selected dependency is unsatisfied:
#              inflate_wrapper
# and then EXITS 0. FFmpeg's png decoder needs zlib; --disable-autodetect below means zlib is
# never found. Enabling it therefore means building zlib for armv7-pc-windows-msvc and adding
# --enable-zlib: a whole new third-party dependency, for a window icon.
#
# Consequence of leaving it out, stated so nobody mistakes it for the bug they are chasing:
# scrcpy logs "Could not open image codec" at startup and has no window icon; in AUDIO-ONLY
# mode the window falls back to a hardcoded size. Mirroring is unaffected.
#
# gate-config.sh deliberately does NOT check CONFIG_PNG_DECODER. A gate that must fail is
# worse than the gap it guards.
# -----------------------------------------------------------------------------------------
../../deps/ffmpeg-8.1.2/configure \
  --prefix=$FF_ROOT/dist/shared \
  --enable-cross-compile --arch=arm --target-os=win32 \
  --cc="$X/cc-arm32.sh" --cxx="$X/cc-arm32.sh" --as="$X/as-arm32.sh" \
  --windres="$X/windres-arm32.sh" \
  --ld="$RT2/lld-link.exe" --ar="$RT2/llvm-lib.exe" --nm="$RT2/llvm-nm.exe" \
  --ranlib="$RT2/llvm-ranlib.exe" --strip="$RT2/llvm-strip.exe" \
  --host-cc="$X/hostcc-x64.sh" --host-ld="$RT2/lld-link.exe" \
  --host-ldflags="@$FF_ROOT_W/cross/x64-link.rsp" \
  --enable-shared --disable-static \
  --enable-asm --enable-neon --enable-thumb \
  --disable-everything --disable-programs --disable-doc \
  --disable-avdevice --disable-avfilter --disable-network --disable-autodetect \
  --enable-dxva2 --enable-hwaccel=h264_dxva2 \
  --enable-decoder=h264,hevc,av1,vp8,vp9,opus,aac,flac,pcm_s16le \
  --enable-demuxers --enable-parsers --enable-bsfs --enable-protocols \
  --enable-muxer=mp4,matroska \
  --enable-avformat --enable-swresample \
  --extra-ldflags="@$FF_ROOT_W/cross/arm32-link.rsp"
echo "===CONFIGURE EXIT=$?==="
