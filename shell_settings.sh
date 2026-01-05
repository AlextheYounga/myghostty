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

_ghostty_prompt_command() {
  git_prompt_update_async
  if [[ -n "${GHOSTTY_ORIGINAL_PROMPT_COMMAND}" ]]; then
    eval "${GHOSTTY_ORIGINAL_PROMPT_COMMAND}"
  fi
}

PROMPT_COMMAND="_ghostty_prompt_command"

PS1="\[\e[36m\]\w\[\e[0m\]\[\e[92m\]\$(git_branch)\[\e[0m\]\$(git_prompt_read_cache)\n$ "
