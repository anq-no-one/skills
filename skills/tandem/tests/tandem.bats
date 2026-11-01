#!/usr/bin/env bats

setup() {
  SCRIPTS="$BATS_TEST_DIRNAME/../scripts"
  SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export ARGV_LOG="$SANDBOX/argv"
  mkdir -p "$XDG_CONFIG_HOME/tandem" "$SANDBOX/bin"

  for binary in claude codex cursor-agent revmux; do
    cat >"$SANDBOX/bin/$binary" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$ARGV_LOG"
printf 'CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}" >>"$ARGV_LOG"
printf 'PWD=%s\n' "$PWD" >>"$ARGV_LOG"
cat >/dev/null
echo "output from stub"
STUB
    chmod +x "$SANDBOX/bin/$binary"
  done
  export PATH="$SANDBOX/bin:/usr/bin:/bin"

  REPO="$SANDBOX/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.name test
  git -C "$REPO" config user.email test@example.com
  echo one >"$REPO/file"
  git -C "$REPO" add file
  git -C "$REPO" commit -qm one
  cd "$REPO"

  echo "do the thing" >"$SANDBOX/prompt"
}

teardown() {
  cd /
  git -C "$REPO" worktree prune 2>/dev/null || true
  rm -rf "$SANDBOX"
}

user_config() { echo "$1" >"$XDG_CONFIG_HOME/tandem/config.json"; }

project_config() {
  mkdir -p "$REPO/.tandem"
  echo "$1" >"$REPO/.tandem/config.json"
}

spawn() {
  run "$SCRIPTS/agent.sh" --workdir "$REPO" --prompt "$SANDBOX/prompt" \
    --out "$SANDBOX/out" "$@"
}

argv_has_pair() {
  grep -A1 -xF -- "$1" "$ARGV_LOG" | grep -qxF -- "$2"
}

@test "a project config beats the user config" {
  user_config '{"preset":"from-user"}'
  project_config '{"preset":"from-project"}'
  run "$SCRIPTS/config.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r .preset <<<"$output")" = "from-project" ]
}

@test "presets merge by name, so a project inherits the shipped ones" {
  project_config '{"presets":{"mine":{"writer":"claude/opus:high","reviewer":"codex/x:high"}}}'
  run "$SCRIPTS/config.sh"
  [ "$(jq -r '.presets | has("mine") and has("cheap")' <<<"$output")" = "true" ]
}

@test "the longest matching scope wins over a shorter one" {
  user_config "{\"scopes\":[
    {\"path\":\"$REPO\",\"config\":{\"preset\":\"deep\"}},
    {\"path\":\"$SANDBOX\",\"config\":{\"preset\":\"shallow\"}}
  ]}"
  run "$SCRIPTS/config.sh"
  [ "$(jq -r .preset <<<"$output")" = "deep" ]
  [ "$(jq -r '.matched_scopes | length' <<<"$output")" = "2" ]
}

@test "a scope does not match a sibling that shares its prefix" {
  user_config "{\"scopes\":[{\"path\":\"$REPO-other\",\"config\":{\"preset\":\"wrong\"}},
                            {\"path\":\"$SANDBOX/rep\",\"config\":{\"preset\":\"wrong\"}}]}"
  run "$SCRIPTS/config.sh"
  [ "$(jq -r .preset <<<"$output")" = "default" ]
}

@test "a tilde in a path expands to the home directory" {
  run "$SCRIPTS/config.sh"
  [ "$(jq -r .state_root <<<"$output")" = "$HOME/.cache/tandem/runs" ]
}

@test "pair prints the configured default when no preset is named" {
  project_config '{"preset":"cheap"}'
  run "$SCRIPTS/pair.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r .preset <<<"$output")" = "cheap" ]
  [ "$(jq -r .writer <<<"$output")" = "claude/sonnet:medium" ]
}

@test "pair refuses an unknown preset and lists the real ones" {
  run "$SCRIPTS/pair.sh" nope
  [ "$status" -eq 3 ]
  [[ "$output" == *"no preset 'nope'"* ]]
  [[ "$output" == *"astra"* ]]
}

@test "a claude reviewer cannot edit, even when the executor bypasses permissions" {
  user_config '{"executors":{"claude":{"kind":"claude","command":["claude"],"permission_mode":"bypassPermissions"}}}'
  spawn --runner claude/opus:high --role reviewer
  [ "$status" -eq 0 ]
  argv_has_pair --permission-mode dontAsk
  grep -qxF -- --disallowed-tools "$ARGV_LOG"
  grep -qxF Edit "$ARGV_LOG"
  grep -qxF Write "$ARGV_LOG"
  ! grep -qxF bypassPermissions "$ARGV_LOG"
}

