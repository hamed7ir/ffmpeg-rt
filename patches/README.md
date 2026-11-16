# patches/

`scripts/fetch-deps.sh` applies these to the FFmpeg 9.0.2 tree, in this order, with
`patch -p1 -N -r -` (or `git apply`), and records the set in `deps/ffmpeg-9.0.2/.ffmpeg-rt-patched`.

## 1. Kodi's Windows patch set (`kodi/`)

Copied unchanged from Kodi, [xbmc/xbmc](https://github.com/xbmc/xbmc) at
`bffa625cc84860f241772d87a654844b98bebb60`, `tools/depends/target/ffmpeg/`. Kodi's Windows build
(`tools/buildsteps/windows/buildhelpers.sh`) applies `*-ffmpeg-windows-*.patch` first, then
`*-ffmpeg-all-*.patch`; so does this repo:

| order | patch | what it does |
|---|---|---|
| 1 | `002-ffmpeg-windows-configure-detect-openssl.patch` | configure: OpenSSL detection with MSVC names |
| 2 | `003-ffmpeg-windows-configure-fix-zlib-conflict.patch` | config.h: undefine HAVE_UNISTD_H when it is 0 |
| 3 | `004-ffmpeg-windows-configure-allow-building-static.patch` | configure: static libraries with MSVC |
| 4 | `005-ffmpeg-windows-configure-detect-libdav1d.patch` | configure: finds `libdav1d.lib` |
| 5 | `006-ffmpeg-windows-dxva2-check-nullptr-surface.patch` | dxva2: checks for a null surface |
| 6 | `007-ffmpeg-windows-configure-detect-zlib.patch` | configure: finds `z.lib` |
| 7 | `001-ffmpeg-all-libpostproc-plugin.patch` | puts libpostproc back into the tree (not built here: it is GPL) |
| 8 | `008-ffmpeg-all-pgssubdec-use-caller-colorspace.patch` | PGS subtitles: the caller's colour space |

Kodi's `002-ffmpeg-libavutil-common-h-cpp11-constant-macros.patch` matches neither pattern, so
Kodi's Windows build does not apply it, and neither does this repo.

## 2. ffmpeg-rt's own

| patch | what it does |
|---|---|
| `0001-arm-hevc-10bit-mc-neon.patch` | NEON for 10-bit HEVC motion compensation on 32-bit ARM: `libavcodec/arm/hevcdsp_mc10_neon.c`, qpel (8-tap) and epel (4-tap), pixels/h/v/hv, plain/uni/bi, widths 4-64 (160 functions). FFmpeg's checkasm passes all 1300 tests on a Surface RT. x265 720p 10-bit decodes 20% faster with the loop filter skipped, 12% with it on. |

Patch count: **9** (8 from Kodi, 1 from this repo).
