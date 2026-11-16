# ffmpeg-rt (from kodi-rt): count ARM32 (Thumb-2) calls whose return address is outside the .pdata function or funclet holding the
# call (toolchain bug 0031: vcruntime's ARM GetEstablisherFrame looks up the raw return address, so such a call makes
# it pick the wrong function). Reads a linked PE image's .pdata and llvm-objdump's linear disassembly.
# Usage: python -I scripts/pdata-calls.py <llvm-objdump.exe> <image.exe>
# Also prints .pdata starts the sweep did not land on, and calls outside any .pdata range: both are places where the
# linear sweep may be misaligned by data in code (in ehtest's images they are all in the CRT part, after ehtest's code).
import re, struct, subprocess, sys, bisect

objdump, exe = sys.argv[1], sys.argv[2]
d = open(exe, 'rb').read()
pe = struct.unpack_from('<I', d, 0x3C)[0]
assert d[pe:pe + 4] == b'PE\0\0'
machine, nsec = struct.unpack_from('<HH', d, pe + 4)
assert machine == 0x1C4, 'not an ARMNT image'
optsz = struct.unpack_from('<H', d, pe + 20)[0]
opt = pe + 24
assert struct.unpack_from('<H', d, opt)[0] == 0x10b, 'not PE32'
base = struct.unpack_from('<I', d, opt + 28)[0]
exc_rva, exc_size = struct.unpack_from('<II', d, opt + 96 + 3 * 8)
secs = []
for i in range(nsec):
    o = opt + optsz + 40 * i
    vsz, va, rsz, roff = struct.unpack_from('<IIII', d, o + 8)
    secs.append((va, vsz, roff, rsz))

def off(rva):
    for va, vsz, roff, rsz in secs:
        if va <= rva < va + max(vsz, rsz):
            return roff + rva - va
    raise ValueError(hex(rva))

# ARM RUNTIME_FUNCTION: BeginAddress (|1 = Thumb), UnwindData. Flag (bits 0-1) != 0: packed, FunctionLength in bits
# 2-12; else UnwindData is the .xdata RVA and FunctionLength is bits 0-17 of its first word. Both in 2-byte units.
funcs = []
for i in range(exc_size // 8):
    b, u = struct.unpack_from('<II', d, off(exc_rva) + 8 * i)
    start = b & ~1
    if u & 3:
        length = ((u >> 2) & 0x7FF) * 2
    else:
        length = (struct.unpack_from('<I', d, off(u))[0] & 0x3FFFF) * 2
    funcs.append((start, start + length))
funcs.sort()
starts = [f[0] for f in funcs]
startset = set(starts)

# llvm-objdump takes a DLL's exports as symbols and, for ARMNT, starts decoding at the export RVA with the Thumb bit
# still set (odd), which misaligns the whole linear sweep. Disassemble a copy with the export directory cleared.
exp_rva, exp_size = struct.unpack_from('<II', d, opt + 96)
target = exe
if exp_rva:
    import os, tempfile
    fd, target = tempfile.mkstemp(suffix=os.path.splitext(exe)[1])
    b = bytearray(d)
    struct.pack_into('<II', b, opt + 96, 0, 0)
    os.write(fd, bytes(b)); os.close(fd)
out = subprocess.run([objdump, '-d', target], capture_output=True, text=True).stdout
if target != exe:
    os.remove(target)
line_re = re.compile(r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{4} )+)\s*(\S+)\s*(.*)$')
call_re = re.compile(r'^blx?(eq|ne|cs|hs|cc|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le)?$')   # bl/blx, also inside IT blocks
insn_addrs = set()
calls = []
seq = []                      # (rva, mnemonic, operands) in sweep order
targets = set()               # direct branch targets (b/b.w/bcc/cbz/cbnz with an immediate target)
literals = set()              # words read by a pc-relative load (ldr*/vldr [pc, #imm]; llvm-objdump prints "@ 0x<addr>")
branch_re = re.compile(r'^(b|b\.w|b(eq|ne|cs|hs|cc|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le)(\.w)?|cbn?z)$')
literal_re = re.compile(r'\[pc, #-?(0x)?[0-9a-f]+\]\s+@ 0x([0-9a-f]+)')
for line in out.splitlines():
    m = line_re.match(line)
    if not m:
        continue
    rva = int(m.group(1), 16) - base
    insn_addrs.add(rva)
    seq.append((rva, m.group(3), m.group(4)))
    if m.group(3).startswith(('ldr', 'vldr')):
        t = literal_re.search(m.group(4))
        if t:
            literals.add(int(t.group(2), 16) - base)
    if branch_re.match(m.group(3)):
        t = re.search(r'0x([0-9a-f]+)', m.group(4))
        if t:
            targets.add(int(t.group(1), 16) - base)
    if call_re.match(m.group(3)):
        calls.append((rva, 2 * len(m.group(2).split()), m.group(3) + ' ' + m.group(4).strip()))
