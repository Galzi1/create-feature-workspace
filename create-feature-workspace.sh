#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create-feature-workspace.sh --feature-name NAME --config-file PATH [--workspaces-root PATH]

Arguments:
  --feature-name    Name of the feature branch/workspace to create
  --config-file     Path to INI file defining repositories
  --workspaces-root Root directory for feature workspaces (default: ~/workspaces)
  --help            Show this help
USAGE
}

feature_name=""
config_file=""
workspaces_root="~/workspaces"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-name)
      [[ $# -ge 2 ]] || { echo "Error: --feature-name requires a value" >&2; exit 1; }
      feature_name="$2"
      shift 2
      ;;
    --config-file)
      [[ $# -ge 2 ]] || { echo "Error: --config-file requires a value" >&2; exit 1; }
      config_file="$2"
      shift 2
      ;;
    --workspaces-root)
      [[ $# -ge 2 ]] || { echo "Error: --workspaces-root requires a value" >&2; exit 1; }
      workspaces_root="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$feature_name" ]] || { echo "Error: --feature-name is required" >&2; usage >&2; exit 1; }
[[ -n "$config_file" ]] || { echo "Error: --config-file is required" >&2; usage >&2; exit 1; }
[[ -f "$config_file" ]] || { echo "Error: config file not found: $config_file" >&2; exit 1; }

expand_path() {
  local p="$1"
  if [[ "$p" == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ "$p" == ~/* ]]; then
    printf '%s/%s\n' "$HOME" "${p#~/}"
  else
    printf '%s\n' "$p"
  fi
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

workspaces_root="$(expand_path "$workspaces_root")"
workspace_dir="$workspaces_root/$feature_name"
mkdir -p "$workspace_dir"

current_section=""
repo_name=""
repo_path=""
repo_branch=""
repo_count=0

create_worktree() {
  local section="$1"
  local name="$2"
  local path="$3"
  local branch="$4"

  [[ -n "$section" ]] || return 0
  [[ -n "$name" ]] || { echo "Error: section [$section] is missing required key: name" >&2; exit 1; }
  [[ -n "$path" ]] || { echo "Error: section [$section] is missing required key: path" >&2; exit 1; }
  [[ -n "$branch" ]] || { echo "Error: section [$section] is missing required key: branch" >&2; exit 1; }

  path="$(expand_path "$path")"
  [[ -d "$path" ]] || { echo "Error: repository path does not exist for [$section]: $path" >&2; exit 1; }
  git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Error: path is not a git repository for [$section]: $path" >&2
    exit 1
  }

  local destination="$workspace_dir/$name"
  if [[ -e "$destination" ]]; then
    echo "Error: destination already exists for [$section]: $destination" >&2
    exit 1
  fi

  echo "Creating worktree for [$section] -> $destination (branch: $feature_name, base: $branch)"
  git -C "$path" worktree add -b "$feature_name" "$destination" "$branch"
  repo_count=$((repo_count + 1))
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim "$raw_line")"

  [[ -z "$line" ]] && continue
  [[ "$line" == ';'* || "$line" == '#'* ]] && continue

  if [[ "$line" =~ ^\[(.*)\]$ ]]; then
    create_worktree "$current_section" "$repo_name" "$repo_path" "$repo_branch"
    current_section="${BASH_REMATCH[1]}"
    repo_name=""
    repo_path=""
    repo_branch=""
    continue
  fi

  if [[ "$line" == *=* ]]; then
    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    case "$key" in
      name) repo_name="$value" ;;
      path) repo_path="$value" ;;
      branch) repo_branch="$value" ;;
    esac
  fi
done < "$config_file"

create_worktree "$current_section" "$repo_name" "$repo_path" "$repo_branch"

if [[ "$repo_count" -eq 0 ]]; then
  echo "Error: no repository sections found in config file" >&2
  exit 1
fi

echo
echo "Workspace created: $workspace_dir"
echo "Repositories added: $repo_count"
echo "Next step: cd \"$workspace_dir\" && claude"