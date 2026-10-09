# syntax=docker/dockerfile:1
ARG JAVA_VERSION=21

# ---------------------------------------------------------------- build stage
FROM maven:3-eclipse-temurin-${JAVA_VERSION}-noble AS build
ARG JAVA_VERSION
ENV JAVA_VERSION=${JAVA_VERSION} \
    GRADLE_USER_HOME=/cache/gradle \
    MAVEN_OPTS="-Dmaven.repo.local=/root/.m2/repository"

WORKDIR /src
COPY dependencies/ dependencies/
COPY gradle/local-deps.gradle /opt/local-deps.gradle

# 1) Bio-Formats -> ~/.m2 (only the modules the converters need)
RUN --mount=type=cache,target=/root/.m2 \
    cd dependencies/bioformats && \
    mvn -B -q -DskipTests -pl components/formats-gpl -am install && \
    mvn -B -q help:evaluate -Dexpression=project.version -DforceStdout > /src/BF_VERSION && \
    mkdir -p /m2-snapshot/ome && cp -r /root/.m2/repository/ome/. /m2-snapshot/ome/

# 2) bioformats2raw -> ~/.m2, 3) raw2ometiff
RUN --mount=type=cache,target=/root/.m2 --mount=type=cache,target=/cache/gradle \
    set -eu; \
    cp -rn /m2-snapshot/ome/. /root/.m2/repository/ome/; \
    BF_VERSION=$(cat BF_VERSION); \
    B2R_VERSION=$(sed -n "s/^version = '\(.*\)'/\1/p" dependencies/bioformats2raw/build.gradle); \
    export BF_VERSION B2R_VERSION; \
    echo "Bio-Formats ${BF_VERSION}, bioformats2raw ${B2R_VERSION}, Java ${JAVA_VERSION}"; \
    GRADLE="./gradlew --no-daemon -q -I /opt/local-deps.gradle"; \
    (cd dependencies/bioformats2raw && $GRADLE -x test -x checkstyleMain -x checkstyleTest publishToMavenLocal installDist); \
    (cd dependencies/raw2ometiff   && $GRADLE -x test -x checkstyleMain -x checkstyleTest installDist); \
    mkdir -p /out; \
    cp -r dependencies/bioformats2raw/build/install/bioformats2raw /out/; \
    cp -r dependencies/raw2ometiff/build/install/raw2ometiff /out/; \
    { echo "java=${JAVA_VERSION}"; echo "bioformats=${BF_VERSION}"; echo "bioformats2raw=${B2R_VERSION}"; \
      echo "raw2ometiff=$(sed -n "s/^version = '\(.*\)'/\1/p" dependencies/raw2ometiff/build.gradle)"; } > /out/VERSIONS

# -------------------------------------------------------------- runtime stage
# Ubuntu/glibc, not Alpine: blosc/OpenCV/turbojpeg ship glibc native libraries.
FROM eclipse-temurin:${JAVA_VERSION}-jre-noble AS runtime
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Nextflow needs bash + ps/awk/date/grep/sed/tail/tee for tasks and tracing
RUN apt-get update \
 && apt-get install -y --no-install-recommends procps gawk \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/ /opt/
RUN ln -s /opt/bioformats2raw/bin/bioformats2raw /usr/local/bin/ \
 && ln -s /opt/raw2ometiff/bin/raw2ometiff /usr/local/bin/ \
 && echo "jre=$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.version = //p')" >> /opt/VERSIONS

COPY tests/smoke.sh /opt/tests/smoke.sh

# Source revisions the image was built from (set by scripts/build.sh and CI)
ARG BUILD_REVISION=unknown
ARG BIOFORMATS_REVISION=unknown
ARG BIOFORMATS2RAW_REVISION=unknown
ARG RAW2OMETIFF_REVISION=unknown
RUN { echo "build.revision=${BUILD_REVISION}"; \
      echo "bioformats.revision=${BIOFORMATS_REVISION}"; \
      echo "bioformats2raw.revision=${BIOFORMATS2RAW_REVISION}"; \
      echo "raw2ometiff.revision=${RAW2OMETIFF_REVISION}"; } >> /opt/VERSIONS

LABEL org.opencontainers.image.title="bioformats-conversion" \
      org.opencontainers.image.description="bioformats2raw + raw2ometiff built from submodules" \
      org.opencontainers.image.revision="${BUILD_REVISION}" \
      bioformats.revision="${BIOFORMATS_REVISION}" \
      bioformats2raw.revision="${BIOFORMATS2RAW_REVISION}" \
      raw2ometiff.revision="${RAW2OMETIFF_REVISION}"
