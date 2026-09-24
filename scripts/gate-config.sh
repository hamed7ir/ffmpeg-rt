#!/bin/sh
set -u
# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
B=$FF_ROOT/build/msys2-shared
H="$B/config.h"; C="$B/config_components.h"
[ -f "$H" ] || { echo "!!! config.h MISSING - configure did not complete"; exit 1; }

val () { grep -hE "define $1( |\$)" "$H" "$C" 2>/dev/null | head -1 | awk '{print $3}'; }

FAIL=0; N=0
check () {   # name expected
  N=$((N+1)); v=$(val "$1"); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$2" ]; then printf "  OK    %-34s = %s\n" "$1" "$v"
  else printf "  FAIL  %-34s = %s   (expected %s)\n" "$1" "$v" "$2"; FAIL=$((FAIL+1)); fi
}

echo "######## ADDENDUM 7 MANDATORY GATE -- read config.h, NEVER the summary ########"
echo "-- AD7's five required symbols --"
check CONFIG_MOV_DEMUXER 1
check CONFIG_MATROSKA_DEMUXER 1
check CONFIG_H264_PARSER 1
check CONFIG_H264_DECODER 1
check CONFIG_FILE_PROTOCOL 1
echo "-- extra: the bitstream filter --disable-everything also killed (not in AD7's list) --"
check CONFIG_H264_MP4TOANNEXB_BSF 1
check CONFIG_HEVC_MP4TOANNEXB_BSF 1
echo "-- regression guards from the previous round --"
check HAVE_NEON 1
check CONFIG_THUMB 1
check CONFIG_SHARED 1
check CONFIG_STATIC 0
check CONFIG_DXVA2 1
check CONFIG_H264_DXVA2_HWACCEL 1
echo "-- the rest of the curated decoder set --"
for d in HEVC AV1 VP8 VP9 OPUS AAC FLAC PCM_S16LE; do check CONFIG_${d}_DECODER 1; done
echo "-- muxers (writing) must still be on --"
check CONFIG_MP4_MUXER 1
check CONFIG_MATROSKA_MUXER 1

echo
echo "checks = $N, failed = $FAIL"
if [ "$FAIL" -ne 0 ]; then echo "!!!! GATE FAILED -- STOP. DO NOT SHIP. !!!!"; exit 1; fi
echo "GATE PASSED"

echo
echo "######## component census (how generous did we actually get?) ########"
for g in DEMUXER PARSER BSF PROTOCOL DECODER MUXER ENCODER; do
  on=$(grep -cE "^#define CONFIG_[A-Z0-9_]+_${g} 1$" "$C" 2>/dev/null)
  tot=$(grep -cE "^#define CONFIG_[A-Z0-9_]+_${g} [01]$" "$C" 2>/dev/null)
  printf "  %-10s enabled %4s / %4s\n" "$g" "$on" "$tot"
done
