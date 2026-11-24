#!/usr/bin/env bash
# Builds (and optionally pushes) the three custom images: python, jupyterbook and bcl2fastq.
# Set CONTAINER_REGISTRY / CONTAINER_TAG to use your own registry; PUSH=true pushes after building.
set -euo pipefail

REGISTRY="${CONTAINER_REGISTRY:-ghcr.io/mishrap1971}"
TAG="${CONTAINER_TAG:-0.8}"
PUSH="${PUSH:-false}"
# bcl2fastq only exists for Intel/AMD64 chips. for Apple Silicon systems, which use ARM chips, set PLATFORM=linux/amd64 so the image is built as if for an Intel.
PLATFORM="${PLATFORM:-}"

IMAGES=(python bcl2fastq jupyterbook)

DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
    targets=("${IMAGES[@]}")
fi

platform_args=()
if [ -n "${PLATFORM}" ]; then
    platform_args=(--platform "${PLATFORM}")
fi

for name in "${targets[@]}"; do
    if [[ ! " ${IMAGES[*]} " == *" ${name} "* ]]; then
        echo "unknown image '${name}' — expected one of: ${IMAGES[*]}" >&2
        exit 1
    fi
    tag="${REGISTRY}/${name}:${TAG}"
    echo "== building ${tag} =="
    docker build ${platform_args[@]+"${platform_args[@]}"} -t "${tag}" "${DOCKER_DIR}/${name}"
    if [ "${PUSH}" = "true" ]; then
        echo "== pushing ${tag} =="
        docker push "${tag}"
    fi
done
