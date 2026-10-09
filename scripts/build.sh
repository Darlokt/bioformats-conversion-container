#!/bin/bash
# Build the Docker image and smoke-test it.
# Usage: scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source build.env

image="${IMAGE_NAME}:${IMAGE_TAG}"

# Source revisions as --build-arg KEY=VALUE
build_args=(--build-arg JAVA_VERSION="${JAVA_VERSION}")
while IFS= read -r kv; do build_args+=(--build-arg "$kv"); done < <(scripts/revisions.sh)

echo "==> Building ${image} (Temurin ${JAVA_VERSION}, newest release)"
docker build --pull "${build_args[@]}" \
  -t "${image}" .

echo "==> Smoke tests (as non-root user)"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp "${image}" /opt/tests/smoke.sh
