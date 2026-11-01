#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
user_config="${XDG_CONFIG_HOME:-$HOME/.config}/tandem/config.json"

if [ -n "${TANDEM_PROJECT_DIR:-}" ]; then
  target="$TANDEM_PROJECT_DIR"
else
  target="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
project_config="$target/.tandem/config.json"

layer() { [ -f "$1" ] && cat "$1" || echo '{}'; }

jq -n \
  --argjson skill   "$(cat "$skill_dir/config.json")" \
  --argjson user    "$(layer "$user_config")" \
  --argjson project "$(layer "$project_config")" \
  --arg home "$HOME" \
  --arg target "$target" '
    def expand: if type == "string" then sub("^~"; $home) else . end;

    ($skill * $user) as $base
    | [ ($base.scopes // [])[]
        | (.path | expand) as $prefix
        | select($target == $prefix or ($target | startswith($prefix + "/")))
      ]
      | sort_by(.path | length) as $matched
    | (reduce $matched[] as $s ($base; . * $s.config)) as $scoped
    | ($scoped * $project)
    | .worktree_root |= expand
    | .state_root    |= expand
    | .matched_scopes = [$matched[].path]
    | .target = $target
  '
