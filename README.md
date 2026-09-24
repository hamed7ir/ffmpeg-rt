# ffmpeg-rt

> **Upstream: [FFmpeg](https://ffmpeg.org), release `8.1.2`. Patches applied here: 0.**
> Build infrastructure only; no upstream source is included. `scripts/fetch-deps.sh` verifies the
> tarball's sha256. See [`UPSTREAM.md`](UPSTREAM.md).

FFmpeg 8.1.2 for 32-bit ARM Windows (`armv7-pc-windows-msvc`). It runs on **Windows RT 8.1**.

74/74 ARM assembly files assemble; 45 of the resulting objects contain NEON. H.264 decodes at
944 fps (360p) and 533 fps (480p) on a Surface 2 (Tegra 4) with NEON active. Used by
`scrcpy-rt` on a Surface RT (Tegra 3).

## Release contents

`avcodec-62.dll`, `avformat-62.dll`, `avutil-60.dll`, `swresample-6.dll`, `swscale-9.dll`, with
import libraries and headers. ARM32, no UCRT dependency.

## Enabled

- Decoders: h264, hevc, av1, vp8, vp9, opus, aac, flac, pcm_s16le
- All demuxers, parsers and bitstream filters; all non-network protocols
- Muxers: mp4, matroska
- DXVA2. No avfilter, avdevice or network.

## Limitations

- No PNG decoder (it needs zlib).
- swscale's `rgb2yuv` NEON path is absent.
- Each DLL has its own static CRT: free FFmpeg allocations with `av_free`, not `free`.

## Build

Set these in [`config.sh`](config.sh) or export them. The same names work in all three `-rt` repos.

| variable | value |
|---|---|
| `RT2` | LLVM 23.1.1-rt2 `bin` directory |
| `VCTOOLS` | MSVC 14.44.35207 (14.51 dropped ARM32) |
| `WINSDK`, `WINSDKVER` | Windows SDK 10.0.19041.0 (the last with ARM32 libraries) |
| `MSYS2` | MSYS2 install, with `pacman -S make diffutils` |

From an MSYS2 shell:

```sh
sh scripts/fetch-deps.sh
sh scripts/gen-rsp.sh
sh scripts/configure-arm32.sh
sh scripts/gate-config.sh
sh scripts/build.sh
sh scripts/verify-build.sh
```

`gate-config.sh` checks `config.h` and must pass before `build.sh`. Absolute build paths are
embedded in `avutil` through FFmpeg's configure line.

## Licence

**Copyright (c) 2026 hamed7ir** for the files this repository adds, under LGPL-2.1-or-later —
[`LICENSE`](LICENSE).

FFmpeg is LGPL-2.1-or-later. `--enable-gpl` and `--enable-nonfree` are not used, and the
libraries are shared. See [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

## Related

- [`UPSTREAM.md`](UPSTREAM.md) — the component, its pin, licence and patch count
- `adb-rt` and `scrcpy-rt`
- [rt2](https://github.com/hamed7ir/llvm-rt1) — the toolchain
