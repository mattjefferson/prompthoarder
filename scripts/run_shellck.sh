#!/usr/bin/env bash
set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellck: shellcheck not found (install with brew install shellcheck)" >&2
  exit 1
fi

debug() {
  [[ -n "${SHELLCK_DEBUG:-}" ]] && echo "shellck: $*" >&2
  return 0
}

is_shell_file() {
  local path="$1"
  case "$path" in
    *.sh|*.bash|*.zsh|*.ksh|*.command)
      debug "matched by extension: $path"
      return 0
      ;;
  esac
  if [[ -f "$path" ]]; then
    local first
    first="$(head -n 1 "$path" 2>/dev/null || true)"
    # Match shebangs: #!/bin/bash, #!/usr/bin/env bash, etc.
    # Using glob patterns instead of \b (not portable in bash ERE)
    if [[ "$first" == "#!/"*"/sh" ]] ||
       [[ "$first" == "#!/"*"/sh "* ]] ||
       [[ "$first" == "#!/"*"/bash" ]] ||
       [[ "$first" == "#!/"*"/bash "* ]] ||
       [[ "$first" == "#!/"*"/zsh" ]] ||
       [[ "$first" == "#!/"*"/zsh "* ]] ||
       [[ "$first" == "#!/"*"/ksh" ]] ||
       [[ "$first" == "#!/"*"/ksh "* ]] ||
       [[ "$first" == "#!/"*"env sh" ]] ||
       [[ "$first" == "#!/"*"env sh "* ]] ||
       [[ "$first" == "#!/"*"env bash" ]] ||
       [[ "$first" == "#!/"*"env bash "* ]] ||
       [[ "$first" == "#!/"*"env zsh" ]] ||
       [[ "$first" == "#!/"*"env zsh "* ]] ||
       [[ "$first" == "#!/"*"env ksh" ]] ||
       [[ "$first" == "#!/"*"env ksh "* ]]; then
      debug "matched by shebang: $path"
      return 0
    fi
    debug "no match: $path (shebang: ${first:-<empty>})"
  fi
  return 1
}

add_targets_from_dir() {
  local dir="$1"
  while IFS= read -r -d '' f; do
    if is_shell_file "$f"; then
      TARGETS+=("$f")
    fi
  done < <(find "$dir" -type f -print0)
}

add_target() {
  local path="$1"
  if [[ -d "$path" ]]; then
    add_targets_from_dir "$path"
    return
  fi
  if [[ -f "$path" ]]; then
    if is_shell_file "$path"; then
      TARGETS+=("$path")
    fi
    return
  fi
  echo "shellck: path not found: $path" >&2
  exit 2
}

TARGETS=()
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    add_target "$arg"
  done
else
  if [[ -d "scripts" ]]; then
    add_targets_from_dir "scripts"
  else
    echo "shellck: no targets provided and scripts/ not found" >&2
    exit 2
  fi
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "shellck: no shell scripts found" >&2
  exit 0
fi

shellcheck -x "${TARGETS[@]}"
