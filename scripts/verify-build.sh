#!/bin/sh
set -u
# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
FF_SELF=$0
FF_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$FF_ROOT/config.sh"
rt_check_config || exit 1
export PATH="/usr/bin:$PATH"
B=$FF_ROOT/build/msys2-shared
RO="$RT2/llvm-readobj.exe"; OD="$RT2/llvm-objdump.exe"; NM="$RT2/llvm-nm.exe"
cd "$B"

echo "############ S4.1 -- every object must be ARMNT 0x1C4 ############"
mapfile -t OBJS < <(find . -name '*.o' | sort)
EXP=${#OBJS[@]}; ATT=0; A=0; OTH=0; UNR=0
: > /tmp/bad.txt
for o in "${OBJS[@]}"; do
  ATT=$((ATT+1))
  M=$("$RO" --file-headers "$o" 2>/dev/null | grep -m1 -i 'Machine:')
  case "$M" in
    *ARMNT*) A=$((A+1));;
    "")      UNR=$((UNR+1)); echo "UNREADABLE $o" >> /tmp/bad.txt;;
    *)       OTH=$((OTH+1)); echo "$M  $o" >> /tmp/bad.txt;;
  esac
done
echo "objects found = $EXP, inspected = $ATT, ARMNT = $A, other = $OTH, unreadable = $UNR"
[ "$EXP" -eq "$ATT" ] && echo "DENOMINATOR OK" || echo "!!! DENOMINATOR MISMATCH !!!"
[ "$EXP" -gt 0 ] || echo "!!! ZERO OBJECTS -- NOT A PASS !!!"
[ -s /tmp/bad.txt ] && { echo "--- NON-ARMNT / UNREADABLE ---"; cat /tmp/bad.txt; }
echo "--- CONTROL: reader must be able to say NO ---"
"$RO" --file-headers $FF_ROOT/build/noext/h.obj 2>/dev/null | grep -m1 -i 'Machine:' | sed 's/^/  x64 control: /'

echo
echo "############ S4.2 -- the library set ############"
find . \( -name '*.dll' -o -name '*.lib' -o -name '*.a' \) -printf '%10s  %p\n' 2>/dev/null | sort -k2

echo
echo "############ NEON in the SHIPPED DLLs (not just the .o) ############"
NEONRE='	(vld[1-4]|vst[1-4]|vadd|vsub|vmul|vmla|vmls|vmov|vdup|vshl|vshr|vrshr|vqadd|vqsub|vrev|vext|vzip|vuzp|vtrn|vabs|vneg|vand|vorr|veor|vbic|vbsl|vbit|vbif|vmax|vmin|vpadd|vpmax|vpmin|vrhadd|vhadd|vhsub|vqmovn|vqmovun|vmovl|vmovn|vaddw|vsubw|vaddl|vsubl|vcgt|vcge|vceq|vtst|vcnt|vclz|vrecpe|vrsqrte|vtbl|vtbx|vswp|vqrshrn|vqshrn|vrshrn|vshrn|vmlal|vmull|vqdmul|vabd|vsri|vsli|vcvt|vpaddl|vqrdmul)'
for d in $(find . -name '*.dll' | sort); do
  "$OD" -d "$d" > /tmp/d.txt 2>/dev/null
  T=$(grep -cE '^ *[0-9a-f]+:' /tmp/d.txt)
  V=$(grep -E "$NEONRE" /tmp/d.txt | grep -cE '[[:space:]](d[0-9]+|q[0-9]+|\{d)')
  printf "  %-34s instructions=%-9s NEON=%s\n" "$(basename "$d")" "$T" "$V"
done

echo
echo "############ ARM asm objects actually built ############"
find . -path '*arm*' -name '*.o' | wc -l | sed 's/^/  arm .o count = /'
find . -path '*arm*' -name '*neon*.o' | wc -l | sed 's/^/  neon .o count = /'

echo
echo "############ ADDENDUM 3 -- undefined __aeabi_* in real output ############"
: > /tmp/u.txt; N=0
for o in "${OBJS[@]}"; do N=$((N+1)); "$NM" --undefined-only "$o" 2>/dev/null >> /tmp/u.txt; done
echo "  objects inspected = $N"
echo "  undefined __aeabi_* = $(grep -c '__aeabi_' /tmp/u.txt || true)"
echo "  CONTROL (seeded line matches?) = $(echo '  U __aeabi_idiv' | grep -c '__aeabi_')"
grep '__aeabi_' /tmp/u.txt | sort -u | head

echo
echo "############ RT 8.1 load gate on the DLLs (must be <= 6.3) ############"
for d in $(find . -name '*.dll' | sort); do
  printf "  %-34s %s\n" "$(basename "$d")" \
    "$("$RO" --file-headers "$d" 2>/dev/null | grep -E 'MajorOperatingSystemVersion|MinorOperatingSystemVersion|MajorSubsystemVersion|MinorSubsystemVersion|^  Machine' | tr -s ' ' | tr '\n' ' ')"
done
