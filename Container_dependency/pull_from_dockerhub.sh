#!/bin/sh
# Pull a Docker Hub image as a Singularity/Apptainer .sif on HPC.
# Usage examples:
#   sh pull_from_dockerhub.sh
#   sh pull_from_dockerhub.sh qingzfly/getm-wad-container hydro_01 getm-wad-container_hydro_01.sif
#   sh pull_from_dockerhub.sh qingzfly/getm-wad-container hydro_01 my.sif 0

set -eu

IMAGE_REPO="${1:-qingzfly/getm-wad-container}"
IMAGE_TAG="${2:-hydro_500m}"
OUT_DIR="$HOME/Singularity_containers"
OUT_SIF_NAME="${3:-getm-wad-container_${IMAGE_TAG}.sif}"
OUT_SIF="${OUT_DIR}/${OUT_SIF_NAME}"
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
mkdir -p "${OUT_DIR}"
"${RUNTIME}" pull "${OUT_SIF}" "${IMAGE_URI}"

sync_from_image_dir_rsync() {
    IMAGE_DIR="$1"
    HOST_TARGET_DIR="$2"
    HOST_TARGET_REL=""

    case "${HOST_TARGET_DIR}" in
        "$HOME")
            HOST_TARGET_REL=""
            ;;
        "$HOME"/*)
            HOST_TARGET_REL="${HOST_TARGET_DIR#"$HOME"/}"
            ;;
        *)
            echo "ERROR: Host target must be under HOME. Got: ${HOST_TARGET_DIR}"
            return 1
            ;;
    esac

    if "${RUNTIME}" exec "${OUT_SIF}" test -d "${IMAGE_DIR}"; then
        mkdir -p "${HOST_TARGET_DIR}"
        "${RUNTIME}" exec --bind "$HOME:/host_home" "${OUT_SIF}" sh -c \
            "command -v rsync >/dev/null 2>&1 || { echo 'ERROR: rsync not found in container.'; exit 1; }; \
             mkdir -p \"/host_home/${HOST_TARGET_REL}\"; \
             rsync -a --delete \"${IMAGE_DIR}/\" \"/host_home/${HOST_TARGET_REL}/\""
        echo "Synced (rsync --delete): ${IMAGE_DIR} -> ${HOST_TARGET_DIR}"
    else
        echo "Warning: ${IMAGE_DIR} not found in container. Skipping sync."
    fi
}

if [ "${COPY_EXECUTABLES}" = "1" ]; then
    echo "Copying compiled model folders to cluster locations..."
    sync_from_image_dir_rsync "/opt/local/gotm" "$HOME/local"
    sync_from_image_dir_rsync "/opt/local/getm" "$HOME/local"
    sync_from_image_dir_rsync "/opt/tools/getm/build" "$HOME/tools/getm"
    sync_from_image_dir_rsync "/opt/home/GETM_ERSEM_SETUPS/dws_500m/bin" "$HOME/home/GETM_ERSEM_SETUPS/dws_500m/bin"
fi

echo "Done. Created: ${OUT_SIF}"
echo "To start a shell:"
echo "  ${RUNTIME} shell ${OUT_SIF}"
echo "To bind your workspace:"
echo "  ${RUNTIME} shell --bind \$HOME/home/container:/opt/workspace ${OUT_SIF}"
