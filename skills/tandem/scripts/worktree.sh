#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: worktree.sh add <run-id> <task-id> <commit-ish>   prints the worktree path
       worktree.sh remove <run-id> <task-id>
       worktree.sh prune <run-id>

A reviewer reads a detached worktree pinned at the commit under review, so the writer
may keep editing the main tree at the same time.
EOF
  exit 2
}

[ $# -ge 2 ] || usage

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$("$script_dir/config.sh" | jq -r .worktree_root)"
repo="$(git rev-parse --show-toplevel)"
action="$1"; run_id="$2"

[ -n "$run_id" ] || { echo "worktree.sh: empty run id" >&2; exit 2; }
case "$run_id" in */*|.|..) echo "worktree.sh: bad run id '$run_id'" >&2; exit 2 ;; esac

case "$action" in
  add)
    [ $# -eq 4 ] || usage
    path="$root/$run_id/task-$3"
    if [ -d "$path" ]; then
      git -C "$repo" worktree remove --force "$path" >/dev/null 2>&1 || rm -rf "$path"
    fi
    mkdir -p "$(dirname "$path")"
    git -C "$repo" worktree add --detach --quiet "$path" "$4"
    echo "$path"
    ;;
  remove)
    [ $# -eq 3 ] || usage
    path="$root/$run_id/task-$3"
    git -C "$repo" worktree remove --force "$path" >/dev/null 2>&1 || rm -rf "$path"
    ;;
  prune)
    rm -rf "${root:?}/$run_id"
    git -C "$repo" worktree prune
    ;;
  *) usage ;;
esac
