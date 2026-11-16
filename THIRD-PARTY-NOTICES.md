# THIRD-PARTY NOTICES — ffmpeg-rt

`ffmpeg-rt` is build infrastructure. It **vendors no third-party source**: nothing under `deps/`
is committed here. `scripts/fetch-deps.sh` reconstructs it from pinned, public tarballs, and
refuses to continue if a sha256 does not match. The one third-party material committed here is
`patches/kodi/`, eight patch files from Kodi.

## Components

| component | version | licence | where |
|---|---|---|---|
| FFmpeg | **9.0.2** | **LGPL-2.1-or-later** | `deps/ffmpeg-9.0.2`, fetched; six shared DLLs |
| dav1d | 1.5.3 | BSD-2-Clause | `deps/dav1d-1.5.3`, fetched; static, inside `avcodec-63.dll` |
| zlib | 1.3.2 | zlib | `deps/zlib-1.3.2`, fetched; static, inside `avformat-63.dll` |
| nasm | 2.15.05 | BSD-2-Clause | `deps/nasm-2.15.05`, fetched; a build tool, nothing of it is in the DLLs |
| Kodi's FFmpeg patches | xbmc/xbmc `bffa625c` | Kodi's repository is GPL-2.0-or-later; the patches change FFmpeg's own files and each names its author | `patches/kodi/`, 8 files |

The release zips carry FFmpeg's `LICENSE.md` and `COPYING.LGPLv2.1`, dav1d's `COPYING` and zlib's
`LICENSE` in `licenses/`. FFmpeg's licence text is also reproduced at [`LICENSE`](LICENSE).

## Why this build is LGPL and not GPL — a deliberate choice, not an accident

FFmpeg can be configured either way. This one is configured to stay under the LGPL:

- **`--enable-gpl` is absent** from `scripts/configure.sh`, and so is `--enable-nonfree`. Both are
  checkable in one command: `grep -c 'enable-gpl\|enable-nonfree' scripts/configure.sh` returns
  **0**. `scripts/gate-config.sh` also checks `CONFIG_GPL 0` and `CONFIG_NONFREE 0` in `config.h`
  before every build.
- Kodi's patch `001-ffmpeg-all-libpostproc-plugin.patch` puts libpostproc (GPL) back into the
  source tree. It is **not built**: libpostproc needs `--enable-gpl`.
- The libraries are built **`--enable-shared --disable-static`**, so a recipient can replace any
  of the six DLLs with their own build of the same FFmpeg version.
- The **complete configure line is published**: it is `scripts/configure.sh`, not a paraphrase of
  it. `scripts/fetch-deps.sh` pins the exact source and `patches/` holds every patch it applies.

Between them those facts are what the LGPL asks of a distributor of linked binaries: the source,
the means to rebuild it, and the ability to relink.

One consequence worth stating plainly. The DLLs are built with the **static CRT (`/MT`)**, so each
carries its own C runtime, hence its own heap and its own `FILE*` table. FFmpeg routes its
allocation through `av_malloc`/`av_free` in `avutil`, so FFmpeg's own objects are safe across the
boundary. A consumer **must not** free an FFmpeg-allocated pointer with its own `free()`.

## Files added by this project

Everything outside `deps/` and `patches/kodi/` was written for this port: `scripts/`, `cross/`,
`config.sh`, `pgo/`, `bench/`, `probe/` and `patches/0001-*`. It contains no code copied from
FFmpeg or anywhere else; it is build glue, plus one FFmpeg patch. It is offered under the **same
LGPL-2.1-or-later** as the project it serves.

## Toolchain — used, not redistributed

| | |
|---|---|
| **rt2.4**, LLVM 23.1.1-rt2.4 | Apache-2.0 WITH LLVM-exception |
| MSVC toolset 14.44.35207, Windows SDK 10.0.26100.0 and 10.0.19041.0 | Microsoft, used under their own terms |

Neither is redistributed by this repository.

## Test clips — not redistributed

The PGO profile and the bench numbers come from seven freely licensed clips: Blender Foundation's
Sintel and Big Buck Bunny (CC BY 3.0), an Opus sample from Firefox's media tests, and an MP3 by
Kevin MacLeod (CC BY 3.0). [`pgo/README.md`](pgo/README.md) lists where each comes from. None of
them is in this repository or in a release.
