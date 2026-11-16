#!/bin/sh
# ffmpeg-rt :: fetch the upstream sources this repo builds against, and patch FFmpeg.
#
# Nothing upstream is committed here. This script reconstructs deps/ from pinned, public
# tarballs, so the build is reproducible without redistributing anybody else's tree:
#   FFmpeg 9.0.2  the version Kodi master pins (tools/depends/target/ffmpeg/FFMPEG-VERSION)
#   dav1d 1.5.3   software AV1, linked statically into avcodec
#   zlib 1.3.2    linked statically into avformat
#   nasm 2.15.05  build tool only: the x86 SIMD assembler (scripts/build-nasm.sh)
# All four come from Kodi's mirror, the URL Kodi's own build uses, and each sha512 matches
# Kodi's pin file. The sha256 below is what this script checks.
#
# Then the patches in patches/ go onto the FFmpeg tree, in the order Kodi's Windows build
# applies its own (patches/kodi/README.md), then ffmpeg-rt's. Needs GNU patch
# (MSYS2: pacman -S patch) or git; Git Bash has both.
set -u

FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"

MIRROR=https://mirrors.kodi.tv/build-deps/sources
PINS="ffmpeg-$FFMPEG_VER.tar.xz 8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
dav1d-$DAV1D_VER.tar.bz2 e099f53253f6c247580c554d53a13f1040638f2066edc3c740e4c2f15174ce22
zlib-$ZLIB_VER.tar.xz d7a0654783a4da529d1bb793b7ad9c3318020af77667bcae35f95d0e42a792f3
nasm-$NASM_VER.tar.xz 3caf6729c1073bf96629b57cee31eeb54f4f8129b01902c73428836550b30a3f"

# DEPS comes from config.sh; it defaults to $FF_ROOT/deps.
# Normalise to a POSIX path before tar sees it. GNU tar reads a leading "C:" in
# `-C C:/Users/...` as a REMOTE HOST and fails with "Cannot connect to C: resolve failed".
DEPS=$(cygpath -u "$DEPS" 2>/dev/null || echo "$DEPS")
mkdir -p "$DEPS"

# --- the hash check, self-tested first ---------------------------------------------------
# A verifier that cannot fail is not a verifier, so the checker proves it can say NO before
# it says YES.
sha_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
_probe=$DEPS/.sha-selftest
printf 'abc' > "$_probe"
_want=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
_got=$(sha_of "$_probe")
printf 'abd' > "$_probe"
_other=$(sha_of "$_probe")
rm -f "$_probe"
if [ "$_got" != "$_want" ] || [ "$_other" = "$_want" ]; then
  echo "sha256sum self-test FAILED: sha256('abc') = '$_got', sha256('abd') = '$_other'"
  echo "The checker is broken. Every 'matches the pin' below would be meaningless. Stop."
  exit 2
fi
echo "checker OK: sha256('abc') = $(echo "$_got" | cut -c1-16)..."

# --- fetch, check, extract -------------------------------------------------------------------
echo "$PINS" | while read -r archive pin; do
  tarball=$DEPS/$archive
  echo "=== $archive ==="
  if [ -f "$tarball" ]; then
    echo "  have: $tarball"
  else
    echo "  download: $MIRROR/$archive"
    # curl here may be a NATIVE Windows binary: hand it a Windows path ("curl: (23)" otherwise).
    curl -fsSL --max-time 900 "$MIRROR/$archive" \
         -o "$(cygpath -w "$tarball" 2>/dev/null || echo "$tarball")" || exit 1
  fi
  got=$(sha_of "$tarball")
  echo "  sha256: $got"
  if [ "$got" != "$pin" ]; then
    echo "  EXPECTED $pin"
    echo "  The pin did not match. Do not build from this tarball until you know why."
    exit 1
  fi
  echo "  matches the pin."
  dir=$DEPS/${archive%.tar.*}
  if [ -d "$dir" ]; then
    echo "  extracted already: $dir"
  else
    tar --force-local -xf "$tarball" -C "$DEPS" || exit 1
    [ -d "$dir" ] || { echo "  $archive did not extract to $dir"; exit 1; }
    echo "  extracted: $dir"
  fi
done || exit 1

# --- patch FFmpeg ----------------------------------------------------------------------------
SRC=$DEPS/ffmpeg-$FFMPEG_VER
STAMP=$SRC/.ffmpeg-rt-patched
LIST=$( (ls "$FF_ROOT"/patches/kodi/*-ffmpeg-windows-*.patch; ls "$FF_ROOT"/patches/kodi/*-ffmpeg-all-*.patch;
         ls "$FF_ROOT"/patches/[0-9][0-9][0-9][0-9]-*.patch) 2>/dev/null)
WANT=$(for p in $LIST; do echo "$(sha_of "$p")  $(basename "$p")"; done)
echo "=== patches ($(echo "$LIST" | wc -l)) ==="
if [ -f "$STAMP" ]; then
  if [ "$(cat "$STAMP")" = "$WANT" ]; then echo "  applied already (deps/ffmpeg-$FFMPEG_VER/.ffmpeg-rt-patched)"
  else echo "  $SRC was patched with a different patch set. Delete it and run this again."; exit 1; fi
else
  [ -f "$SRC/.ffmpeg-rt-patching" ] && { echo "  an earlier run stopped halfway: delete $SRC and run this again"; exit 1; }
  : > "$SRC/.ffmpeg-rt-patching"
  for p in $LIST; do
    echo "  $(basename "$p")"
    if command -v patch > /dev/null 2>&1; then
      patch -p1 -N -r - -d "$SRC" -i "$p" > "$DEPS/.patch.out" 2>&1; rc=$?
    elif command -v git > /dev/null 2>&1; then
      # deps/ sits inside this clone: stop git from finding the clone, so it patches plain files
      (cd "$SRC" && GIT_CEILING_DIRECTORIES=$(dirname "$SRC") git apply -p1 --whitespace=nowarn "$p") \
        > "$DEPS/.patch.out" 2>&1; rc=$?
    else
      echo "  no GNU patch and no git on PATH (MSYS2: pacman -S patch)"; exit 1
    fi
    if [ $rc -ne 0 ] || grep -qiE 'FAILED|reject|Reversed' "$DEPS/.patch.out"; then
      sed 's/^/    /' "$DEPS/.patch.out"; echo "  PATCH FAILED: $(basename "$p")"; exit 1
    fi
  done
  rm -f "$SRC/.ffmpeg-rt-patching" "$DEPS/.patch.out"
  echo "$WANT" > "$STAMP"
  echo "  all applied."
fi
echo "  FFmpeg RELEASE: $(cat "$SRC/RELEASE" 2>/dev/null)"

echo
echo "deps ready. Next:"
echo "  sh scripts/gen-rsp.sh                 # expand the cross/ templates against config.sh"
echo "  sh scripts/build-nasm.sh              # x86 only: nasm for the SIMD code"
echo "  sh scripts/build-deps.sh arm32        # zlib + dav1d (and: x86)"
echo "  sh scripts/configure.sh arm32 use     # then gate-config.sh, build.sh, verify-build.sh"