index = {r: k for k, (r, _, _) in enumerate(seq)}

def unconditional(mn, ops):
    return (mn in ('b', 'b.w', 'bx', 'trap', 'udf', 'udf.w') or (mn in ('pop', 'pop.w') and 'pc' in ops)
            or (mn in ('ldr', 'ldr.w') and ops.startswith('pc,')))

def pool_like(rva, size, text):
    # A literal-pool word decoded as code. Narrow on purpose (blocks that the runtime enters, such as funclet entries
    # and catch continuations, are reached by no branch either): only a 16-bit "blx rN" that is the high half of a
    # 4-byte-aligned word (e.g. float 65536.0 = 0x47800000 reads as "movs r0, r0; blx r0"), and either
    #  - that word is read by a pc-relative load (exact; added 2026-11-13 for an 80-byte float pool at the end of an
    #    FFmpeg function in the instrumented PGO build, longer than the walk below), or
    #  - it is in a run that follows an unconditional instruction (at most 32 back) and contains no .pdata start and
    #    no direct branch target.
    # Returns the reason ('' = not pool data). Listed with its word.
    if size != 2 or not text.startswith('blx r') or rva % 4 != 2:
        return ''
    if rva - 2 in literals:
        return 'read by a pc-relative load'
    k = index[rva]
    while k > 0:
        r, mn, ops = seq[k - 1]
        if unconditional(mn, ops):
            run = [seq[j][0] for j in range(k, index[rva] + 1)]
            return '' if any(a in targets or a in startset for a in run) else 'after an unconditional branch, no branch to it'
        k -= 1
        if index[rva] - k > 32:
            return ''
    return ''

def word_at(rva):
    o = off(rva & ~3)
    return struct.unpack_from('<I', d, o)[0]

leave, outside = [], []
for rva, size, text in calls:
    i = bisect.bisect_right(starts, rva) - 1
    if i < 0 or not (funcs[i][0] <= rva < funcs[i][1]):
        outside.append((rva, text))
    elif rva + size >= funcs[i][1]:
        leave.append((rva, text, funcs[i], rva + size in startset, pool_like(rva, size, text)))
misaligned = [s for s in starts if s not in insn_addrs]
real = [x for x in leave if not x[4]]

print(f'{exe}: {len(funcs)} .pdata entries, {len(calls)} calls')
print(f'  calls whose return address leaves their function: {len(real)} '
      f'({sum(1 for x in real if x[3])} of them return into the next .pdata entry); '
      f'plus {len(leave) - len(real)} that are literal-pool data decoded as a call (listed with their word)')
print(f'  sweep checks: {len(misaligned)} .pdata starts not on an instruction boundary, '
      f'{len(outside)} calls outside any .pdata range')
for s in misaligned:
    print(f'    misaligned .pdata start {s:08x}')
for rva, text in outside:
    print(f'    call outside .pdata: {rva:08x} {text}')
for rva, text, f, nxt, pool in leave:
    note = f'POOL DATA: word 0x{word_at(rva):08x}, {pool}' if pool else ''
    print(f'    {rva:08x} {text:<44} func {f[0]:08x}-{f[1]:08x} {"-> next entry" if nxt else ""} {note}')
