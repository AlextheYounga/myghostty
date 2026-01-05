#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_config="${script_dir}/config"
target_dir="${HOME}/.config/ghostty"
target_config="${target_dir}/config"

mkdir -p "${target_dir}"
ln -sfn "${source_config}" "${target_config}"

printf "Linked %s -> %s\n" "${target_config}" "${source_config}"
