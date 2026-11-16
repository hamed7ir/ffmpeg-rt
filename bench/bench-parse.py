# ffmpeg-rt: the summary of a bench run (bench/run-ffbench.cmd): per clip, mode and build
# the best of three -benchmark runs. Video modes (t1, tbgra) in frames per second (frames from ffmpeg's last
# "frame=" count, time from "rtime="), audio as times real time ("time=" of the decoded audio / rtime). Then the
# PGO build against the plain one, in percent.
# Usage: python -I bench/bench-parse.py <results\log.txt> [markdown]
import re
import sys

text = open(sys.argv[1], encoding='utf-8', errors='replace').read().replace('\r', '\n')
blocks = re.split(r'\n=== ', '\n' + text)[1:]
best = {}
for b in blocks:
    head, _, body = b.partition('\n')
    parts = head.split()
    if len(parts) < 3:
        continue
    clip, mode, build = parts[0], parts[1], parts[2]
    m = re.search(r'bench: utime=[\d.]+s stime=[\d.]+s rtime=([\d.]+)s', body)
    if not m:
        continue
    rtime = float(m.group(1))
    if rtime <= 0:
        continue
    if mode == 'audio':
        ts = re.findall(r'time=(\d+):(\d+):([\d.]+)', body)
        if not ts:
            continue
        h, mi, s = ts[-1]
        dur = int(h) * 3600 + int(mi) * 60 + float(s)
        if dur <= 0:
            continue
        val = dur / rtime
    else:
        fr = re.findall(r'frame=\s*(\d+)', body)
        if not fr or int(fr[-1]) == 0:
            continue
        val = int(fr[-1]) / rtime
    key = (clip, mode, build)
    best[key] = max(best.get(key, 0), val)

md = len(sys.argv) > 2 and sys.argv[2] == 'markdown'
clips = sorted({k[0] for k in best})
rows = []
for clip in clips:
    for mode in ('t1', 'tbgra', 'audio'):
        p, g = best.get((clip, mode, 'plain')), best.get((clip, mode, 'pgo'))
        if not p or not g:
            continue
        unit = 'x real time' if mode == 'audio' else 'fps'
        rows.append((clip, mode, p, g, (g / p - 1) * 100, unit))
if md:
    print('| clip | mode | plain | PGO + ThinLTO | gain |')
    print('|---|---|---|---|---|')
    for c, m, p, g, d, u in rows:
        print(f'| {c} | {m} | {p:.1f} {u} | {g:.1f} {u} | {d:+.1f}% |')
else:
    for c, m, p, g, d, u in rows:
        print(f'{c:34s} {m:6s} plain {p:8.1f}  pgo {g:8.1f} {u:12s} {d:+6.1f}%')
