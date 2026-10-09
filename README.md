# bioformats-conversion-container

[![CI](https://github.com/Darlokt/bioformats-conversion-container/actions/workflows/ci.yml/badge.svg)](https://github.com/Darlokt/bioformats-conversion-container/actions/workflows/ci.yml)
![Status](https://img.shields.io/badge/Status-in_development-yellow)
[![Language](https://img.shields.io/badge/Language-Java-blue)](https://openjdk.org/)
[![Java](https://img.shields.io/badge/Java-21-blue?logo=openjdk)](https://adoptium.net/temurin/)
[![Base Image](https://img.shields.io/badge/Base_Image-eclipse--temurin-lightgrey)](https://hub.docker.com/_/eclipse-temurin)
[![Container](https://img.shields.io/badge/Container-Docker-lightgrey?logo=docker)](https://www.docker.com/)
[![Nextflow](https://img.shields.io/badge/Runs_in-Nextflow-lightgrey)](https://www.nextflow.io/)

## General information

This repository builds a container for converting microscopy images to OME-Zarr and
OME-TIFF in Nextflow pipelines.

It provides:

- [bioformats2raw](https://github.com/glencoesoftware/bioformats2raw) and
  [raw2ometiff](https://github.com/glencoesoftware/raw2ometiff), built on the same
  [Bio-Formats](https://github.com/ome/bioformats)
- A `stable` image with the latest upstream releases and an `unstable` image with
  newer development versions
- Images for Nextflow and Docker, public on
  `ghcr.io/darlokt/bioformats-conversion-container`

## Project Structure

```text
bioformats-conversion-container/
├── .github/
│   ├── actions/
│   │   └── setup-registry/  # Composite action: image name, regctl, GHCR login
│   ├── workflows/
│   │   ├── ci.yml           # Triggers, lint, one image.yml run per channel
│   │   └── image.yml        # Build, smoke-test and release one channel
│   └── dependabot.yml       # Weekly submodule and action updates
├── dependencies/
│   ├── bioformats/          # Submodule: ome/bioformats (Maven)
│   ├── bioformats2raw/      # Submodule: glencoesoftware/bioformats2raw (Gradle)
│   └── raw2ometiff/         # Submodule: glencoesoftware/raw2ometiff (Gradle)
├── gradle/
│   └── local-deps.gradle    # Gradle init script wiring the builds together
├── scripts/
│   ├── build.sh             # Build and smoke-test locally
│   ├── build-key.sh         # Hash of everything that goes into the image (CI)
│   ├── checkout-releases.sh # Submodules to their newest release tags (CI, stable)
│   ├── revisions.sh         # Source revisions for /opt/VERSIONS (build.sh and CI)
│   └── version-tag.sh       # Version tag from an image's /opt/VERSIONS (CI)
├── tests/
│   └── smoke.sh             # Smoke tests run inside the image
├── build.env                # Build configuration (Java version, image name)
├── Dockerfile               # Multi-stage build: JDK build stage → JRE runtime stage
└── README.md                # Project overview and usage
```

### Directory Overview

| Path | Description |
| --- | --- |
| [`.github/workflows/`](.github/workflows/) | Builds, tests and publishes the image with GitHub Actions. |
| [`dependencies/`](dependencies/) | Upstream sources as Git submodules, kept unmodified. |
| [`gradle/local-deps.gradle`](gradle/local-deps.gradle) | Forces the Gradle builds onto the locally built snapshot versions and the configured JDK. |
| [`scripts/build.sh`](scripts/build.sh) | Builds the Docker image and runs the smoke tests. |
| [`scripts/build-key.sh`](scripts/build-key.sh) | Prints the build key that decides whether CI rebuilds or reuses an image. |
| [`scripts/checkout-releases.sh`](scripts/checkout-releases.sh) | Checks out every submodule at its newest upstream release tag, for the stable images. |
| [`scripts/revisions.sh`](scripts/revisions.sh) | Prints the commit of this repository and of each submodule as build args. |
| [`scripts/version-tag.sh`](scripts/version-tag.sh) | Prints the version tag of an image, read from its `/opt/VERSIONS`. |
| [`tests/smoke.sh`](tests/smoke.sh) | Checks the Nextflow tools, version wiring, and a fake → OME-Zarr → OME-TIFF conversion. |
| [`build.env`](build.env) | Java version and image name/tag. |
| [`Dockerfile`](Dockerfile) | Build recipe for the image. |

## Pulling the image

The images are public, no login needed:

```bash
docker pull ghcr.io/darlokt/bioformats-conversion-container:latest
```

In Nextflow, use
`container 'ghcr.io/darlokt/bioformats-conversion-container:<tag>'`. Use a version tag
(see [Tags](#tags)) for reproducible pipelines.

## Build

### Requirements

- Docker 23 or newer (BuildKit, the default builder, is needed for the cache mounts in
  the `Dockerfile`)

### Usage

```bash
git submodule update --init
scripts/build.sh            # Docker image + smoke tests
```

### Configuration

[`build.env`](build.env) sets `JAVA_VERSION`, the Java feature version. Every build
pulls the newest Temurin release of that version (`docker build --pull`).

### How the builds are chained

1. Bio-Formats is installed into the local Maven repository with `mvn install`.
2. bioformats2raw is built and published to the local Maven repository.
3. raw2ometiff is built against that bioformats2raw.

The submodules hardcode release versions of their dependencies. The Gradle init script
[`gradle/local-deps.gradle`](gradle/local-deps.gradle) replaces them with the versions of
the checked-out sources, so no edits to the submodules are needed.

## CI and container registry

[`ci.yml`](.github/workflows/ci.yml) lints the repository, then runs
[`image.yml`](.github/workflows/image.yml) once per channel. Each run builds the image,
smoke-tests it and pushes it to the GitHub Container Registry:

| Channel | Sources |
| --- | --- |
| `unstable` | The submodules as pinned in this repository. |
| `stable` | Every submodule at its newest upstream release tag (`vX.Y.Z`, no release candidates), checked out by [`scripts/checkout-releases.sh`](scripts/checkout-releases.sh). |

| Job | What it does |
| --- | --- |
| `Lint` | shellcheck, hadolint, `docker build --check` and actionlint. |
| `<channel> / Build and smoke test` | Computes the build key. If a released image has the same key, tags it `:<short commit>-<channel>` instead of rebuilding. Otherwise builds the image with the commits from [`scripts/revisions.sh`](scripts/revisions.sh), reusing unchanged stages from a registry cache (`:buildcache-<channel>`), and pushes it as `:<short commit>-<channel>`. Then runs [`tests/smoke.sh`](tests/smoke.sh) in the image as a non-root user, and attests newly built images. |
| `<channel> / Release` | After the tests pass, adds the release tags below. Default branch and tags only. |

Pull requests, including those from forks and Dependabot, build and smoke-test the image
locally and push nothing.

Workflows run for pushes to `main`, tags, pull requests, manual runs (**Actions → CI →
Run workflow**) and a weekly schedule (Tuesdays), which picks up new Temurin and upstream
releases. GitHub disables scheduled workflows after 60 days without activity in the
repository; re-enable it under **Actions → CI**.

### Tags

| Tag | Set by |
| --- | --- |
| `:latest-stable`, `:latest` | `stable`, default branch |
| `:latest-unstable` | `unstable`, default branch |
| `:<git tag>-<channel>` | Tag pushes |
| Version tag | Default branch and tag pushes |

The version tag names the version and short commit of each tool, the Temurin JRE
release and the build key, for example
`bf8.5.0-877c317_b2r0.12.1-f0efe80_r2t0.10.1-a6a5393_jre21.0.12.1_build4606ba14`. It is
read from the image's `/opt/VERSIONS`.

The build key is a hash of everything that goes into the image: the submodule commits,
the digest of the Temurin JRE base image, and `Dockerfile`, `.dockerignore`,
`build.env`, `gradle/` and `tests/`. An image is only rebuilt when one of these changes,
for example a new upstream release or Temurin image, so a commit that changes nothing
else reuses the released image. Because the version tag contains the key, a rebuild
never overwrites an existing version tag.

### Attestations

Every newly built image gets a signed build provenance attestation and an SPDX SBOM
attestation, stored next to the image in the registry:

```bash
gh attestation verify oci://ghcr.io/darlokt/bioformats-conversion-container:latest --owner Darlokt
```

### Dependency updates

[Dependabot](.github/dependabot.yml) opens weekly pull requests that move the submodule
pins (the `unstable` channel) and the pinned GitHub Actions forward.

## Bumping a dependency

```bash
git -C dependencies/bioformats checkout v9.0.0
scripts/build.sh
git add dependencies/bioformats && git commit
```

The version overrides follow the checked-out sources automatically.

## Provenance

Each image records the commit of this repository and of every submodule it was built
from, in `/opt/VERSIONS` and as image labels. `-dirty` marks uncommitted changes.

```bash
docker run --rm ghcr.io/darlokt/bioformats-conversion-container:latest cat /opt/VERSIONS
```
