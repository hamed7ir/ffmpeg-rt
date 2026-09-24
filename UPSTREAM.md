# UPSTREAM — what this repository builds, and whose work it is

`ffmpeg-rt` is **build infrastructure for FFmpeg**. It is not a fork of FFmpeg and it contains
no FFmpeg source. [`scripts/fetch-deps.sh`](scripts/fetch-deps.sh) downloads the upstream
release, **verifies its sha256 against the pin recorded below, and refuses to continue on a
mismatch**; the build then runs against that unmodified tree.

## The component

| | |
|---|---|
| **component** | **FFmpeg** |
| **upstream** | the FFmpeg project — <https://ffmpeg.org> · source at <https://git.ffmpeg.org/ffmpeg.git> |
| **version** | **8.1.2** |
| **pinned by** | tarball sha256 |
| **fetch URL** | `https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz` |
| **sha256** | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` |
| **licence** | **LGPL-2.1-or-later** (`--enable-gpl` and `--enable-nonfree` are both absent from the configure line) |
| **linkage** | built as five shared libraries; a recipient can replace any of them |
| **patches from this repository** | **0** |

**Patch count for this repository: 0.** `patches/` is empty, and it is empty because nothing
needed patching — not because anything was applied in place. All **74** of FFmpeg's ARM
assembly files assemble as they ship, zero failures, once the assembler is clang's integrated
one rather than MSVC's `armasm.exe`. **45 of the 74 resulting objects contain NEON
instructions**; the others are ARM assembly without it. Both figures come from disassembling
every object, not from a configure summary.

That version is the same one scrcpy v4.1 pins in its own `app/deps/ffmpeg.sh`, so `ffmpeg-rt`
and `scrcpy-rt` agree on it by construction.

## How the pin is verified

`scripts/fetch-deps.sh` hashes the downloaded tarball and compares it to `FFMPEG_SHA` above. It
also **self-tests the hash checker before trusting it** — it hashes a known vector, confirms the
answer, then confirms a one-byte change produces a different answer, and exits 2 if either
check fails. A verifier that cannot fail is not a verifier, so the script proves it can say no
before it is allowed to say yes.

## What in this repository is not upstream's

Everything outside `deps/`: `scripts/`, `cross/`, `config.sh`, the compiler wrappers and the
response-file templates. All of it was written for this port, it contains no code copied from
FFmpeg or anywhere else, and it is offered under the **same LGPL-2.1-or-later** so a recipient
has one licence to reason about rather than two.

See [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) for the licence obligations and
[`LICENSE`](LICENSE) for FFmpeg's own licence text, reproduced verbatim.

## Toolchain — used, not redistributed

**rt2** — **LLVM 23.1.1 plus a small set of patches** this target still needs upstream, built
as its own project and published at **<https://github.com/hamed7ir/llvm-rt1>**. Base: `llvmorg-23.1.1`, whose source tarball
sha256 `ebe9be46fe8756d58c5b198ffad0fa2a766257add81a4dc52179bfacc7888ee6` was verified before
that build. Licence: **Apache-2.0 WITH LLVM-exception**, and because it is a *modified* LLVM,
its own repository is where the modified source lives — not here.

The binaries these repos were built with are identified by sha256 in `config.sh`, not by version
string alone, because an unrelated LLVM 18.1.8 lives one character away on the original build
machine and would build everything silently and wrongly.

MSVC toolset 14.44.35207 and Windows SDK 10.0.19041.0: Microsoft, under their own terms.
**Nothing in this paragraph is redistributed here.**
