#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

fail() {
  echo "$1: $2" >&2
  failed=1
}

frontmatter_value() {
  awk -v key="$2" '
    NR == 1 { next }
    /^---$/ { exit }
    index($0, key ": ") == 1 { print substr($0, length(key) + 3); exit }
  ' "$1"
}

for dir in "$root"/skills/*/; do
  skill="$(basename "$dir")"
  file="$dir/SKILL.md"

  [ -f "$file" ] || { fail "$skill" "no SKILL.md"; continue; }
  [ "$(head -1 "$file")" = "---" ] || { fail "$skill" "no frontmatter"; continue; }

  name="$(frontmatter_value "$file" name)"
  description="$(frontmatter_value "$file" description)"

  [ "$name" = "$skill" ] || fail "$skill" "name '$name' does not match its directory"
  [ -n "$description" ] || fail "$skill" "empty description"
  [ "${#description}" -le 1024 ] || fail "$skill" "description is ${#description} characters, the limit is 1024"

  while IFS= read -r reference; do
    [ -e "$dir/$reference" ] || fail "$skill" "points at missing file $reference"
  done < <(grep -oE "\`(references|scripts)/[A-Za-z0-9._-]+\`" "$file" | tr -d "\`" | sort -u)
done

exit "$failed"
