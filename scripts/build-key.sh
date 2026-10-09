#!/bin/sh
# Print the build key: a hash over everything that goes into the image (the submodule
# commits, the Temurin runtime image and the build files). Used by CI to reuse an image
# that was already tested and released with the same key. Needs regctl.
# POSIX sh.
set -eu
cd "$(dirname "$0")/.."
. ./build.env

# Outside the pipe below, so a failed lookup fails the script
temurin=$(regctl image digest "docker.io/library/eclipse-temurin:${JAVA_VERSION}-jre-noble")

{
  git config -f .gitmodules --get-regexp '\.path$' | while read -r _ dir; do git -C "$dir" rev-parse HEAD; done
  echo "$temurin"
  git ls-files -s Dockerfile .dockerignore build.env gradle tests
} | sha256sum | cut -c1-8
