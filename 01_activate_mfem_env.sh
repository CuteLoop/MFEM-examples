#!/usr/bin/env bash
set -euo pipefail

SPACK_DIR="${HOME}/spack"
SPACK_ENV_NAME="mfem-env"

# site modules you want *active* in regular shells
LOAD_MODULES=(
  "cmake/3.28.3"
  "git/2.41.0"
  "gnu8/8.3.0"
  # "cuda12/12.5"   # uncomment if you want CUDA in every session
)

# 1) site modules
module purge || true
for m in "${LOAD_MODULES[@]}"; do
  module load "$m"
done

# 2) spack environment
# shellcheck disable=SC1090
source "${SPACK_DIR}/share/spack/setup-env.sh"
spack env activate "${SPACK_ENV_NAME}"

# 3) load mfem (and friends) into this shell’s PATH/LD_LIBRARY_PATH
spack load mfem

# (optional) quiet Git pulls by adding your SSH key once per session:
# if command -v ssh-add >/dev/null 2>&1; then
#   eval "$(ssh-agent -s)" >/dev/null
#   ssh-add -q "${HOME}/.ssh/id_ed25519" || true
# fi

# sanity prints (comment out if noisy)
echo "[MFEM env active] $(spack find --loaded)"
