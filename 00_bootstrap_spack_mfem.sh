#!/usr/bin/env bash
set -euo pipefail

# ---------- user knobs ----------
SPACK_DIR="${HOME}/spack"
SPACK_ENV_NAME="mfem-env"

# choose toolchain modules present on your cluster
# (from your module list)
LOAD_MODULES=(
  "cmake/3.28.3"
  "git/2.41.0"
  "gnu8/8.3.0"
)
# optionally add CUDA if you plan GPU builds; can be added later too
# LOAD_MODULES+=("cuda12/12.5")

# MFEM variants (CPU default). For GPU later, you’ll add +cuda to the env.
MFEM_SPECS=(
  "openmpi %gcc"
  "mfem +mpi +hypre +metis ^openmpi"
  # add glvis if you plan to visualize on a workstation with GUI libs available:
  # "glvis"
)

# ---------- load site modules ----------
module purge || true
for m in "${LOAD_MODULES[@]}"; do
  module load "$m"
done

# ---------- install or update spack ----------
if [[ ! -d "${SPACK_DIR}" ]]; then
  git clone https://github.com/spack/spack.git "${SPACK_DIR}"
else
  git -C "${SPACK_DIR}" pull --ff-only
fi
# shellcheck disable=SC1090
source "${SPACK_DIR}/share/spack/setup-env.sh"

# ---------- discover externals (compilers, cuda if loaded) ----------
spack external find || true
spack compilers

# ---------- create/update a spack environment for MFEM ----------
if ! spack env list | grep -q "^${SPACK_ENV_NAME}\$"; then
  spack env create "${SPACK_ENV_NAME}"
fi

# switch to env
spack env activate "${SPACK_ENV_NAME}"

# add specs to the env (idempotent: add only if missing)
for spec in "${MFEM_SPECS[@]}"; do
  if ! spack -e "${SPACK_ENV_NAME}" find --format "{name} {version}" ${spec} >/dev/null 2>&1; then
    spack -e "${SPACK_ENV_NAME}" add ${spec}
  fi
done

# ---------- concretize & install ----------
spack -e "${SPACK_ENV_NAME}" concretize -f
spack -e "${SPACK_ENV_NAME}" install --fail-fast

# ---------- report ----------
echo
echo "Spack environment '${SPACK_ENV_NAME}' is ready."
echo "To use it in any shell:"
echo "  source ${SPACK_DIR}/share/spack/setup-env.sh"
echo "  spack env activate ${SPACK_ENV_NAME}"
echo "  spack load mfem"
echo
echo "Tip (GPU later):"
echo "  spack -e ${SPACK_ENV_NAME} add mfem +mpi +hypre +metis +cuda cuda_arch=80  # A100 example"
echo "  spack -e ${SPACK_ENV_NAME} concretize -f && spack -e ${SPACK_ENV_NAME} install"
