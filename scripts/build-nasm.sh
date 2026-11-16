#!/bin/sh
# ffmpeg-rt :: nasm 2.15.05 (Kodi's pin) for this x64 build host, into build/nasm/nasm.exe.
# Only the x86 target needs it: FFmpeg and dav1d assemble their x86 SIMD code with it.
#
# nasm's Mkfiles/msvc.mak stops nmake with "cycle in dependency tree for target 'asm\nasm.obj'",
# so this compiles the makefile's own file lists (NASM = asm/nasm, LIBOBJ without disasm)
# directly with clang-cl. The generated sources are in the release tarball: no Perl step.
#
# Usage: sh scripts/build-nasm.sh        (after fetch-deps.sh and gen-rsp.sh)
set -u
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
export MSYS2_ARG_CONV_EXCL='*'
w() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
u() { cygpath -u "$1" 2>/dev/null || echo "$1"; }
SRC=$(w "$DEPS/nasm-$NASM_VER")
B=$(w "$BUILD/nasm-obj")
OUT=$(w "$BUILD/nasm")
[ -f "$(u "$SRC")/asm/nasm.c" ] || { echo "no nasm source at $SRC: run sh scripts/fetch-deps.sh"; exit 1; }
[ -f "$FF_ROOT/cross/x64-msvc.rsp" ] || { echo "no cross/x64-msvc.rsp: run sh scripts/gen-rsp.sh"; exit 1; }
OBJS="stdlib/snprintf stdlib/vsnprintf stdlib/strlcpy stdlib/strnlen stdlib/strrchrnul
 nasmlib/ver nasmlib/alloc nasmlib/asprintf nasmlib/errfile nasmlib/crc64 nasmlib/md5c nasmlib/string nasmlib/nctype
 nasmlib/file nasmlib/mmap nasmlib/ilog2 nasmlib/realpath nasmlib/path nasmlib/filename nasmlib/rlimit nasmlib/zerobuf
 nasmlib/readnum nasmlib/bsi nasmlib/rbtree nasmlib/hashtbl nasmlib/raa nasmlib/saa nasmlib/strlist nasmlib/perfhash
 nasmlib/badenum common/common
 x86/insnsa x86/insnsb x86/insnsd x86/insnsn x86/regs x86/regvals x86/regflags x86/regdis x86/disp8 x86/iflag
 asm/error asm/warnings asm/floats asm/directiv asm/directbl asm/pragma asm/assemble asm/labels asm/parser asm/preproc
 asm/quote asm/pptok asm/listing asm/eval asm/exprlib asm/exprdump asm/stdscan asm/strfunc asm/tokhash asm/segalloc
 asm/preproc-nop asm/rdstrnum asm/srcfile macros/macros
 output/outform output/outlib output/legacy output/nulldbg output/nullout output/outbin output/outaout output/outcoff
 output/outelf output/outobj output/outas86 output/outrdf2 output/outdbg output/outieee output/outmacho output/codeview"
INC="-I$SRC -I$SRC/include -I$SRC/x86 -I$SRC/asm -I$SRC/disasm -I$SRC/output"
rm -rf "$(u "$B")"; mkdir -p "$(u "$B")" "$(u "$OUT")" || exit 1
list=""
for o in $OBJS asm/nasm; do
  obj="$B/$(echo "$o" | tr / _).obj"
  "$RT2/clang-cl.exe" "@$FF_ROOT_W/cross/x64-msvc.rsp" -MT -O2 -nologo -w $INC -c "$SRC/$o.c" -Fo"$obj" \
    || { echo "COMPILE FAILED: $o"; exit 1; }
  [ "$o" = asm/nasm ] || list="$list $obj"
done
# as the makefile: everything but asm/nasm in libnasm.lib, so the linker takes only the members it
# needs (nasm.obj defines error_file itself, and some inline functions also exist as members)
"$RT2/llvm-lib.exe" -nologo -out:"$B/libnasm.lib" $list || { echo "LIB FAILED"; exit 1; }
"$RT2/lld-link.exe" "@$FF_ROOT_W/cross/x64-link.rsp" -nologo -subsystem:console -out:"$OUT/nasm.exe" \
  "$B/asm_nasm.obj" "$B/libnasm.lib" || { echo "LINK FAILED"; exit 1; }
cp -f "$(u "$SRC")/LICENSE" "$(u "$OUT")/LICENSE.txt"
"$(u "$OUT")/nasm.exe" -v || { echo "nasm.exe does not run"; exit 1; }
# smoke test: one SSE2 and one AVX2 instruction, assembled for win32
printf 'bits 32\nsection .text\npaddd xmm0, xmm1\nvpaddd ymm0, ymm1, ymm2\nret\n' > "$(u "$B")/t.asm"
"$(u "$OUT")/nasm.exe" -f win32 -o "$B/t.obj" "$B/t.asm" && "$RT2/llvm-objdump.exe" -d "$B/t.obj" | grep -E "paddd|ret" \
  || { echo "nasm.exe cannot assemble"; exit 1; }
echo "NASM DONE: $OUT/nasm.exe"
