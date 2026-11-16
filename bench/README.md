# bench/ — what PGO + ThinLTO gives on the Surface RT

`run-ffbench.cmd` runs two ARM32 builds of the same FFmpeg on the same clips. They have the same
source, components and compiler; one is plain (`configure.sh arm32 plain`), one is the release
build (`arm32 use`). Per clip, the builds take turns (plain, PGO, plain, PGO, plain, PGO), so heat
throttling hits both alike:

- `t1`: 10 s of video on one thread, no conversion (`-threads 1 -t 10 -map 0:v? -f null -`)
- `tbgra`: 10 s of video on all threads, converted to BGRA (`-t 10 -map 0:v? -pix_fmt bgra -f null -`)
- `audio`: the whole audio track (`-map 0:a? -vn -f null -`)

`bench-parse.py <results\log.txt> [markdown]` takes the best of three per build from ffmpeg's
`-benchmark` real time: frames per second for video, times real time for audio.

To run it, make a folder with `ffmpeg-plain\` (the contents of `dist/arm32-plain/bin`),
`ffmpeg-pgo\` (`dist/arm32-use/bin`), `clips\` (pgo/README.md lists the release's set; every file
there is used) and `run-ffbench.cmd`. Copy it to the device and double-click `run-ffbench.cmd`.

## The release's run

A Surface RT (Windows RT 8.1, 6.3.9600, Tegra 3), 2026-11-16 08:38-08:45, 126 runs, no errors:

| clip | mode | plain | PGO + ThinLTO | gain |
|---|---|---|---|---|
| H.264 Constrained Baseline 480x270 (Big Buck Bunny trailer) | t1 | 300.5 fps | 319.7 fps | +6.4% |
| | tbgra | 347.2 fps | 355.6 fps | +2.4% |
| | audio (AAC) | 94.6x | 98.6x | +4.2% |
| H.264 High 854x480 (Sintel trailer) | t1 | 77.4 fps | 80.3 fps | +3.8% |
| | tbgra | 104.1 fps | 106.0 fps | +1.8% |
| | audio (AAC) | 95.1x | 99.3x | +4.4% |
| H.264 High 1280x720 (Sintel trailer) | t1 | 35.1 fps | 36.5 fps | +4.1% |
| | tbgra | 47.7 fps | 48.1 fps | +0.7% |
| | audio (AAC) | 95.5x | 97.4x | +2.1% |
| H.264 High 1920x1080 (Sintel trailer) | t1 | 15.4 fps | 16.0 fps | +3.6% |
| | tbgra | 20.5 fps | 20.5 fps | +0.1% |
| | audio (AAC) | 92.6x | 98.2x | +6.0% |
| VP9 854x480 60 fps (Big Buck Bunny) | t1 | 120.6 fps | 119.8 fps | -0.7% |
| | tbgra | 112.5 fps | 113.8 fps | +1.1% |
| | audio (Opus 5.1) | 14.6x | 14.9x | +2.3% |
| MP3 320 kb/s | audio | 58.6x | 59.1x | +0.9% |
| Opus speech, 2.9 s | audio | 69.3x | 72.8x | too short to count |

- On one thread, H.264 and AAC gain 2-6%, and every PGO run there beat every plain run.
- With threads + BGRA, three of the four H.264 clips are within run-to-run noise.
- VP9 spends most of its time in hand-written NEON assembly, which PGO does not touch. On one
  thread it is 0.7% slower: small, but every PGO run was slower.
