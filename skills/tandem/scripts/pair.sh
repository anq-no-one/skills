#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: pair.sh [<preset>]

Prints {preset, writer, reviewer} for the named preset, or for the configured
default when none is named. Exits 3 when the preset does not exist.
EOF
  exit 2
}

[ $# -le 1 ] || usage
[ "${1:-}" = "-h" ] && usage

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$("$script_dir/config.sh")"
name="${1:-$(jq -r '.preset // "default"' <<<"$config")}"

if ! jq -e --arg n "$name" '.presets[$n]' <<<"$config" >/dev/null; then
  echo "pair.sh: no preset '$name'. Available: $(jq -r '.presets | keys | join(", ")' <<<"$config")" >&2
  exit 3
fi

jq --arg n "$name" '{preset: $n, writer: .presets[$n].writer, reviewer: .presets[$n].reviewer}' <<<"$config"