@test "a claude writer uses the executor's permission mode" {
  user_config '{"executors":{"claude":{"kind":"claude","command":["claude"],"permission_mode":"bypassPermissions"}}}'
  spawn --runner claude/opus:high --role writer
  argv_has_pair --permission-mode bypassPermissions
  ! grep -qxF -- --disallowed-tools "$ARGV_LOG"
}

@test "a codex reviewer runs a read-only sandbox and a writer does not" {
  spawn --runner codex/gpt-x:high --role reviewer
  argv_has_pair -s read-only
  spawn --runner codex/gpt-x:high --role writer
  argv_has_pair -s workspace-write
}

@test "a cursor reviewer runs in plan mode and never forces" {
  spawn --runner cursor/gpt-x:low --role reviewer
  argv_has_pair --mode plan
  ! grep -qxF -- --force "$ARGV_LOG"
}

@test "cursor folds effort into the model name" {
  spawn --runner cursor/gpt-x:high
  argv_has_pair --model gpt-x-high
}

@test "cursor sends the model name untouched for the default effort" {
  spawn --runner cursor/gpt-x-high-fast:default
  argv_has_pair --model gpt-x-high-fast
}

@test "effort defaults to medium when the runner omits it" {
  spawn --runner claude/opus
  argv_has_pair --model opus
  argv_has_pair --effort medium
}

@test "an executor's env reaches the process with its tilde expanded" {
  user_config '{"executors":{"work":{"kind":"claude","command":["claude"],"env":{"CLAUDE_CONFIG_DIR":"~/.claude-work"}}}}'
  spawn --runner work/opus
  grep -qxF "CONFIG_DIR=$HOME/.claude-work" "$ARGV_LOG"
}

@test "a claude agent runs in its workdir and writes its output file" {
  spawn --runner claude/opus
  grep -qxF "PWD=$(pwd -P)" "$ARGV_LOG"
  [ "$(cat "$SANDBOX/out")" = "output from stub" ]
}

@test "a project config is still found from a review worktree via --repo" {
  project_config '{"executors":{"only-here":{"kind":"claude","command":["claude"]}}}'
  outside="$SANDBOX/worktree"
  mkdir "$outside"
  run "$SCRIPTS/agent.sh" --runner only-here/opus --workdir "$outside" --repo "$REPO" \
    --prompt "$SANDBOX/prompt" --out "$SANDBOX/out"
  [ "$status" -eq 0 ]
}

@test "an unknown executor fails instead of guessing" {
  spawn --runner ghost/opus
  [ "$status" -eq 2 ]
  [[ "$output" == *"no executor 'ghost'"* ]]
}

@test "an agent's non-zero exit reaches the caller" {
  printf '#!/usr/bin/env bash\nexit 7\n' >"$SANDBOX/bin/claude"
  spawn --runner claude/opus
  [ "$status" -eq 7 ]
}

@test "a review worktree stays pinned while the main tree moves" {
  pinned="$(git rev-parse HEAD)"
  run "$SCRIPTS/worktree.sh" add run-1 1 "$pinned"
  [ "$status" -eq 0 ]
  path="$output"
  echo two >file
  git commit -qam two
  [ "$(git -C "$path" rev-parse HEAD)" = "$pinned" ]
  [ "$(cat "$path/file")" = "one" ]
  [ -z "$(git -C "$path" branch --show-current)" ]
}

@test "prune removes a run's worktrees from disk and from git" {
  run "$SCRIPTS/worktree.sh" add run-1 1 HEAD
  path="$output"
  "$SCRIPTS/worktree.sh" prune run-1
  [ ! -e "$path" ]
  ! git worktree list | grep -qF "$path"
}

@test "a run id cannot escape the worktree root" {
  run "$SCRIPTS/worktree.sh" prune ../..
  [ "$status" -eq 2 ]
  [ -d "$HOME" ]
}

@test "preflight passes on a clean tree with every binary present" {
  run "$SCRIPTS/preflight.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok: true"* ]]
}

@test "preflight fails on a dirty tree" {
  echo dirty >file
  run "$SCRIPTS/preflight.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"tree must be clean"* ]]
}

@test "preflight names a missing executor binary" {
  rm "$SANDBOX/bin/codex"
  run "$SCRIPTS/preflight.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"codex: MISSING"* ]]
}

@test "preflight only needs revmux when the final review is on" {
  rm "$SANDBOX/bin/revmux"
  run "$SCRIPTS/preflight.sh"
  [ "$status" -ne 0 ]
  project_config '{"final_review":{"enabled":false}}'
  git add .tandem && git commit -qm config
  run "$SCRIPTS/preflight.sh"
  [ "$status" -eq 0 ]
}
