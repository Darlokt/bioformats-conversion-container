#!/bin/bash
# Smoke tests, run inside the image.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok   $*"; }

# Nextflow task requirements
[ -x /bin/bash ] || fail "/bin/bash missing"
for cmd in bash ps awk date grep sed tail tee java bioformats2raw raw2ometiff; do
  command -v "$cmd" >/dev/null || fail "$cmd not on PATH"
done
pass "required executables present"

cat /opt/VERSIONS
java -version 2>&1 | head -1

# --version exits 255 upstream, so check the output instead of the exit code
bf=$(sed -n 's/^bioformats=//p' /opt/VERSIONS)
for tool in bioformats2raw raw2ometiff; do
  out=$($tool --version 2>&1 || true)
  grep -qF "Bio-Formats version = $bf" <<<"$out" || { echo "$out"; fail "$tool not using local Bio-Formats $bf"; }
done
pass "--version"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

# Synthetic input via Bio-Formats' fake reader (no test data needed)
fake="smoke&sizeX=256&sizeY=256&sizeZ=3&sizeC=2&sizeT=2&pixelType=uint16.fake"
touch "$fake"

# Default compression is blosc -> exercises the native library
bioformats2raw "$fake" out.zarr --resolutions 2 >log.txt 2>&1 || { cat log.txt; fail "bioformats2raw (blosc)"; }
[ -f out.zarr/zarr.json ] || [ -f out.zarr/.zattrs ] || fail "no Zarr metadata written"
pass "bioformats2raw fake -> zarr (blosc)"

raw2ometiff out.zarr out.ome.tiff >log.txt 2>&1 || { cat log.txt; fail "raw2ometiff"; }
[ -s out.ome.tiff ] || fail "empty OME-TIFF"
pass "raw2ometiff zarr -> ome.tiff ($(stat -c %s out.ome.tiff) bytes)"

echo "All smoke tests passed."
