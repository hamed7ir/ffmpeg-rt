# UPSTREAM — what this repository builds, and whose work it is

`ffmpeg-rt` is **build infrastructure for FFmpeg**. It is not a fork of FFmpeg and it contains
no FFmpeg source. [`scripts/fetch-deps.sh`](scripts/fetch-deps.sh) downloads the upstream
releases, **verifies each sha256 against the pins recorded below, and refuses to continue on a
mismatch**. It then applies the patches in [`patches/`](patches/) to the FFmpeg tree, and the build
runs against that.

## The components

| component | version | pinned by | licence | in the build |
|---|---|---|---|---|
| **FFmpeg** | **9.0.2** | sha256 `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e` | LGPL-2.1-or-later | six shared libraries; a recipient can replace any of them |
| dav1d | 1.5.3 | sha256 `e099f53253f6c247580c554d53a13f1040638f2066edc3c740e4c2f15174ce22` | BSD-2-Clause | static, inside `avcodec` |
| zlib | 1.3.2 | sha256 `d7a0654783a4da529d1bb793b7ad9c3318020af77667bcae35f95d0e42a792f3` | zlib | static, inside `avformat` |
| nasm | 2.15.05 | sha256 `3caf6729c1073bf96629b57cee31eeb54f4f8129b01902c73428836550b30a3f` | BSD-2-Clause | build tool only (x86 SIMD) |

- **Upstreams**: the FFmpeg project, <https://ffmpeg.org> (source at <https://git.ffmpeg.org/ffmpeg.git>);
  VideoLAN, <https://code.videolan.org/videolan/dav1d>; <https://zlib.net>; <https://nasm.us>.
- **Fetch URL**: `https://mirrors.kodi.tv/build-deps/sources/<archive>` for all four, the mirror
  Kodi's own build uses. Each tarball's sha512 also matches Kodi's pin file at xbmc/xbmc
  `bffa625c` (`tools/depends/target/ffmpeg/FFMPEG-VERSION` and its neighbours).
- **Versions**: FFmpeg, dav1d, zlib and nasm are the versions Kodi master pins, so ffmpeg-rt and
  Kodi RT build the same FFmpeg.

**Patches: 9**, all in [`patches/`](patches/) and listed in
[`patches/README.md`](patches/README.md).
- **8 from Kodi**, copied unchanged from xbmc/xbmc `tools/depends/target/ffmpeg/`. They are applied
  in the order Kodi's Windows build applies them, and are mostly configure fixes for MSVC-style
  builds.
- **1 from this repository**: `0001-arm-hevc-10bit-mc-neon.patch`, NEON for 10-bit HEVC motion
  compensation on 32-bit ARM.

The patched tree is byte-identical to the one the release was built from (checked with `diff -r`).

## Tested from a clean copy

On 2026-11-16, a copy of this repository at another path on the build server (Windows Server 2022,
MSYS2) ran every script:
- `fetch-deps.sh` gave the release's source tree, with GNU patch and with `git apply`.
- All four variants (`arm32 use`, `arm32 plain`, `arm32 instr`, `x86 plain`) passed `gate-config.sh`
  and `verify-build.sh`.
- The probe built against both installs; the x86 one decoded a 480p H.264 clip.
- `package.sh` made both zips.

Compared with the release builds:
- `arm32 plain` and `x86 plain` have the same code size (`.text`) in all six DLLs, to the byte.
- `arm32 use` has it in four of six. avcodec is 0.17% smaller and avutil 8 bytes smaller.

The release zips themselves hold the binaries that were measured on the device.

## How the pins are verified

`scripts/fetch-deps.sh` hashes each tarball and compares it to the pin. It also **self-tests the
hash checker before trusting it**: it hashes a known vector and confirms the answer, then confirms
that a one-byte change gives a different answer. It exits 2 if either check fails. A verifier
that cannot fail is not a verifier, so the script proves it can say no before it is allowed to
say yes. The patch set is recorded with each patch's sha256 in `deps/ffmpeg-9.0.2/.ffmpeg-rt-patched`.

## What in this repository is not upstream's

- **Written for this port**: everything outside `deps/` and `patches/kodi/`. That is `scripts/`,
  `cross/`, `config.sh`, `pgo/`, `bench/`, `probe/` and `patches/0001-*`. It contains no code
  copied from FFmpeg or anywhere else. It is offered under the **same LGPL-2.1-or-later**, so a
  recipient has one licence to reason about rather than two.
- **Kodi's**: `patches/kodi/`. Each patch names its author.
- **The PGO profile** `pgo/ffshared-arm32.profdata` is data: execution counts of this FFmpeg build
  on the training clips listed in [`pgo/README.md`](pgo/README.md). It contains no source code.

See [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) for the licence obligations and
[`LICENSE`](LICENSE) for FFmpeg's own licence text, reproduced verbatim.

## Toolchain — used, not redistributed

**rt2.4**: LLVM 23.1.1 plus the patches this target still needs upstream, built as its own project
(<https://github.com/hamed7ir/llvm-rt1> is where rt2 lives). Licence: **Apache-2.0 WITH
LLVM-exception**, and because it is a *modified* LLVM, its own repository is where the modified
source lives — not here.

The binaries the release was built with are identified by sha256 in `config.sh`, not by version
string alone. The version string is "Varan clang version 23.1.1-rt2.4
(f6e5f8e02a8c69d0479b5623215b8a8b8fcd2e01)".

Also used: MSVC toolset 14.44.35207 and the Windows SDK (headers 10.0.26100.0, ARM32 libraries
10.0.19041.0). They are Microsoft's, under their own terms.

**Nothing in this section is redistributed here.**
