#!/usr/bin/env bash
# build.sh — build the `vyges-emap` driver against pinned mockturtle and assemble
# a relocatable **x86_64 binary tarball**. No container is published: the binary
# is meant to be dropped into the OpenROAD/flow container (or run on an x86_64
# host). Runs on ubuntu:24.04 — a CI runner, or a throwaway `docker run
# --rm -v "$PWD:/w" -w /w ubuntu:24.04 bash scripts/build.sh` for local builds.
#
# Env: MT_COMMIT (required), VERSION (default dev), OUT_DIR (default ./dist),
#      SRC (default cwd). Installs cmake/ninja/fmt/abseil via apt if missing.
set -euo pipefail
: "${MT_COMMIT:?set MT_COMMIT}"
VERSION="${VERSION:-dev}"; OUT_DIR="${OUT_DIR:-$(pwd)/dist}"; SRC="${SRC:-$(pwd)}"
SHORT=$(echo "$MT_COMMIT" | cut -c1-12)
NAME="vyges-mockturtle-${VERSION}-g${SHORT}"
WORK=$(mktemp -d); mkdir -p "$OUT_DIR"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# mockturtle bundles its deps (fmt/kitty/lorina/parallel_hashmap) in lib/ — no
# system fmt/abseil needed; just a C++17 toolchain + cmake/ninja.
if ! (command -v cmake >/dev/null && command -v ninja >/dev/null && command -v g++ >/dev/null); then
  if command -v apt-get >/dev/null; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq git cmake ninja-build build-essential
  fi
fi

echo "== clone mockturtle @ $MT_COMMIT =="
git clone -q https://github.com/lsils/mockturtle.git "$WORK/mockturtle"
git -C "$WORK/mockturtle" checkout -q "$MT_COMMIT"
# non-recursive: get lib/* (fmt, kitty, lorina, parallel_hashmap, …) but skip the
# large nested ABC under lib/abcsat (only needed when MOCKTURTLE_ENABLE_ABC=ON).
git -C "$WORK/mockturtle" submodule update --init -q

echo "== build vyges-emap =="
cmake -S "$SRC" -B "$WORK/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DMOCKTURTLE_DIR="$WORK/mockturtle"
cmake --build "$WORK/build"
BIN="$WORK/build/vyges-emap"; test -x "$BIN"

echo "== assemble relocatable bundle: $OUT_DIR/$NAME =="
B="$OUT_DIR/$NAME"; rm -rf "$B"; mkdir -p "$B"/{bin,libexec,lib}
cp "$BIN" "$B/libexec/vyges-emap"
ldd "$B/libexec/vyges-emap" | awk '/=>/{print $3}' | grep -E '^/' \
  | grep -vE '/libc\.so|/libm\.so|/libpthread|/libdl\.so|/librt\.so|/libresolv|ld-linux|/libgcc_s|/libstdc\+\+' \
  | sort -u | xargs -I{} cp -Ln {} "$B/lib/" 2>/dev/null || true
cat > "$B/bin/vyges-emap" <<'WRAP'
#!/bin/sh
HERE=$(cd "$(dirname "$0")/.." && pwd)
export LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/libexec/vyges-emap" "$@"
WRAP
chmod +x "$B/bin/vyges-emap"

printf '{\n  "schema": "vyges-mockturtle-manifest/1.0",\n  "version": "%s",\n  "upstream_commit": "%s",\n  "build_os": "ubuntu:24.04",\n  "artifact": "vyges-emap"\n}\n' "$VERSION" "$MT_COMMIT" > "$B/manifest.json"
for lic in "$WORK/mockturtle/LICENSE" "$WORK/mockturtle/LICENSE.txt"; do
  [ -f "$lic" ] && cp "$lic" "$B/LICENSE.mockturtle" && break
done

echo "== tarball =="
tar -C "$OUT_DIR" -czf "$OUT_DIR/${NAME}-linux-x86_64.tar.gz" "$NAME"
rm -rf "$WORK"
du -sh "$B" "$OUT_DIR/${NAME}-linux-x86_64.tar.gz"
echo "BUILD_OK short=$SHORT name=$NAME"
