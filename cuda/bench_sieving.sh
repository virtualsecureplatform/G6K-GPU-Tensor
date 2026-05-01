#!/usr/bin/env bash
set -euo pipefail

CUDA_PATH=${CUDA_PATH:-/usr/local/cuda}
NVCC=${NVCC:-${CUDA_PATH}/bin/nvcc}
CUDA_CXX=${CUDA_CXX:-g++}
MAX_SIEVING_DIM=${MAX_SIEVING_DIM:-160}
GPUVECNUM=${GPUVECNUM:-131072}

if [ "${SMS:-}" = "" ] && command -v nvidia-smi >/dev/null 2>&1; then
    SMS=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
        | awk -F. '{ gsub(/[^0-9]/, "", $1); gsub(/[^0-9]/, "", $2); if ($1 != "" && $2 != "") print $1 $2 }' \
        | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]*$//')
fi
SMS=${SMS:-80}
SMS=$(echo "${SMS}" | tr ',' ' ')

GENCODE_FLAGS=()
for sm in ${SMS}; do
    GENCODE_FLAGS+=(-gencode "arch=compute_${sm},code=sm_${sm}")
done
highest_sm=$(printf '%s\n' ${SMS} | sort -n | tail -n1)
GENCODE_FLAGS+=(-gencode "arch=compute_${highest_sm},code=compute_${highest_sm}")

COMMON_FLAGS=(
    -ccbin "${CUDA_CXX}"
    -Xcompiler -fPIC
    -Xcompiler -Ofast
    -Xcompiler -march=native
    -Xcompiler -pthread
    -Xcompiler -Wall
    -Xcompiler -Wextra
    -DMAX_SIEVING_DIM="${MAX_SIEVING_DIM}"
    -DGPUVECNUM="${GPUVECNUM}"
    -DHAVE_CUDA
    -I../parallel-hashmap
    -std=c++11
    -O3
    "${GENCODE_FLAGS[@]}"
    -lineinfo
    -I"${CUDA_PATH}/include"
)

if [ -z "${1:-}" ]; then
    "${NVCC}" "${COMMON_FLAGS[@]}" -c ../cuda/GPUStreamGeneral.cu -o GPUStreamGeneral.o
fi

"${NVCC}" "${COMMON_FLAGS[@]}" -lcublas -lcurand --resource-usage bench_sieving.cpp -o bench_sieving GPUStreamGeneral.o
"${NVCC}" "${COMMON_FLAGS[@]}" -lcublas -lcurand --resource-usage bench_quality.cpp -o bench_quality GPUStreamGeneral.o
