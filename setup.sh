#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHOSTTY_DIR="${HOME}/.config/ghostty"
SHELL_SETTINGS_PATH="${GHOSTTY_DIR}/shell_settings"

log() {
  printf "%s\n" "$*"
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

copy_ghostty_files() {
  local source_config="${SCRIPT_DIR}/config/config"
  local source_shell_settings="${SCRIPT_DIR}/config/shell_settings.sh"
  local target_config="${GHOSTTY_DIR}/config"

  mkdir -p "${GHOSTTY_DIR}"
  cp "${source_config}" "${target_config}"
  cp "${source_shell_settings}" "${SHELL_SETTINGS_PATH}"

  log "Copied ${source_config} -> ${target_config}"
  log "Copied ${source_shell_settings} -> ${SHELL_SETTINGS_PATH}"
}

completion_already_installed() {
  if has_command brew; then
    local brew_prefix
    brew_prefix="$(brew --prefix)"
    [[ -f "${brew_prefix}/opt/bash-completion@2/etc/profile.d/bash_completion.sh" ]]
    return
  fi

  [[ -f "/etc/bash_completion" || -f "/etc/profile.d/bash_completion.sh" || -f "/usr/share/bash-completion/bash_completion" ]]
}

completion_package_name() {
  if has_command brew; then
    printf "bash-completion@2"
  else
    printf "bash-completion"
  fi
}

package_for_tool() {
  local tool="$1"
  case "$tool" in
    delta)
      printf "git-delta"
      ;;
    *)
      printf "%s" "$tool"
      ;;
  esac
}

missing_packages() {
  local missing=()
  local tool
  for tool in fzf zoxide bat eza delta; do
    if [[ "$tool" == "bat" ]]; then
      if has_command bat || has_command batcat; then
        continue
      fi
      missing+=("$(package_for_tool "$tool")")
      continue
    fi

    if ! has_command "$tool"; then
      missing+=("$(package_for_tool "$tool")")
    fi
  done

  if ! completion_already_installed; then
    missing+=("$(completion_package_name)")
  fi

  printf "%s\n" "${missing[@]}"
}

install_with_brew() {
  brew install "$@"
}

install_with_apt() {
  sudo apt-get update
  if printf '%s\n' "$@" | grep -qx "bat"; then
    if ! sudo apt-get install -y bat; then
      sudo apt-get install -y batcat
    fi
  fi
  for pkg in "$@"; do
    [[ "$pkg" == "bat" ]] && continue
    sudo apt-get install -y "$pkg"
  done
}

install_with_dnf() {
  sudo dnf install -y "$@"
}

install_with_pacman() {
  sudo pacman -S --noconfirm "$@"
}

install_dependencies() {
  local missing=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && missing+=("$pkg")
  done < <(missing_packages)
  if (( ${#missing[@]} == 0 )); then
    log "All optional tools already installed."
    return
  fi

  log "Installing optional tools: ${missing[*]}"

  if has_command brew; then
    install_with_brew "${missing[@]}"
    return
  fi

  if has_command apt-get; then
    install_with_apt "${missing[@]}"
    return
  fi

  if has_command dnf; then
    install_with_dnf "${missing[@]}"
    return
  fi

  if has_command pacman; then
    install_with_pacman "${missing[@]}"
    return
  fi

  log "No supported package manager found. Install manually: ${missing[*]}"
}

add_source_line() {
  local rc_file="$1"
  local source_line="source \"${SHELL_SETTINGS_PATH}\""

  if [[ ! -f "$rc_file" ]]; then
    : >"$rc_file"
  fi

  if ! grep -Fqx "$source_line" "$rc_file"; then
    printf "%s\n" "$source_line" >>"$rc_file"
    log "Added prompt source to ${rc_file}"
  else
    log "Prompt source already present in ${rc_file}"
  fi
}

configure_shell() {
  case "${SHELL##*/}" in
    bash)
      add_source_line "${HOME}/.bash_profile"
      ;;
    zsh)
      add_source_line "${HOME}/.zshrc"
      ;;
    *)
      log "Unknown shell: ${SHELL##*/}"
      log "Add this line to your shell rc file:"
      log "source \"${SHELL_SETTINGS_PATH}\""
      ;;
  esac
}

main() {
  copy_ghostty_files
  install_dependencies
  configure_shell
  log "Setup complete. Restart your shell or run: source \"${SHELL_SETTINGS_PATH}\""
}

main "$@"
