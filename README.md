# vyges-mockturtle

The **`vyges-emap`** driver — file-level **multi-output technology mapping** (the "enhanced
ABC" capability from Antmicro's
[techmapping work](https://antmicro.com/blog/2026/06/multi-output-techmapping-in-openroad)),
built reproducibly on top of [mockturtle](https://github.com/lsils/mockturtle)'s header-only
`emap` algorithm.

`vyges-emap` reads an **AIGER netlist + genlib** and writes a **mapped Verilog** netlist with
native multi-output cells (adders, compressors) that ABC's single-output mapper can't produce.
It's the standalone tool mockturtle doesn't ship (`emap` is a library algorithm), designed to
run as a **file-level step** in a synthesis / place-and-route flow.

## Distribution — a binary, not a container

mockturtle is a small header-only C++17 library, and the emap step runs **inside the
OpenROAD/flow container anyway** — so this ships a **relocatable x86_64 binary tarball**, not
a standalone image. Drop `bin/vyges-emap` into the OpenROAD/flow container, or run it on an
x86_64 host (glibc ≥ 2.39).

```
vyges-mockturtle-<version>-g<short>-linux-x86_64.tar.gz
  bin/vyges-emap        # relocatable wrapper (sets LD_LIBRARY_PATH)
  libexec/vyges-emap    # the ELF
  lib/                  # non-glibc shared-lib closure (fmt, abseil)
  manifest.json · LICENSE.mockturtle
```

Releases are on the GitHub Releases page; `index.json` maps commit ↔ version ↔ tarball
(`scripts/which.sh latest`).

## Usage

```sh
vyges-emap --aig design.aig --genlib tech.genlib -o design.mapped.v \
           --multioutput --stats stats.json
```

## Cadence — daily sync, on-demand build

mockturtle changes slowly, so we don't nightly-build:
- **`sync.yml`** (daily) checks mockturtle `master` and opens a PR bumping the pin in
  `upstream.yaml` when it moves.
- **`release.yml`** (on demand) builds the pinned commit → tarball → GH Release + `index.json`.

Merge a sync PR to pin, then cut a release with a `version` (e.g. `2026.07.0`).

## Build

`scripts/build.sh` builds `vyges-emap` against pinned mockturtle and assembles the tarball —
on a CI runner or a throwaway `docker run --rm -v "$PWD:/w" -w /w ubuntu:24.04 bash
scripts/build.sh` (env `MT_COMMIT`, `VERSION`). `CMakeLists.txt` links mockturtle's headers +
fmt + abseil.

> **Status:** the `vyges-emap` driver is **compile-validated** on ubuntu:24.04 — reads AIGER +
> genlib, runs emap, writes mapped Verilog + a stats sidecar (~360 KB tarball). Remaining
> follow-ups: reproduce the blog's multi-output area reduction on a datapath design (the
> acceptance target), and preserve module/port names for clean read-back.

## Licensing

Repository tooling is Apache-2.0 (`LICENSE`). The built artifact is a driver we author (MIT)
linked against **mockturtle (MIT, EPFL)** — each tarball ships `LICENSE.mockturtle` +
`manifest.json` (pinned commit). fmt (MIT) and abseil (Apache-2.0) are permissive; all clean
against the Apache-only policy.
