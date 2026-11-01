#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
preset="${1:-}"
ok=true

need() {
  if path="$(command -v "$1" 2>/dev/null)"; then
    echo "$1: $path"
  else
    echo "$1: MISSING${2:+ — $2}"
    ok=false
  fi
}

need git
need jq

config="$("$script_dir/config.sh")"
pair="$("$script_dir/pair.sh" ${preset:+"$preset"})"
echo "preset: $(jq -r .preset <<<"$pair")"
echo "writer: $(jq -r .writer <<<"$pair")"
echo "reviewer: $(jq -r .reviewer <<<"$pair")"
echo "presets available: $(jq -r '.presets | keys | join(", ")' <<<"$config")"

for runner in $(jq -r '.writer, .reviewer' <<<"$pair"); do
  name="${runner%%/*}"
  spec="$(jq -c --arg e "$name" '.executors[$e] // empty' <<<"$config")"
  if [ -z "$spec" ]; then
    echo "$name: UNDEFINED executor — add it under .executors"
    ok=false
    continue
  fi
  binary="$(jq -r '.command[0]' <<<"$spec")"
  env_note="$(jq -r '(.env // {}) | to_entries | map("\(.key)=\(.value)") | join(" ")' <<<"$spec")"
  need "$binary" "${env_note:+env: $env_note}"
done

if [ "$(jq -r '.final_review.enabled' <<<"$config")" = true ]; then
  need revmux "brew install umputun/apps/revmux"
fi

if command -v gtimeout >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1; then
  echo "timeout: coreutils"
else
  echo "timeout: built-in watchdog"
fi

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "repo: $(git rev-parse --show-toplevel)"
  echo "branch: $(git branch --show-current)"
  dirty="$(git status --porcelain | wc -l | tr -d ' ')"
  echo "dirty files: $dirty"
  [ "$dirty" = 0 ] || { echo "tree must be clean before a run"; ok=false; }
else
  echo "repo: MISSING — run from inside a git repository"
  ok=false
fi

echo "ok: $ok"
[ "$ok" = true ]
