# ffmpeg-rt

> **Upstream: [FFmpeg](https://ffmpeg.org), release `9.0.2`, the version Kodi master pins. Patches
> applied here: 9** (8 from Kodi's Windows build, 1 from this repo). Build infrastructure only; no
> upstream source is included. `scripts/fetch-deps.sh` verifies every tarball's sha256. See
> [`UPSTREAM.md`](UPSTREAM.md).

FFmpeg 9.0.2 as shared DLLs for 32-bit ARM Windows (`armv7-pc-windows-msvc`), which run on
**Windows RT 8.1**, and for desktop Windows x86. It is the FFmpeg of
[Kodi RT](https://github.com/hamed7ir/kodi-rt): the same source, patches and compiler. The ARM32
build is compiled with PGO and ThinLTO, from a profile trained on a Surface RT.

Measured on a Surface RT (Tegra 3, Windows RT 8.1), against the same build without PGO and ThinLTO
([`bench/`](bench/)):
- H.264 on one thread: +3.6 to +6.4%
- AAC: +2 to +6%
- H.264 on all threads with BGRA conversion: 0 to +2.4%
- VP9: -0.7 to +1.1%

Patch 0001 (NEON for 10-bit HEVC motion compensation) makes 10-bit HEVC (x265 720p) decode 20%
faster with the loop filter skipped and 12% with it on.

## Release contents

`ffmpeg-9.0.2-rt-arm32.zip` (PGO + ThinLTO) and `ffmpeg-9.0.2-rt-x86.zip`:
- `bin/`: `avcodec-63.dll`, `avformat-63.dll`, `avutil-61.dll`, `avfilter-12.dll`, `swscale-10.dll`,
  `swresample-7.dll` with their PDBs, plus `ffmpeg.exe` as a test tool.
- `lib/`: import libraries and `.def` files.
- `include/`: the headers.
- `checks/`: the Windows RT 8.1 checks (dumpbin `/headers /imports` of every file).
- `licenses/`: FFmpeg's, dav1d's and zlib's licence texts.

Each DLL imports only Windows system DLLs (KERNEL32, USER32, bcrypt, ole32) and the other FFmpeg
DLLs. The CRT is static: there is no UCRT or VC runtime dependency. OS and subsystem version are 6.0.

## Enabled

- Decoders:
  - video: h264, hevc, av1, vp8, vp9, mpeg4, h263
  - audio: opus, aac, flac, mp3, mp3float, vorbis, alac
  - PCM: s16le/be, s24le/be, s32le, f32le, f64le, u8, alaw, mulaw
  - `libdav1d`, for software AV1 (FFmpeg's own `av1` decoder needs a hardware accelerator)
- All demuxers, parsers and bitstream filters, and all non-network protocols, except those that
  need an external library or the network.
- Muxers: mp4, mov, matroska, null.
- avfilter: atempo, aformat, aresample, format, scale, null, anull. abuffer/buffer/abuffersink/buffersink
  are always built.
- swscale, swresample, DXVA2 (h264_dxva2).
- zlib 1.3.2 (in avformat) and dav1d 1.5.3 (in avcodec), linked statically.
- No avdevice, no network.

## Limitations

- Not built:
  - the dash and imf demuxers (they need libxml2)
  - rtp/rtsp/sap/sdp and the network protocols
  - the ahx parser and bsf (FFmpeg 9 builds them only with `--enable-gpl`)
  - decoders not listed above
- The x86 build has no PGO: the profile is ARM code.
- Each DLL has its own static CRT, so free FFmpeg allocations with `av_free`, not `free`.

## Build

Set these in [`config.sh`](config.sh) or export them. `RT2`, `VCTOOLS`, `WINSDK` and `WINSDKVER` are
the same names as in the other `-rt` repos.

| variable | value |
|---|---|
| `RT2` | LLVM 23.1.1-rt2.4 `bin` directory (the release: build f6e5f8e0) |
| `VCTOOLS` | MSVC 14.44.35207 (14.51 dropped ARM32) |
| `WINSDK`, `WINSDKVER` | Windows SDK; ARM32 libraries from 10.0.19041.0 (the last with them) |
| `WINSDKINCVER` | SDK headers, and the x86 libraries: 10.0.26100.0 |
| `CMAKE`, `NINJA` | zlib (VS 2022 Build Tools' own) |
| `MESON` | dav1d (`pip install meson`; 1.9.1 built the release) |
| `PYTHON` | the DLL checks and the zips |
| `MSYS2` | MSYS2 install, with `pacman -S make diffutils patch` |

From an MSYS2 shell:

```sh
sh scripts/fetch-deps.sh             # FFmpeg, dav1d, zlib, nasm; applies patches/
sh scripts/gen-rsp.sh                # expands cross/*.in against config.sh
sh scripts/build-nasm.sh             # x86 only
sh scripts/build-deps.sh arm32       # zlib + dav1d; and: x86
sh scripts/configure.sh arm32 use    # or: arm32 plain, arm32 instr, x86 plain
sh scripts/gate-config.sh arm32 use
sh scripts/build.sh arm32 use
sh scripts/verify-build.sh arm32 use
sh scripts/package.sh                # the zips, from arm32 use and x86 plain
```

`gate-config.sh` checks `config.h` and must pass before `build.sh`. For `arm32 use` it also checks
that the configuration is the one the profile was trained on. Absolute build paths are embedded
in `avutil` through FFmpeg's configure line. [`pgo/`](pgo/) says how the profile was made and how
to train a new one.

## Licence

**Copyright (c) 2026 hamed7ir** for the files this repository adds, under LGPL-2.1-or-later —
[`LICENSE`](LICENSE).

FFmpeg is LGPL-2.1-or-later. `--enable-gpl` and `--enable-nonfree` are not used, and the
libraries are shared. dav1d is BSD-2-Clause, zlib under the zlib licence. See
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

## Related

- [`UPSTREAM.md`](UPSTREAM.md): the components, their pins, licences and patch count
- [Kodi RT](https://github.com/hamed7ir/kodi-rt), `adb-rt` and `scrcpy-rt`
- [rt2](https://github.com/hamed7ir/llvm-rt1): the toolchain
