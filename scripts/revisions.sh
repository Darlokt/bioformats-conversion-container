#!/bin/sh
# Print the source revisions as KEY=VALUE lines (Dockerfile build args).
# Used by scripts/build.sh and by CI (as a dotenv report). POSIX sh: runs in alpine/git.
set -eu
cd "$(dirname "$0")/.."

# "<commit> (<describe>)", with -dirty if there are uncommitted changes
rev() {
  git -C "$1" rev-parse -q --verify HEAD >/dev/null || { echo "no-commit"; return; }
  echo "$(git -C "$1" rev-parse HEAD) ($(git -C "$1" describe --tags --always --dirty))"
}

echo "BUILD_REVISION=$(rev .)"
echo "BIOFORMATS_REVISION=$(rev dependencies/bioformats)"
echo "BIOFORMATS2RAW_REVISION=$(rev dependencies/bioformats2raw)"
echo "RAW2OMETIFF_REVISION=$(rev dependencies/raw2ometiff)"
