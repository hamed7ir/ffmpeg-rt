#!/bin/sh
# ffmpeg-rt :: the configuration gate. Read config.h and config_components.h, NEVER configure's
# summary: configure turns a component off when a dependency is missing and still exits 0.
# For "arm32 use" it also checks that the configuration is the one the PGO profile counted
# (pgo/arm32-config.sha256): a profile only fits the code it was made from.
# Must pass before build.sh.
#
# Usage: sh scripts/gate-config.sh <arch> <variant>
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
ARCH=${1:-}; VARIANT=${2:-}
B=$(cygpath -u "$BUILD" 2>/dev/null || echo "$BUILD")/$ARCH-$VARIANT
H=$B/config.h; C=$B/config_components.h
[ -f "$H" ] && [ -f "$C" ] || { echo "no $H: run sh scripts/configure.sh $ARCH $VARIANT"; exit 1; }

val() { grep -hE "define $1( |\$)" "$H" "$C" 2>/dev/null | head -1 | awk '{print $3}'; }
FAIL=0; N=0
check() {   # name expected
  N=$((N+1)); v=$(val "$1"); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$2" ]; then printf "  OK    %-30s = %s\n" "$1" "$v"
  else printf "  FAIL  %-30s = %s   (expected %s)\n" "$1" "$v" "$2"; FAIL=$((FAIL+1)); fi
}

echo "-- target --"
case "$ARCH" in
  arm32) for k in ARCH_ARM HAVE_NEON HAVE_ARMV6T2 CONFIG_THUMB; do check $k 1; done ;;
  x86)   for k in ARCH_X86_32 HAVE_X86ASM; do check $k 1; done ;;
  *)     echo "usage: sh scripts/gate-config.sh <arm32|x86> <variant>"; exit 1 ;;
esac
echo "-- shape and licence --"
for kv in HAVE_W32THREADS=1 CONFIG_SHARED=1 CONFIG_STATIC=0 CONFIG_GPL=0 CONFIG_NONFREE=0 CONFIG_VERSION3=0 \
          CONFIG_ZLIB=1 CONFIG_LIBDAV1D=1 CONFIG_NETWORK=0 CONFIG_AVFILTER=1 CONFIG_SWSCALE=1 CONFIG_SWRESAMPLE=1 \
          CONFIG_AVDEVICE=0 CONFIG_FFMPEG=1 CONFIG_DXVA2=1 CONFIG_H264_DXVA2_HWACCEL=1; do check ${kv%=*} ${kv#*=}; done
echo "-- decoders --"
for d in H264 HEVC AV1 LIBDAV1D VP8 VP9 OPUS AAC FLAC MP3 MP3FLOAT VORBIS MPEG4 H263 ALAC \
         PCM_S16LE PCM_S16BE PCM_S24LE PCM_S24BE PCM_S32LE PCM_F32LE PCM_F64LE PCM_U8 PCM_ALAW PCM_MULAW; do
  check CONFIG_${d}_DECODER 1
done
echo "-- demuxers, parsers, bsfs, protocols, muxers, filters --"
for kv in MOV_DEMUXER MATROSKA_DEMUXER OGG_DEMUXER MP3_DEMUXER AAC_DEMUXER FLAC_DEMUXER WAV_DEMUXER \
          H264_PARSER HEVC_PARSER VP9_PARSER OPUS_PARSER AAC_PARSER H264_MP4TOANNEXB_BSF HEVC_MP4TOANNEXB_BSF \
          FILE_PROTOCOL PIPE_PROTOCOL MP4_MUXER MATROSKA_MUXER NULL_MUXER \
          ATEMPO_FILTER AFORMAT_FILTER ARESAMPLE_FILTER SCALE_FILTER; do check CONFIG_$kv 1; done
check CONFIG_HTTP_PROTOCOL 0

if [ "$ARCH-$VARIANT" = arm32-use ]; then
  echo "-- the configuration the profile counted --"
  # the same lines, apart from paths, the compiler identity and the year
  got=$(cat "$H" "$C" | tr -d '\r' | grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|CONFIG_THIS_YEAR' \
        | sha256sum | cut -c1-64)
  want=$(cut -c1-64 "$FF_ROOT/pgo/arm32-config.sha256" 2>/dev/null)
  N=$((N+1))
  if [ "$got" = "$want" ]; then echo "  OK    configuration = pgo/arm32-config.sha256"
  else echo "  FAIL  configuration $got, the profile's $want"; FAIL=$((FAIL+1)); fi
fi

echo
echo "checks = $N, failed = $FAIL"
[ "$FAIL" -eq 0 ] || { echo "!!!! GATE FAILED -- STOP. DO NOT SHIP. !!!!"; exit 1; }
echo "GATE PASSED"
echo
echo "-- component census --"
for g in DECODER DEMUXER PARSER BSF PROTOCOL MUXER ENCODER FILTER; do
  on=$(grep -cE "^#define CONFIG_[A-Z0-9_]+_${g} 1$" "$C" 2>/dev/null)
  tot=$(grep -cE "^#define CONFIG_[A-Z0-9_]+_${g} [01]$" "$C" 2>/dev/null)
  printf "  %-9s %4s of %4s\n" "$g" "$on" "$tot"
done
