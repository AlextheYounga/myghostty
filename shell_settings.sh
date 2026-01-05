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

git_diff_stats() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
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

PS1="\[\e[36m\]\w\[\e[0m\]\[\e[92m\]\$(git_branch)\[\e[0m\]\$(git_diff_stats)\n$ "
