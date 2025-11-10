
---

# MFEM on HPC — Quick Start (Spack-first)

This guide shows how to install and use **MFEM** on *any* HPC with environment modules. It’s split into:

* **One-time bootstrap** (build once with Spack)
* **Per-login activation** (use it every session / in jobs)

It works even if your cluster has different compiler/MPI/CUDA versions.

---

## TL;DR

1. On your HPC login node, check what exists:

```bash
module avail
```

2. Run the one-time bootstrap (downloads Spack, builds OpenMPI + MFEM):

```bash
bash 00_bootstrap_spack_mfem.sh
```

3. Activate the environment each login (or source in your `~/.bashrc`):

```bash
source 01_activate_mfem_env.sh
```

4. Test:

```bash
MFEM_PREFIX="$(spack location -i mfem)"
cp -r "${MFEM_PREFIX}/examples" ~/mfem_examples && cd ~/mfem_examples
make ex1 -j && ./ex1 -m ../data/beam-hex.mesh
```

MPI test:

```bash
make ex1p -j
srun -n 4 ./ex1p -m ../data/beam-hex.mesh -pa
```

---

## 0) Inspect your HPC

Every HPC is different. First, see what you have:

```bash
module avail
```

Look for **CMake**, **Git**, **GCC (or Intel/Clang)**, and (if you’ll use GPUs) **CUDA**.
If present, the bootstrap script will load these (you can tweak versions inside the script).

---

## 1) One-time bootstrap (builds MFEM)

**File:** `00_bootstrap_spack_mfem.sh`
**Run:** once per account (safe to re-run)

What it does:

* Loads core modules (CMake, Git, GCC).
* Clones/updates **Spack** into `~/spack`.
* Lets Spack discover your toolchain (`spack external find`).
* Creates a Spack env and installs:

  * `openmpi` (built by Spack)
  * `mfem +mpi +hypre +metis` (CPU build; add CUDA later if needed)

> If your site already has a preferred compiler/MPI, load those modules *before* running the script (and adjust the `LOAD_MODULES` list inside).

---

## 2) Per-login activation (use MFEM)

**File:** `01_activate_mfem_env.sh`
**Run:** each new shell (or add to `~/.bashrc`)

What it does:

* Loads the same core modules (CMake, Git, GCC; adjust if needed).
* Activates your Spack environment.
* `spack load mfem` so the right `PATH/LD_LIBRARY_PATH` are set.

---

## 3) Smoke tests

**Serial:**

```bash
MFEM_PREFIX="$(spack location -i mfem)"
cp -r "${MFEM_PREFIX}/examples" ~/mfem_examples && cd ~/mfem_examples
make ex1 -j && ./ex1 -m ../data/beam-hex.mesh
```

**MPI (Slurm example):**

```bash
make ex1p -j
srun -n 4 ./ex1p -m ../data/beam-hex.mesh -pa
```

---

## 4) Optional: GPUs (add later)

If your cluster has NVIDIA GPUs, get the architecture on a GPU node:

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader
# map compute_cap (e.g., 8.0 → sm_80 A100; 7.0 → sm_70 V100; 9.0 → sm_90 H100)
```

Then extend your Spack env (one time):

```bash
spack -e mfem-env add mfem +mpi +hypre +metis +cuda cuda_arch=80   # change 80 as needed
spack -e mfem-env concretize -f && spack -e mfem-env install
```

Your normal `01_activate_mfem_env.sh` still works; it will now load the CUDA build.

**Minimal GPU Slurm template** (edit account/partition and paths):

```bash
#!/bin/bash
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --gpus-per-node=1
#SBATCH -t 00:15:00
#SBATCH -J mfem_gpu
#SBATCH -A <your_account>
#SBATCH -p <gpu_partition>

module purge
source $HOME/spack/share/spack/setup-env.sh
spack env activate mfem-env
spack load mfem

MFEM_PREFIX="$(spack location -i mfem)"
cp -r "${MFEM_PREFIX}/examples" $SLURM_SUBMIT_DIR/examples
cd $SLURM_SUBMIT_DIR/examples && make ex1p -j

srun -n 4 ./ex1p -m ../data/beam-hex.mesh -pa
```

---

## 5) Common pitfalls

* **Modules don’t persist:** modules & Spack loads are per-shell. Source `01_activate_mfem_env.sh` in every shell or in `~/.bashrc`.
* **Wrong compiler/MPI picked:** edit `LOAD_MODULES` lists in both scripts to the site-preferred toolchain, re-run the bootstrap.
* **CUDA mismatch:** `cuda_arch` must match the node GPU (e.g., A100 → `80`). Re-concretize/re-install if you change it.
* **GLVis on HPC:** prefer running GLVis locally (or via X-forwarding). You can `spack install glvis` if you need it.

---

## 6) Repo layout (suggested)

```
.
├─ 00_bootstrap_spack_mfem.sh   # one-time builder
├─ 01_activate_mfem_env.sh      # per-login activator
├─ README.md                    # this file
└─ slurm/
   ├─ cpu_example.slurm
   └─ gpu_example.slurm
```

---

## 7) Updating

When you want newer MFEM or dependencies:

```bash
# update spack
git -C $HOME/spack pull --ff-only
. $HOME/spack/share/spack/setup-env.sh
spack env activate mfem-env

# adjust specs (e.g., add +cuda), then:
spack concretize -f
spack install --fail-fast
```

---
