# THIRD-PARTY NOTICES — ffmpeg-rt

`ffmpeg-rt` is build infrastructure. It **vendors no third-party source**: nothing under
`deps/` is committed here. `scripts/fetch-deps.sh` reconstructs it from one pinned, public
tarball, and refuses to continue if the sha256 does not match.

## Components

| component | version / pin | licence | where |
|---|---|---|---|
| FFmpeg | **8.1.2**, sha256 `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | **LGPL-2.1-or-later** | `deps/ffmpeg-8.1.2`, fetched |

That is the whole list. **Source patches to FFmpeg: zero** — `patches/` is empty, and it is
empty because nothing needed patching, not because anything was applied in place.

FFmpeg's own licence text is reproduced at [`LICENSE`](LICENSE) (its `COPYING.LGPLv2.1`,
verbatim). The fetched tree carries its own `LICENSE.md` naming the copyright holders.

## Why this build is LGPL and not GPL — a deliberate choice, not an accident

FFmpeg can be configured either way. This one is configured to stay under the LGPL:

- **`--enable-gpl` is absent** from `scripts/configure-arm32.sh`. So is `--enable-nonfree`.
  Both are checkable in one command: `grep -c 'enable-gpl\|enable-nonfree' scripts/configure-arm32.sh`
  returns **0**.
- The libraries are built **`--enable-shared --disable-static`**, so a recipient can replace
  any of the five DLLs with their own build of the same FFmpeg version.
- The **complete configure line is published** — it is `scripts/configure-arm32.sh`, not a
  paraphrase of it — and `scripts/fetch-deps.sh` pins the exact source it applies to.

Between them those three facts are what the LGPL asks of a distributor of linked binaries:
the source, the means to rebuild it, and the ability to relink.

⚠ One consequence worth stating plainly. The DLLs are built with the **static CRT (`/MT`)**,
so each carries its own C runtime, hence its own heap and its own `FILE*` table. FFmpeg routes
its allocation through `av_malloc`/`av_free` in `avutil`, so FFmpeg's own objects are safe
across the boundary — but a consumer **must not** free an FFmpeg-allocated pointer with its own
`free()`.

## Files added by this project

Everything outside `deps/` — `scripts/`, `cross/`, `config.sh`, the wrappers and response-file
templates — was written for this port. It contains no code copied from FFmpeg or anywhere else;
it is build glue. It is offered under the **same LGPL-2.1-or-later** as the project it serves,
so a recipient has one licence to reason about rather than two.

## Toolchain — used, not redistributed

| | |
|---|---|
| **rt2** — LLVM 23.1.1-rt2 | Apache-2.0 WITH LLVM-exception |
| MSVC toolset 14.44.35207, Windows SDK 10.0.19041.0 | Microsoft, used under their own terms |

Neither is redistributed by this repository.

## Reference binaries deliberately NOT redistributed

A 2013 third-party ARM32 FFmpeg 2.1 build (`ffmpeg2.1_ARM.zip`, from
`files.open-rt.party/Software/`) was used during this port as an instrument — to establish that
a Tegra 3 can decode H.264 at all. Its licence and provenance are unknown, so it is **not**
included in this repository and not in any release from it.
