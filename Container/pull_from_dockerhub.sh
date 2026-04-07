#!/bin/sh
# Pull a Docker Hub image as a Singularity/Apptainer .sif on HPC.
# Usage examples:
#   sh pull_from_dockerhub.sh
#   sh pull_from_dockerhub.sh qingzfly/getm-wad-container hydro_01 getm-wad-container_hydro_01.sif
#   sh pull_from_dockerhub.sh qingzfly/getm-wad-container hydro_01 my.sif 0

set -eu

IMAGE_REPO="${1:-qingzfly/getm-wad-container}"
IMAGE_TAG="${2:-hydro_01}"
OUT_SIF="${3:-getm-wad-container_${IMAGE_TAG}.sif}"
COPY_EXECUTABLES="${4:-1}"
IMAGE_URI="docker://${IMAGE_REPO}:${IMAGE_TAG}"

if command -v singularity >/dev/null 2>&1; then
    RUNTIME="singularity"
elif command -v apptainer >/dev/null 2>&1; then
    RUNTIME="apptainer"
else
    if command -v module >/dev/null 2>&1; then
        module load singularity || true
    fi

    if command -v singularity >/dev/null 2>&1; then
        RUNTIME="singularity"
    elif command -v apptainer >/dev/null 2>&1; then
        RUNTIME="apptainer"
    else
        echo "ERROR: Neither singularity nor apptainer is available in PATH."
        exit 1
    fi
fi

echo "Using runtime: ${RUNTIME}"
echo "Pulling ${IMAGE_URI}"
"${RUNTIME}" pull "${OUT_SIF}" "${IMAGE_URI}"

copy_from_image_dir() {
    IMAGE_DIR="$1"
    HOST_PARENT_DIR="$2"
    HOST_PARENT_REL=""

    case "${HOST_PARENT_DIR}" in
        "$HOME")
            HOST_PARENT_REL=""
            ;;
        "$HOME"/*)
            HOST_PARENT_REL="${HOST_PARENT_DIR#"$HOME"/}"
            ;;
        *)
            echo "ERROR: Host target must be under HOME. Got: ${HOST_PARENT_DIR}"
            return 1
            ;;
    esac

    if "${RUNTIME}" exec "${OUT_SIF}" test -d "${IMAGE_DIR}"; then
        mkdir -p "${HOST_PARENT_DIR}"
        "${RUNTIME}" exec --bind "$HOME:/host_home" "${OUT_SIF}" sh -c \
            "cp -a \"${IMAGE_DIR}\" \"/host_home/${HOST_PARENT_REL}/\""
        echo "Copied: ${IMAGE_DIR} -> ${HOST_PARENT_DIR}"
    else
        echo "Warning: ${IMAGE_DIR} not found in container. Skipping copy."
    fi
}

if [ "${COPY_EXECUTABLES}" = "1" ]; then
    echo "Copying compiled model folders to cluster locations..."
    copy_from_image_dir "/opt/local/gotm" "$HOME/local"
    copy_from_image_dir "/opt/local/getm" "$HOME/local"
    copy_from_image_dir "/opt/tools/getm/build" "$HOME/tools/getm"
fi

echo "Done. Created: ${OUT_SIF}"
echo "To start a shell:"
echo "  ${RUNTIME} shell ${OUT_SIF}"
echo "To bind your workspace:"
echo "  ${RUNTIME} shell --bind \$HOME/home/container:/opt/workspace ${OUT_SIF}"
