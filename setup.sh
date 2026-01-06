#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shell_settings="${HOME}/.config/ghostty/shell_settings"
shell_configs_var='SHELL_CONFIGS_FILE'
shell_configs_value="${shell_settings}"

# Parse command line arguments
os_type=""
for arg in "$@"; do
  if [[ "$arg" == --os=* ]]; then
    os_type="${arg#*=}"
    break
  fi
done

if [[ "$os_type" != "mac" && "$os_type" != "linux" ]]; then
  printf "Error: --os argument is required. Use --os=mac or --os=linux\n" >&2
  exit 1
fi

copy_ghostty_files() {
  local source_config="${script_dir}/config/config_${os_type}"
  local source_shell_settings="${script_dir}/config/shell_settings.sh"
  local target_dir="${HOME}/.config/ghostty"
  local target_config="${target_dir}/config"
  local target_shell_settings="${target_dir}/shell_settings"

  mkdir -p "${target_dir}"
  cp "${source_config}" "${target_config}"
  cp "${source_shell_settings}" "${target_shell_settings}"

  printf "Copied %s -> %s\n" "${source_config}" "${target_config}"
  printf "Copied %s -> %s\n" "${source_shell_settings}" "${target_shell_settings}"
}

copy_ghostty_files

add_source_line() {
  local rc_file="$1"
  local line="source \"${shell_settings}\""
  local export_line="export ${shell_configs_var}=\"${shell_configs_value}\""

  if [[ ! -f "$rc_file" ]]; then
    : >"$rc_file"
  fi

  if grep -Eq "^export ${shell_configs_var}=" "$rc_file"; then
    if ! grep -Fqx "$export_line" "$rc_file"; then
      tmp_file="${rc_file}.tmp.$$"
      awk -v key="${shell_configs_var}" -v line="${export_line}" '
        $0 ~ "^export " key "=" { print line; next }
        { print }
      ' "$rc_file" >"$tmp_file"
      mv "$tmp_file" "$rc_file"
      printf "Updated prompt export in %s\n" "$rc_file"
    else
      printf "Prompt export already present in %s\n" "$rc_file"
    fi
  else
    printf "\n# Ghostty prompt settings\n%s\n" "$export_line" >>"$rc_file"
    printf "Added prompt export to %s\n" "$rc_file"
  fi

  if ! grep -Fqx "$line" "$rc_file"; then
    printf "%s\n" "$line" >>"$rc_file"
    printf "Added prompt source to %s\n" "$rc_file"
  else
    printf "Prompt source already present in %s\n" "$rc_file"
  fi
}

case "${SHELL##*/}" in
  bash)
  	profile="${HOME}/.bashrc"
    if [[ "$os_type" == "mac" ]]; then
      profile="${HOME}/.bash_profile"
    fi

    add_source_line "$profile"
    ;;
  zsh)
    add_source_line "${HOME}/.zshrc"
    ;;
  *)
    printf "Unknown shell: %s\n" "${SHELL##*/}"
    printf "Add this line to your shell rc file:\n%s\n" "source \"${shell_settings}\""
    ;;
esac

printf "Setup complete. Restart your shell or run: source \"%s\"\n" "$shell_settings"
