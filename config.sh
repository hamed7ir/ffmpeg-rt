# ffmpeg-rt :: the ONE place absolute paths are configured.
#
# Every script under scripts/ sources this file. Nothing else in the repo hardcodes a
# location, and the repo root is derived from the script's own path -- so a clone builds
# wherever it is put.
#
# Every value uses the `: "${VAR:=default}"` form, so an exported environment variable always
# wins over the default. RT2, VCTOOLS, WINSDK and WINSDKVER have the SAME NAMES in ffmpeg-rt,
# adb-rt and scrcpy-rt. ffmpeg-rt now needs rt2.4 (see 1.), so export RT2 for it separately:
#
#     export RT2=/c/toolchains/llvm-rt/rt2.4/bin
#     export VCTOOLS="/c/BuildTools/VC/Tools/MSVC/14.44.35207"
#
# The defaults are the values the release was actually built and device-verified with.

# ---- repo root, derived. Never hardcode it. -----------------------------------------------
if [ -z "${FF_ROOT:-}" ]; then
  FF_ROOT=$(cd "$(dirname "${FF_SELF:-$0}")/.." 2>/dev/null && pwd)
  [ -f "$FF_ROOT/config.sh" ] || FF_ROOT=$(cd "$(dirname "$0")" && pwd)
fi
# Windows form, for anything handed to a native tool or written into a response file.
FF_ROOT_W=$(cygpath -m "$FF_ROOT" 2>/dev/null || echo "$FF_ROOT")
export FF_ROOT FF_ROOT_W

# ---- 1. the compiler -- rt2.4, LLVM 23.1.1-rt2.4 ------------------------------------------
# WARNING must report 23.1.1-rt2.4. rt2.1-rt2.3 lack the fix for rt2.x bug 0031 (a call to a
# noreturn function at the very end of a function leaves its return address outside the
# function's .pdata range, which breaks unwinding on Windows ARM32), and the PGO profile in
# pgo/ was made with this exact build: another compiler gives different code, so the profile
# no longer fits it.
#
# The version string is the cheap check; these sha256 digests are the identifier, recorded
# from the build that produced the released binaries ("Varan clang version 23.1.1-rt2.4
# (f6e5f8e02a8c69d0479b5623215b8a8b8fcd2e01)"):
#   clang-cl.exe       f24b35ac6539a117afca2cf67a87e7d80b0e3c9d5ed981dbe7884664040f1d27
#   lld-link.exe       2f4ab430a7a680b90d12d1e947654646457f20cbae65442fd9c156c9239c0070
#   llvm-lib.exe       67ec0d584c553880838a8fcb25f28b5e3d4ca442d3ee48d557c6242ac9a3382b
#   llvm-profdata.exe  ea3b9e254fea5850b8978c2bc0664e6718872af22f4dedf1ec9df2e81eb616d5
: "${RT2:=F:/kodi-rt/tc/rt24d-cr/bin}"
RT2_COMMIT=f6e5f8e02a8c69d0479b5623215b8a8b8fcd2e01

# ---- 2. the MSVC toolset ------------------------------------------------------------------
# WARNING 14.51 (VS 2026) hard-#errors on ARM32 -- vadefs.h:15, "Support for 32-bit ARM has
# been permanently removed" -- and clang-cl auto-selects the NEWEST toolset unless pinned.
: "${VCTOOLS:=D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207}"

# ---- 3. the Windows SDK -------------------------------------------------------------------
# Headers from 10.0.26100.0; ARM32 import and UCRT libraries from 10.0.19041.0, the LAST SDK
# that ships them. x86 takes both from 10.0.26100.0. WINSDKVER keeps its meaning across the
# -rt repos: the SDK whose ARM32 libraries are linked.
: "${WINSDK:=D:/Windows Kits/10}"
: "${WINSDKVER:=10.0.19041.0}"
: "${WINSDKINCVER:=10.0.26100.0}"

