#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: agent.sh --runner <executor/model:effort> --workdir <dir> --prompt <file> --out <file>
                [--role writer|reviewer] [--repo <dir>] [--timeout <minutes>]

Spawns one headless model process. Executors come from the config: each names a kind
(claude, codex or cursor), the command to run and any environment it needs, so a second
account or a different CLI is a config entry rather than a code change.

A reviewer may not write — a claude kind loses its editing tools and may not bypass
permissions, a codex kind runs its sandbox read-only, a cursor kind runs in plan mode.

Effort defaults to medium. A cursor kind folds it into the model name, and ":default"
sends the name through untouched. Pass --repo when the workdir is a review worktree
outside the project, so per-project config still resolves. Exit 124 means the timeout
killed it.
EOF
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner=""; workdir=""; prompt=""; out=""; role="writer"; timeout_min=""; repo=""

while [ $# -gt 0 ]; do
  case "$1" in
    --runner)  runner="$2"; shift 2 ;;
    --workdir) workdir="$2"; shift 2 ;;
    --prompt)  prompt="$2"; shift 2 ;;
    --out)     out="$2"; shift 2 ;;
    --role)    role="$2"; shift 2 ;;
    --repo)    repo="$2"; shift 2 ;;
    --timeout) timeout_min="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$runner" ] && [ -n "$workdir" ] && [ -n "$prompt" ] && [ -n "$out" ] || usage
[ -f "$prompt" ] || { echo "agent.sh: no prompt file at $prompt" >&2; exit 2; }
[ -d "$workdir" ] || { echo "agent.sh: no workdir at $workdir" >&2; exit 2; }

export TANDEM_PROJECT_DIR="${repo:-${TANDEM_PROJECT_DIR:-$workdir}}"

executor="${runner%%/*}"
rest="${runner#*/}"
model="${rest%%:*}"
effort="${rest##*:}"
[ "$effort" = "$rest" ] && effort="medium"

spec="$("$script_dir/config.sh" | jq -c --arg e "$executor" '.executors[$e] // empty')"
[ -n "$spec" ] || {
  echo "agent.sh: no executor '$executor' in the config" >&2
  exit 2
}

kind="$(jq -r '.kind' <<<"$spec")"
cmd=()
while IFS= read -r part; do cmd+=("$part"); done < <(jq -r '.command[]' <<<"$spec")

while IFS= read -r kv; do
  [ -n "$kv" ] || continue
  export "${kv%%=*}=${kv#*=}"
done < <(jq -r --arg home "$HOME" '
  (.env // {}) | to_entries[] | "\(.key)=\(.value | sub("^~"; $home))"' <<<"$spec")

run() {
  if [ -z "$timeout_min" ]; then "$@"; return $?; fi

  for t in gtimeout timeout; do
    if command -v "$t" >/dev/null 2>&1; then
      "$t" --signal=TERM --kill-after=30s "${timeout_min}m" "$@"
      return $?
    fi
  done

  exec 3<&0
  "$@" <&3 &
  local pid=$! rc=0
  exec 3<&-
  ( sleep $(( timeout_min * 60 ))
    kill -TERM "$pid" 2>/dev/null
    sleep 30
    kill -KILL "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid" || rc=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  [ "$rc" = 143 ] && rc=124
  return "$rc"
}

mkdir -p "$(dirname "$out")"

case "$kind" in
  claude)
    args=(--print --model "$model" --effort "$effort")
    if [ "$role" = reviewer ]; then
      args+=(--permission-mode dontAsk --disallowed-tools Edit Write NotebookEdit)
    else
      args+=(--permission-mode "$(jq -r '.permission_mode // "acceptEdits"' <<<"$spec")")
    fi
    ( cd "$workdir" && run "${cmd[@]}" "${args[@]}" < "$prompt" ) > "$out"
    ;;
  codex)
    sandbox=workspace-write
    [ "$role" = reviewer ] && sandbox=read-only
    run "${cmd[@]}" exec \
      -m "$model" \
      -c model_reasoning_effort="$effort" \
      -s "$sandbox" \
      -C "$workdir" \
      --skip-git-repo-check \
      -o "$out" \
      - < "$prompt" > "${out}.log"
    ;;
  cursor)
    case "$effort" in
      default) cursor_model="$model" ;;
      *)       cursor_model="${model}-${effort}" ;;
    esac
    args=(--print --output-format text --trust --workspace "$workdir" --model "$cursor_model")
    if [ "$role" = reviewer ]; then
      args+=(--mode plan)
    else
      args+=(--force)
    fi
    ( cd "$workdir" && run "${cmd[@]}" "${args[@]}" < "$prompt" ) > "$out"
    ;;
  *)
    echo "agent.sh: executor '$executor' has unknown kind '$kind'" >&2
    exit 2
    ;;
esac
