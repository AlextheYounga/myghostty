#!/usr/bin/env bash

# Ghostty built in shell integrations
if [ -n "${GHOSTTY_RESOURCES_DIR}" ]; then
    builtin source "${GHOSTTY_RESOURCES_DIR}/shell-integration/bash/ghostty.bash"
fi


# Custom shell configurations
git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
  local branch
  branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
  printf " (%s)" "$branch"
}

ghostty_prompt_env() {
  if [[ -n "${VIRTUAL_ENV-}" ]]; then
    printf " [%s]" "$(basename "$VIRTUAL_ENV")"
  elif [[ -n "${CONDA_DEFAULT_ENV-}" ]]; then
    printf " [%s]" "$CONDA_DEFAULT_ENV"
  fi
}

ghostty_prompt_status() {
  local status="$1"
  if (( status != 0 )); then
    local np_start=$'\001'
    local np_end=$'\002'
    printf " ${np_start}\e[31m${np_end}✗%s${np_start}\e[0m${np_end}" "$status"
  fi
}

ghostty_prompt_duration() {
  local start="$1"
  local now duration
  now=$(date +%s)
  duration=$((now - start))
  if (( duration >= 2 )); then
    local np_start=$'\001'
    local np_end=$'\002'
    printf " ${np_start}\e[90m${np_end}%ss${np_start}\e[0m${np_end}" "$duration"
  fi
}

git_prompt_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ghostty"
git_prompt_cache_file="${git_prompt_cache_dir}/git_prompt_cache"
git_prompt_lock_dir="${git_prompt_cache_dir}/git_prompt_lock"
git_prompt_cache_ttl_seconds=1

git_prompt_stat_mtime() {
  if stat -f "%m" "$1" >/dev/null 2>&1; then
    stat -f "%m" "$1"
  else
    stat -c "%Y" "$1"
  fi
}

git_prompt_build_stats() {
  local added=0
  local deleted=0
  local a d _path
  while read -r a d _path; do
    [[ $a == "-" ]] && a=0
    [[ $d == "-" ]] && d=0
    added=$((added + a))
    deleted=$((deleted + d))
  done < <(git diff --numstat; git diff --cached --numstat)

  if (( added > 0 || deleted > 0 )); then
    local np_start=$'\001'
    local np_end=$'\002'
    printf " ${np_start}\e[32m${np_end}+%s${np_start}\e[0m${np_end}${np_start}\e[31m${np_end}-%s${np_start}\e[0m${np_end}" \
      "$added" "$deleted"
  fi
}

git_prompt_update_async() {
  local now last
  now=$(date +%s)

  mkdir -p "$git_prompt_cache_dir"

  if [[ -f "$git_prompt_cache_file" ]]; then
    last=$(git_prompt_stat_mtime "$git_prompt_cache_file")
    if (( now - last < git_prompt_cache_ttl_seconds )); then
      return
    fi
  fi

  if mkdir "$git_prompt_lock_dir" 2>/dev/null; then
    (
      trap 'rmdir "$git_prompt_lock_dir" >/dev/null 2>&1' EXIT
      tmp_file="${git_prompt_cache_file}.tmp.$$"

      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git_prompt_build_stats >"$tmp_file"
      else
        : >"$tmp_file"
      fi
      mv "$tmp_file" "$git_prompt_cache_file"
    ) >/dev/null 2>&1 &
    if [[ -o monitor ]]; then
      disown >/dev/null 2>&1 || true
    fi
  fi
}

git_prompt_read_cache() {
  [[ -f "$git_prompt_cache_file" ]] || return
  cat "$git_prompt_cache_file"
}

if [[ -z "${GHOSTTY_ORIGINAL_PROMPT_COMMAND+x}" ]]; then
  GHOSTTY_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND-}"
fi

__ghostty_cmd_start=${__ghostty_cmd_start:-$(date +%s)}
__ghostty_in_prompt=""
__ghostty_last_histnum=""

__ghostty_debug_trap() {
  [[ -n "${__ghostty_in_prompt}" ]] && return
  __ghostty_cmd_start=$(date +%s)
}

trap '__ghostty_debug_trap' DEBUG

_ghostty_prompt_command() {
  local last_status="$?"
  __ghostty_in_prompt=1
  local duration=""
  local histnum=""
  if histnum="$(history 1 2>/dev/null)"; then
    histnum="$(printf "%s" "$histnum" | sed 's/^ *\([0-9]*\).*/\1/')"
  fi
  if [[ -n "$histnum" && "$histnum" != "$__ghostty_last_histnum" ]]; then
    duration="$(ghostty_prompt_duration "$__ghostty_cmd_start")"
  fi
  git_prompt_update_async
  if [[ -n "${GHOSTTY_ORIGINAL_PROMPT_COMMAND}" ]]; then
    eval "${GHOSTTY_ORIGINAL_PROMPT_COMMAND}"
  fi
  __ghostty_in_prompt=""
  GHOSTTY_PROMPT_STATUS="$(ghostty_prompt_status "$last_status")"
  GHOSTTY_PROMPT_DURATION="$duration"
  __ghostty_cmd_start=$(date +%s)
  __ghostty_last_histnum="$histnum"
}

PROMPT_COMMAND="_ghostty_prompt_command"

PS1="\[\e[36m\]╭\[\e[0m\] \[\e[36m\]\w\[\e[0m\]\$(ghostty_prompt_env)\[\e[92m\]\$(git_branch)\[\e[0m\]\$(git_prompt_read_cache)\${GHOSTTY_PROMPT_STATUS}\${GHOSTTY_PROMPT_DURATION}\n\[\e[36m\]╰\[\e[0m\] $ "

# Bash completions
if [[ -r "/etc/bash_completion" ]]; then
  source "/etc/bash_completion"
elif [[ -r "/etc/profile.d/bash_completion.sh" ]]; then
  source "/etc/profile.d/bash_completion.sh"
elif [[ -r "/usr/share/bash-completion/bash_completion" ]]; then
  source "/usr/share/bash-completion/bash_completion"
elif command -v brew >/dev/null 2>&1; then
  brew_prefix="$(brew --prefix)"
  if [[ -r "${brew_prefix}/opt/bash-completion@2/etc/profile.d/bash_completion.sh" ]]; then
    source "${brew_prefix}/opt/bash-completion@2/etc/profile.d/bash_completion.sh"
  fi
fi

# Quality-of-life defaults (only if installed)
if command -v bat >/dev/null 2>&1; then
  alias cat="bat"
elif command -v batcat >/dev/null 2>&1; then
  alias bat="batcat"
  alias cat="batcat"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first --icons=auto"
fi

if command -v delta >/dev/null 2>&1; then
  export GIT_PAGER="delta"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

if command -v fzf >/dev/null 2>&1; then
  if [[ -r "${HOME}/.fzf.bash" ]]; then
    source "${HOME}/.fzf.bash"
  elif [[ -r "/usr/share/doc/fzf/examples/completion.bash" ]]; then
    source "/usr/share/doc/fzf/examples/completion.bash"
  elif command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix)"
    if [[ -r "${brew_prefix}/opt/fzf/shell/completion.bash" ]]; then
      source "${brew_prefix}/opt/fzf/shell/completion.bash"
    fi
  fi

  __ghostty_fzf_history() {
    local selected
    selected="$(history | sed 's/^ *[0-9]* *//' | fzf --tac --height=40% --reverse --prompt='history> ')" || return
    READLINE_LINE="$selected"
    READLINE_POINT="${#READLINE_LINE}"
  }
  bind -x '"\C-r": __ghostty_fzf_history'
fi
