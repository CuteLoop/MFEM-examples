#!/usr/bin/env bash
set -euo pipefail

# ---------- user configuration ----------
SPACK_DIR="${HOME}/spack"
SPACK_ENV_NAME="mfem-env"

# Site modules (adjust to your HPC)
LOAD_MODULES=(
  "cmake/3.28.3"
  "git/2.41.0"
  "gnu8/8.3.0"
)
# Optionally add CUDA later, e.g.:
# LOAD_MODULES+=("cuda12/12.5")

# Root specs (CPU default). Add +cuda later if needed.
MFEM_SPECS=(
  "openmpi %gcc"
  "mfem +mpi +metis ^openmpi"
  # "glvis"     # uncomment if you need the viewer
)

ts() { date +'%F %T'; }
log() { echo "[$(ts)] $*"; }
section() { echo; echo "==== $* ===="; }
fail() { echo "ERROR: $*" >&2; exit 2; }

section "Loading site modules"
module purge || true
for m in "${LOAD_MODULES[@]}"; do
  module load "$m"
done
log "Modules loaded: ${LOAD_MODULES[*]}"

section "Ensuring Spack is present"
if [[ ! -d "${SPACK_DIR}" ]]; then
  git clone https://github.com/spack/spack.git "${SPACK_DIR}"
  log "Spack cloned to ${SPACK_DIR}"
else
  git -C "${SPACK_DIR}" pull --ff-only
  log "Spack updated in ${SPACK_DIR}"
fi
# shellcheck disable=SC1090
source "${SPACK_DIR}/share/spack/setup-env.sh"

section "Detecting compilers and externals (idempotent)"
if ! spack compiler list 2>/dev/null | grep -Eq '(gcc|clang|intel)'; then
  spack compiler find || log "compiler find returned non-zero; continuing"
fi
spack external find cmake git || true
log "Compilers available:"
spack compiler list || true

section "Preparing Spack environment: ${SPACK_ENV_NAME}"
if ! spack env list | grep -qx "${SPACK_ENV_NAME}"; then
  spack env create "${SPACK_ENV_NAME}"
  log "Environment created: ${SPACK_ENV_NAME}"
else
  log "Environment already exists: ${SPACK_ENV_NAME}"
fi
spack env activate "${SPACK_ENV_NAME}"

section "Adding root specs (idempotent)"
for spec in "${MFEM_SPECS[@]}"; do
  # spack add is idempotent; it will not duplicate identical root specs
  spack -e "${SPACK_ENV_NAME}" add ${spec} || true
done
log "Root specs configured."

section "Checking current installation status"
MFEM_INSTALLED=0
if spack -e "${SPACK_ENV_NAME}" find mfem >/dev/null 2>&1; then
  if spack -e "${SPACK_ENV_NAME}" find mfem | grep -q '^mfem@'; then
    MFEM_INSTALLED=1
  fi
fi

if [[ "${MFEM_INSTALLED}" -eq 1 ]]; then
  log "MFEM is already installed in environment '${SPACK_ENV_NAME}'. No build required."
  echo
  echo "Environment ready. To use in a new shell:"
  echo "  source ${SPACK_DIR}/share/spack/setup-env.sh"
  echo "  spack env activate ${SPACK_ENV_NAME}"
  echo "  spack load mfem"
  exit 0
fi

section "Concretizing environment (force refresh)"
spack -e "${SPACK_ENV_NAME}" concretize -f

section "Installing (will reuse any completed builds)"
spack -e "${SPACK_ENV_NAME}" install --fail-fast --reuse

section "Verifying installation"
if spack -e "${SPACK_ENV_NAME}" find mfem | grep -q '^mfem@'; then
  log "MFEM installation completed successfully."
else
  fail "MFEM not found after installation. Inspect build logs. Tip: spack -e ${SPACK_ENV_NAME} stage -p mfem"
fi

section "Summary"
echo "Environment: ${SPACK_ENV_NAME}"
echo "Spack dir  : ${SPACK_DIR}"
echo
echo "Use in any new shell:"
echo "  source ${SPACK_DIR}/share/spack/setup-env.sh"
echo "  spack env activate ${SPACK_ENV_NAME}"
echo "  spack load mfem"
echo
echo "Optional GPU build (example for A100, sm_80):"
echo "  spack -e ${SPACK_ENV_NAME} add mfem +mpi +metis +cuda cuda_arch=80"
echo "  spack -e ${SPACK_ENV_NAME} concretize -f && spack -e ${SPACK_ENV_NAME} install --reuse"
