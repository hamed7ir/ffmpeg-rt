# `cross/` — the toolchain plumbing

Everything FFmpeg's `configure` needs in order to drive clang-cl at a 32-bit ARM Windows
target. No path is hardcoded here: every wrapper derives the repo root from its own location
and sources [`config.sh`](../config.sh).

## Build host

**MSYS2, MSYS environment.** `pacman -S make diffutils` — a fresh install ships neither.

WSL2 was tried first and **abandoned**. It was never preferred; it was simply the only shell on
the original box with `make` before MSYS2 existed. It failed on three separate path blockers,
all the same root cause: **FFmpeg's build system assumes the shell and the compiler share one
path namespace.** MSYS2 makes that true; WSL does not. The `*.wsl.sh` wrappers are kept as a
record of that attempt and are **not part of any supported build**.

## Files

| file | used by | notes |
|---|---|---|
| `cc-arm32.sh` | `--cc`, `--cxx` | clang-cl, ARM32, `-MT` static CRT |
| `as-arm32.sh` | `--as` | **clang's GCC driver — the flag that buys NEON** |
| `hostcc-x64.sh` | `--host-cc` | x64 host tools |
| `windres-arm32.sh` | `--windres` | `llvm-windres` with an explicit `--target=arm` |
| `arm32-msvc.rsp.in` | `cc-arm32.sh` | target + MSVC sysroot |
| `arm32-link.rsp.in` | `--extra-ldflags` | `-machine:arm` + the ARM library paths |
| `x64-msvc.rsp.in`, `x64-link.rsp.in` | host | the same, for x64 |
| `target-arm32.rsp` | anything that needs only the triple | one line, no paths |
| `bin/lib.exe` | FFmpeg's `makedef` | a **shell script**, not Microsoft's tool — see below |

The `.rsp.in` files are templates. `sh scripts/gen-rsp.sh` expands `@VCTOOLS@`, `@WINSDK@`,
`@WINSDKVER@`, `@RT2@` and `@ROOT@` from `config.sh` into the real `.rsp` files, which are
generated and therefore not tracked.

## Three traps these files exist to avoid

1. **clang-cl auto-detects MSVC, and its choice beats `-imsvc`.** On the original box it picks
   **14.51**, which hard-`#error`s on ARM32. Only `-vctoolsdir` / `-winsdkdir` /
   `-winsdkversion` pin it. Verified both ways: without the rsp the same compile fails on
   `vadefs.h(15)`; with it, `/showIncludes` reports `14.44.35207` and `10.0.19041.0`.
2. **`--extra-cflags` is passed to the ASSEMBLER too** (`configure:5509`). The MSVC sysroot
   flags are clang-cl-only and the clang GCC driver rejects them outright, so they live in the
   CC wrapper and never in `--extra-cflags`. `-MT` likewise: the GCC driver reads a bare `-MT`
   as "dependency target name" and eats the next argument.
3. **LLVM response files do NOT support `#` comments.** Every comment word becomes an argument.
   It can even appear to pass, because stray words are silently swallowed as "unused linker
   input". Keep the `.rsp` files comment-free and document here instead.

## Why `--as=` is the whole point

`--toolchain=msvc` sets `as_default=armasm.exe` for `arm*`. Measured: `armasm.exe` on FFmpeg's
GAS-syntax `.S` files emits `error A2230` from line 1, writes a **0-byte object, and still
exits 0**. That is why the 2013 MSVC ARM32 build has no ARM assembly at all. Pointing `--as=`
at rt2's clang driver, which has an integrated assembler that reads GAS syntax, removes that
wall — 74/74 ARM `.S` files then assemble, and 45 of the resulting objects carry NEON.

## `bin/lib.exe` is ours, not Microsoft's

A 720-byte POSIX shell script. FFmpeg's `compat/windows/makedef` falls back to a hardcoded
`lib.exe` when `$AR` is unset, so a file by that name must be on `PATH` — this one forwards to
`llvm-lib`. It is the one `.exe` this repository tracks, and `.gitignore` carries an explicit
exception for it.
