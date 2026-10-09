#!/bin/sh
# Print the version tag of an image, read from its /opt/VERSIONS:
#   bf<version>-<commit>_b2r<version>-<commit>_r2t<version>-<commit>_jre<Temurin version>_build<build key>
# Usage: scripts/version-tag.sh <image ref> <build key>. Needs regctl.
# POSIX sh.
set -eu

versions=$(regctl image get-file "$1" /opt/VERSIONS)
v() { printf '%s\n' "$versions" | sed -n "s/^$1=//p"; }
c() { v "$1.revision" | cut -c1-7; }

tag="bf$(v bioformats)-$(c bioformats)_b2r$(v bioformats2raw)-$(c bioformats2raw)_r2t$(v raw2ometiff)-$(c raw2ometiff)_jre$(v jre)_build$2"
printf '%s\n' "$tag" | tr -c 'A-Za-z0-9_.\n-' '-' | cut -c1-128
