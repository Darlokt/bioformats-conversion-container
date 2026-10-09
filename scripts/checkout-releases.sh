#!/bin/sh
# Check out every submodule at its newest upstream release tag (vX.Y.Z, no -rc).
# Used by CI for the stable images. Changes the submodule checkouts.
# POSIX sh: runs in the BuildKit image.
set -eu
cd "$(dirname "$0")/.."

git config -f .gitmodules --get-regexp '\.path$' | while read -r _ dir; do
  tag=$(git -C "$dir" ls-remote --tags --refs origin 'v*' | sed 's#.*refs/tags/##' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
  [ -n "$tag" ] || { echo "no release tag found for $dir" >&2; exit 1; }
  echo "$dir -> $tag"
  git -C "$dir" fetch -q --depth 1 origin tag "$tag"
  git -C "$dir" checkout -q "$tag"
done
