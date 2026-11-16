#!/bin/sh
# ffmpeg-rt :: zlib and dav1d, static, /MT, for one target: build/prefix-<arch>.
#
# FFmpeg links both into its DLLs (zlib into avformat, dav1d into avcodec), so the DLLs still
# import nothing but Windows system DLLs and each other.
#   zlib 1.3.2   CMake + Ninja with cross/cmake-<arch>.cmake. Kodi's configure patch 007 looks for
#                "z.lib", so the static zs.lib is installed under that name too.
#   dav1d 1.5.3  meson + Ninja with cross/meson-<arch>.ini, NEON (arm32) or nasm (x86) assembly.
#                Kodi's patch 005 looks for "libdav1d.lib", so libdav1d.a is installed under it too.
#
# Usage: sh scripts/build-deps.sh <arm32|x86>        (after fetch-deps.sh and gen-rsp.sh)
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
ARCH=${1:-}
case "$ARCH" in arm32|x86) ;; *) echo "usage: sh scripts/build-deps.sh <arm32|x86>"; exit 1 ;; esac

w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
u() { cygpath -u "$1" 2>/dev/null || echo "$1"; }
export MSYS2_ARG_CONV_EXCL='*'          # every path below is already in F:/... form
PFX=$(w "$BUILD/prefix-$ARCH")
D=$(w "$DEPS")
[ -f "$FF_ROOT/cross/cmake-$ARCH.cmake" ] || { echo "no cross/cmake-$ARCH.cmake: run sh scripts/gen-rsp.sh"; exit 1; }
# meson's clang-cl detection runs a bare "lld-link"; dav1d's x86 build looks for nasm on PATH
PATH="$(u "$RT2"):$(dirname "$(u "$NINJA")"):$PATH"
if [ "$ARCH" = x86 ]; then
  [ -f "$(u "$NASM")" ] || { echo "no nasm at $NASM: run sh scripts/build-nasm.sh"; exit 1; }
  PATH="$(dirname "$(u "$NASM")"):$PATH"
fi
export PATH

echo "=== zlib $ZLIB_VER ($ARCH) -> $PFX"
ZB=$(w "$BUILD/zlib-$ARCH")
rm -rf "$(u "$ZB")"
"$CMAKE" -G Ninja -S "$D/zlib-$ZLIB_VER" -B "$ZB" -DCMAKE_MAKE_PROGRAM="$(w "$NINJA")" \
  -DCMAKE_TOOLCHAIN_FILE="$FF_ROOT_W/cross/cmake-$ARCH.cmake" -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PFX" \
  -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON -DZLIB_BUILD_TESTING=OFF > "$(u "$BUILD")/zlib-$ARCH.log" 2>&1 \
  && "$CMAKE" --build "$ZB" -- -j "$JOBS" >> "$(u "$BUILD")/zlib-$ARCH.log" 2>&1 \
  && "$CMAKE" --install "$ZB" >> "$(u "$BUILD")/zlib-$ARCH.log" 2>&1 \
  || { tail -30 "$(u "$BUILD")/zlib-$ARCH.log"; echo "ZLIB FAILED ($BUILD/zlib-$ARCH.log)"; exit 1; }
[ -f "$(u "$PFX")/lib/zs.lib" ] || { echo "no zs.lib in $PFX/lib"; exit 1; }
cp -f "$(u "$PFX")/lib/zs.lib" "$(u "$PFX")/lib/z.lib"
echo "  zs.lib and z.lib"

echo "=== dav1d $DAV1D_VER ($ARCH) -> $PFX"
DB=$(w "$BUILD/dav1d-$ARCH")
rm -rf "$(u "$DB")"
"$MESON" setup "$DB" "$D/dav1d-$DAV1D_VER" --cross-file "$FF_ROOT_W/cross/meson-$ARCH.ini" --prefix "$PFX" \
  --buildtype release --default-library static \
  -Denable_asm=true -Denable_tests=false -Denable_tools=false -Denable_examples=false \
  > "$(u "$BUILD")/dav1d-$ARCH.log" 2>&1 \
  && "$MESON" compile -C "$DB" -j "$JOBS" >> "$(u "$BUILD")/dav1d-$ARCH.log" 2>&1 \
  && "$MESON" install -C "$DB" >> "$(u "$BUILD")/dav1d-$ARCH.log" 2>&1 \
  || { tail -30 "$(u "$BUILD")/dav1d-$ARCH.log"; echo "DAV1D FAILED ($BUILD/dav1d-$ARCH.log)"; exit 1; }
grep -E "define (HAVE_ASM|ARCH_ARM|ARCH_X86_32) " "$(u "$DB")/config.h" | sed 's/^/  /'
grep -q "define HAVE_ASM 1" "$(u "$DB")/config.h" || { echo "dav1d was built without its assembly"; exit 1; }
[ -f "$(u "$PFX")/lib/libdav1d.a" ] || { echo "no libdav1d.a in $PFX/lib"; exit 1; }
cp -f "$(u "$PFX")/lib/libdav1d.a" "$(u "$PFX")/lib/libdav1d.lib"
echo "  libdav1d.a and libdav1d.lib"
echo "DEPS DONE ($ARCH)"
