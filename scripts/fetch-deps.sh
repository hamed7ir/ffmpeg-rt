#!/bin/sh
# ffmpeg-rt :: fetch the upstream source this repo builds against.
#
# Nothing upstream is committed here. This script reconstructs deps/ from a pinned, public
# tarball, so the build is reproducible without redistributing anybody else's tree.
#
# FFmpeg 8.1.2 takes ZERO source patches from this project -- 74/74 ARM .S files assemble
# as-is once the assembler is clang's integrated one rather than MSVC's armasm.exe. That is
# why patches/ is empty and why this one tarball is the whole dependency story.
set -u

FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"

# --- the pin ---------------------------------------------------------------------------------
# Same version scrcpy v4.1 pins in app/deps/ffmpeg.sh, so scrcpy-rt and ffmpeg-rt agree.
FFMPEG_VER=8.1.2
FFMPEG_URL=https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VER.tar.xz
FFMPEG_SHA=464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c

# DEPS comes from config.sh; it defaults to $FF_ROOT/deps.
# ⚠ Normalise to a POSIX path before tar sees it. GNU tar reads a leading "C:" in
# `-C C:/Users/...` as a REMOTE HOST and fails with "Cannot connect to C: resolve failed".
# Measured here the first time this script was run with DEPS exported as a Windows path.
DEPS=$(cygpath -u "$DEPS" 2>/dev/null || echo "$DEPS")
mkdir -p "$DEPS"

# --- the hash check, self-tested first ---------------------------------------------------
# A verifier that cannot fail is not a verifier. This project has shipped four instruments
# that reported PASS while broken, so the checker proves it can say NO before it says YES.
sha_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
_probe=$DEPS/.sha-selftest
printf 'abc' > "$_probe"
_want=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
_got=$(sha_of "$_probe")
rm -f "$_probe"
if [ "$_got" != "$_want" ]; then
  echo "sha256sum self-test FAILED: sha256('abc') came back as '$_got'"
  echo "The checker is broken. Every 'matches the pin' below would be meaningless. Stop."
  exit 2
fi
# and the other direction: a wrong expectation must be rejected
if [ "$_got" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
  echo "sha256sum self-test FAILED in the negative direction."; exit 2
fi
echo "checker OK: sha256('abc') = $(echo "$_got" | cut -c1-16)..."

# --- fetch -------------------------------------------------------------------------------
TARBALL=$DEPS/ffmpeg-$FFMPEG_VER.tar.xz
echo "=== FFmpeg $FFMPEG_VER ==="
if [ -f "$TARBALL" ]; then
  echo "have: $TARBALL"
else
  echo "download: $FFMPEG_URL"
  # curl here is a NATIVE Windows binary. Under MSYS2 a /d/... -o argument reaches it
  # verbatim and it fails with "curl: (23)" -- a path fault wearing a write-error costume.
  curl -fsSL --max-time 900 "$FFMPEG_URL" \
       -o "$(cygpath -w "$TARBALL" 2>/dev/null || echo "$TARBALL")" || exit 1
fi

GOT=$(sha_of "$TARBALL")
echo "  sha256: $GOT"
if [ "$GOT" != "$FFMPEG_SHA" ]; then
  echo "  ⚠ EXPECTED $FFMPEG_SHA"
  echo "  The pin did not match. Do not build from this tarball until you know why."
  exit 1
fi
echo "  matches the pin."

SRC=$DEPS/ffmpeg-$FFMPEG_VER
if [ -d "$SRC" ]; then
  echo "  extracted already: $SRC"
else
  echo "  extracting..."
  tar --force-local -xf "$TARBALL" -C "$DEPS" || exit 1
fi
[ -f "$SRC/configure" ] || { echo "  no configure in $SRC -- extraction did not produce the expected tree"; exit 1; }
echo "  RELEASE: $(cat "$SRC/RELEASE" 2>/dev/null)"
echo "  files: $(find "$SRC" -type f | wc -l)"

echo
echo "deps ready. Next:"
echo "  sh scripts/gen-rsp.sh          # expand cross/*.rsp.in against config.sh"
echo "  sh scripts/configure-arm32.sh"
echo "  sh scripts/gate-config.sh      # MANDATORY -- 23 asserts on config.h"
echo "  sh scripts/build.sh"
