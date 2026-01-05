#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

config_linker="${script_dir}/scripts/link_ghostty_config.sh"
shell_settings="${script_dir}/scripts/shell_settings.sh"
shell_configs_var='SHELL_CONFIGS_FILE'
shell_configs_value="${shell_settings}"

if [[ ! -x "$config_linker" ]]; then
  chmod +x "$config_linker"
fi

"$config_linker"

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
    add_source_line "${HOME}/.bashrc"
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
