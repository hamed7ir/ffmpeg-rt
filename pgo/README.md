# pgo/ — the profile the ARM32 release is built with

| file | what it is |
|---|---|
| `ffshared-arm32.profdata` | the IR-level PGO profile: execution counts of the counting build on the training clips |
| `arm32-config.sha256` | the configuration that build had (`config.h` + `config_components.h`, normalised); `gate-config.sh arm32 use` refuses a build whose configuration differs |
| `run-ffpgo.cmd` | the training run, as it ran on the Surface RT |

## How it was made (2026-11-16)

1. **Counting build**: `configure.sh arm32 instr` (clang-cl `-fprofile-generate`; FFmpeg's NEON
   `.S` files are plain assembly and are not counted).
2. **Training run** on a Surface RT (Windows RT 8.1, 6.3.9600, Tegra 3), 08:10-08:17, 28 passes,
   no errors. It used `run-ffpgo.cmd`, with each clip decoded four ways for 40 s
   (`-stream_loop -1 -t 40`, null output):
   1. as it is (all threads)
   2. `-threads 1`
   3. `-map 0:v? -pix_fmt bgra` (swscale)
   4. `-map 0:a? -af "aresample=48000,aformat=sample_fmts=s16:channel_layouts=stereo,atempo=1.25"` (swresample, avfilter)
3. **Merge**: `llvm-profdata merge` of the seven `.profraw` files, one per DLL plus ffmpeg.exe.
   That gives 10387 functions, a maximum function count of 272984100 and a total count of
   10368581617.
4. **Release build**: `-fprofile-use` + `-flto=thin` + `-mllvm -pgso=false`, linked by lld-link
   with ThinLTO.

The profile names a static function by its source file. The original merge, sha256
`14b779005fb372efa45dd6ed93ce14d57109a0438df8e1473770491c4df42c0b`, has the build server's
absolute path in those names (`F:/kodi-rt/build/s7/ffmpeg-src/libavcodec/h264_cabac.c;...`).

The file here has that folder cut off (`libavcodec/h264_cabac.c;...`, through
`llvm-profdata merge --text`, a prefix replace, and a merge back). The counts are the same, and
`configure.sh` cuts the clone's own source folder off with
`-mllvm -static-func-strip-dirname-prefix=N`, so it fits any checkout. Measured: two hot H.264
files compiled both ways give identical code. Without a profile, 54,000 lines of their disassembly
differ.

Kodi's own profile (from Kodi RT's PGO run) is not part of this one. Kodi plays H.264 through
DXVA, so that profile has no software H.264.

## The training clips

All free to use. None of them is in this repository.

| file in the kit | source | licence | sha256 |
|---|---|---|---|
| `h264-high_480p_aac_sintel.mp4` | download.blender.org/durian/trailer/sintel_trailer-480p.mp4 | CC BY 3.0, Blender Foundation | `b670602fa00934ca27c4351bb0efe7ea7a07fae57284e44226025eeed7c51254` |
| `h264-high_720p_aac_sintel.mp4` | download.blender.org/durian/trailer/sintel_trailer-720p.mp4 | CC BY 3.0, Blender Foundation | `cb0fe73fc0a7d543459996c0cdab730997e6eac1013d3ede18796f777cb7f273` |
| `h264-high_1080p_aac_sintel.mp4` | download.blender.org/durian/trailer/sintel_trailer-1080p.mp4 | CC BY 3.0, Blender Foundation | `34bbd52a4b89fdf63c8ace50b268da26653a59508288100cd3c23de276db7931` |
| `h264-baseline_270p_aac_bbb.m4v` | download.blender.org/peach/trailer/trailer_iphone.m4v | CC BY 3.0, Blender Foundation | `2e09da35a9093921001a6f0a01fc544ba20a84588c4f9bc9a52b506888478280` |
| `vp9_480p60_opus_bbb.mkv` | 30 s of Wikimedia Commons' `Big_Buck_Bunny_4K.webm.480p.vp9.webm`, cut with `-ss 60 -t 30 -c copy` | CC BY 3.0, Blender Foundation | `75fe3b50c1661b798863da2a77ccef8c312addb67dfc9a1393fd92ac20c7ba78` |
| `opus_speech_detodos.opus` | Firefox's `dom/media/test/detodos.opus` | Firefox media test file | `26199e247067d2a6533c8ffe9c63ef4938959a2cae03eb4ad8d50db0a95961fb` |
| `mp3_320k_gymnopedie2.mp3` | Wikimedia Commons, Gymnopedie No. 2 (Erik Satie) performed by Kevin MacLeod | CC BY 3.0 | `7c26ae829a1a4118315ec9974a2b5a3b12e4f899e1c7e8abb9d2e3cfcc8a96a0` |

## Training a new profile

Needed after any change to the source, the patches, the configure line or the compiler. The
gate tells you: `arm32-config.sha256` stops matching.

```sh
sh scripts/configure.sh arm32 instr && sh scripts/gate-config.sh arm32 instr
sh scripts/build.sh arm32 instr && sh scripts/verify-build.sh arm32 instr
sh scripts/pgo-kit.sh                      # build/pgo-kit: put the clips into its clips/
#   run run-ffpgo.cmd on the Surface RT, bring back its results folder
sh scripts/pgo-merge.sh <results folder>   # writes ffshared-arm32.profdata and arm32-config.sha256
sh scripts/configure.sh arm32 use          # and on, as in the README
```
