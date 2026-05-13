#!/bin/sh
# Pull a Docker Hub image as a Singularity/Apptainer .sif on HPC.
# Usage examples:
#   sh pull_from_dockerhub.sh
#   sh pull_from_dockerhub.sh qingzfly/getm-wad-container latest getm-wad-container_latest.sif
#   sh pull_from_dockerhub.sh qingzfly/getm-wad-container sha-<commit> my.sif 0

set -eu

IMAGE_REPO="${1:-qingzfly/getm-wad-container}"
IMAGE_TAG="${2:-latest}"
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

# directory exists
mkdir -p "${OUT_DIR}"
mkdir -p "$HOME/home/GETM_ERSEM_SETUPS/log"

# Remove existing .sif file to allow overwrite
if [ -f "${OUT_SIF}" ]; then
    echo "Removing existing image: ${OUT_SIF}"
    rm -f "${OUT_SIF}"
fi

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
    sync_from_image_dir_rsync "/opt/home/GETM_ERSEM_SETUPS/dws_500m" "$HOME/home/dws_500m"
fi

# ------------------------------------------------------------------
# Create symbolic links required before running the model on the cluster
# ------------------------------------------------------------------
SETUP_DIR="$HOME/home/GETM_ERSEM_SETUPS/dws_500m"

# Ensure expected directories exist first
mkdir -p "$SETUP_DIR"
mkdir -p "$HOME/model_output/active_runs/dws_500m"
mkdir -p "$HOME/home/GETM_ERSEM_SETUPS/dws_500m/out/dws_500m/26x20/base_1"

# Helper function to recreate symlinks forcefully
create_symlink() {
    local target="$1"
    local link_path="$2"

    mkdir -p "$(dirname "${link_path}")"

    if [ -d "${link_path}" ] && [ ! -L "${link_path}" ]; then
        rm -rf "${link_path}"
    fi

    ln -sfn "${target}" "${link_path}"
    echo "  Linked: $(basename "${link_path}") -> ${target}"
    return 0
}

echo "Creating setup directory symlinks..."

# Local symlinks within the dws_500m directory
create_symlink "Configurations/26x20/dws_500m.dim" "${SETUP_DIR}/dimensions.h"
create_symlink "bio_bfm_test.nml" "${SETUP_DIR}/bio_bfm.nml"
create_symlink "no_bio.inp" "${SETUP_DIR}/bio.inp"
create_symlink "dws_500m.xml_Christos" "${SETUP_DIR}/dws_500m.xml"
create_symlink "Configurations/26x20/dws_500m.mask.size0026x0020_offset+0000x-0006_nodes002.machine_file" \
               "${SETUP_DIR}/link_machinefile"
create_symlink "mask.adjust.dws_500m" "${SETUP_DIR}/mask.adjust"
create_symlink "Configurations/26x20/dws_500m.mask.size0026x0020_offset+0000x-0006_nodes002.subdomain_spec.lst" \
               "${SETUP_DIR}/par_setup.dat"
create_symlink "riverinfo_20200323_WaddenSea_dws_500m.dat" "${SETUP_DIR}/riverinfo.dat"
create_symlink "run_all_Christos_2_nodes" "${SETUP_DIR}/run_all"
create_symlink "run.getm_laplace_getmiow_Christos" "${SETUP_DIR}/run.getm"
create_symlink "../log/" "${SETUP_DIR}/log"

# External symlinks (cluster-specific paths)
echo "Creating external symlinks to shared cluster data..."
create_symlink "/export/lv9/ERSEM_runs/boundaries/dws_500m_nwes/bdy_dws_500m_2_2014_12.2d.nc" \
               "${SETUP_DIR}/bdy_2d.nc"
create_symlink "/export/lv9/ERSEM_runs/boundaries/dws_500m_nwes/bdy_dws_500m_2_2014_12.3d.nc" \
               "${SETUP_DIR}/bdy_3d.nc"
create_symlink "${HOME}/home/GETM_ERSEM_SETUPS/dws_500m/out/dws_500m/26x20/base_1" \
               "${SETUP_DIR}/flex_out"
create_symlink "${HOME}/model_output/active_runs/dws_500m" \
               "${SETUP_DIR}/out"
create_symlink "/export/lv1/user/svanleeuwen/home/model_input_files/rivers/20200323/rivers_bfm_20200323_WaddenSea_all.nc" \
               "${SETUP_DIR}/rivers.nc"
create_symlink "/export/lv9/user/cgiannopoulos/home/pre-processing/bathymetry_resampling/topo_dws_500m.nc" \
               "${SETUP_DIR}/topo.nc"

echo "Done. Created: ${OUT_SIF}"
echo "To start a shell:"
echo "  ${RUNTIME} shell ${OUT_SIF}"
echo "To bind your workspace:"
echo "  ${RUNTIME} shell --bind \$HOME/home/container:/opt/workspace ${OUT_SIF}"

#sh models_auto_setup/pull_from_dockerhub.sh qingzfly/getm-wad-container latest getm-wad-container_latest.sif