# ---- 4. host build tools ------------------------------------------------------------------
# Native Windows cmake/ninja invoked from an MSYS2 shell. Do NOT substitute MSYS2's cmake.
# zlib builds with cmake + ninja, dav1d with meson (pip install meson, any recent version;
# 1.9.1 built the release) + ninja. NASM assembles the x86 SIMD code: scripts/build-nasm.sh
# builds Kodi's pinned 2.15.05 into build/nasm, the default here.
: "${CMAKE:=D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe}"
: "${NINJA:=D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe}"
: "${MESON:=F:/kodi-rt/tools/pyenv/Scripts/meson.exe}"
# Python runs the DLL checks (scripts/check-dlls.py, scripts/pdata-calls.py) and makes the zips.
: "${PYTHON:=F:/kodi-rt/tools/pyenv/Scripts/python.exe}"
: "${NASM:=$FF_ROOT_W/build/nasm/nasm.exe}"

# ---- 5. MSYS2 -- ffmpeg's configure and make need a POSIX shell and GNU make ---------------
# WARNING Git Bash has NO make. Do not use WSL: it has no make-compatible path namespace
# shared with native Windows compilers, and three separate blockers traced to that.
: "${MSYS2:=D:/MSYS2}"
: "${MAKE:=$MSYS2/usr/bin/make.exe}"
: "${JOBS:=8}"
export MSYS2 MAKE JOBS

# ---- derived --------------------------------------------------------------------------------
: "${BUILD:=$FF_ROOT/build}"
: "${DIST:=$FF_ROOT/dist}"
: "${DEPS:=$FF_ROOT/deps}"
export RT2 RT2_COMMIT VCTOOLS WINSDK WINSDKVER WINSDKINCVER CMAKE NINJA MESON PYTHON NASM BUILD DIST DEPS
mkdir -p "$BUILD" 2>/dev/null || true

# ---- the pins the scripts share -------------------------------------------------------------
FFMPEG_VER=9.0.2
DAV1D_VER=1.5.3
ZLIB_VER=1.3.2
NASM_VER=2.15.05
export FFMPEG_VER DAV1D_VER ZLIB_VER NASM_VER

# ---- the gate ------------------------------------------------------------------------------
rt_check_config() {
  _bad=0
  for _v in RT2 VCTOOLS WINSDK CMAKE NINJA; do
    eval "_p=\$$_v"
    case "$_v" in
      CMAKE|NINJA) [ -f "$_p" ] || { echo "config: $_v not found: $_p"; _bad=1; } ;;
      *)           [ -d "$_p" ] || { echo "config: $_v not found: $_p"; _bad=1; } ;;
    esac
  done
  [ -d "$WINSDK/Lib/$WINSDKVER/um/arm" ] || {
    echo "config: no ARM32 import libraries at $WINSDK/Lib/$WINSDKVER/um/arm"
    echo "        SDK 10.0.19041.0 is the last one that ships them."; _bad=1; }
  [ -d "$WINSDK/Include/$WINSDKINCVER/um" ] || {
    echo "config: no SDK headers at $WINSDK/Include/$WINSDKINCVER/um"; _bad=1; }
  if [ "$_bad" -eq 0 ]; then
    _v=$("$RT2/clang-cl.exe" --version 2>/dev/null | head -1)
    case "$_v" in
      *23.1.1-rt2.4*"$RT2_COMMIT"*) echo "config OK: $_v" ;;
      *23.1.1-rt2.4*) echo "config OK: $_v"
                      echo "config: note: not the rt2.4 build the release used ($RT2_COMMIT);"
                      echo "        the PGO profile may fit less well." ;;
      "")  echo "config: clang-cl.exe not runnable at \$RT2 ($RT2)"; _bad=1 ;;
      *)   echo "config: WRONG COMPILER -- $_v (expected 23.1.1-rt2.4)"; _bad=1 ;;
    esac
  fi
  [ "$_bad" -eq 0 ] || { echo; echo "Edit config.sh, or export the variables. See README."; return 1; }
  return 0
}
