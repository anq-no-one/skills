---
name: tandem
description: Run a plan through two models working as a pair. One implements a task and commits it, the other reviews that commit in a pinned worktree while the first starts the next task, and findings return as fixup commits that squash at the end. Models, effort and the severity gate come from a named preset that a project can override. Use for "tandem", "run this plan with two models", "implement the plan with cross-review", "resume the tandem run" or "tandem status".
argument-hint: 'optional: a plan file, an issue id, or a description of what to build'
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, TaskStop, Monitor]
---

# tandem — two models, one plan, review that does not wait

One model implements a task and commits it. The other reviews that commit while the first is already
writing the next task. Findings come back as `fixup!` commits against the commit they belong to, and
the series squashes once, at the end.

Reviewing per task rather than per branch is the point. A design mistake in task 1, found after task
8, costs seven rewrites; found while task 2 is being written, it costs one.

```
task 1 ──write──▶ commit A ──────────────▶ fix A ─────────▶
                      │                      ▲
                      └──review (worktree@A)─┘
                                 ║
task 2 ─────────────────────write║──▶ commit B ──────────▶ fix B
                                 ║         │                 ▲
                                 ║         └──review(@B)─────┘
```

The main working tree has exactly one writer at any moment. Reviewers read detached worktrees pinned
at the commit under review, so nothing moves under them.

## Layout

| Path | What |
|---|---|
| `scripts/preflight.sh` | every binary, a clean tree, the resolved config |
| `scripts/config.sh` | merges skill defaults ← user config ← matching scopes ← `./.tandem/config.json` |
| `scripts/pair.sh [<preset>]` | prints `{preset, writer, reviewer}` for a preset, or the default |
| `scripts/agent.sh` | spawns one headless model; a reviewer cannot write |
| `scripts/worktree.sh` | adds, removes and prunes the reviewer worktrees |
| `references/plan.md` | how a plan is obtained and split |
| `references/prompts.md` | the writer, reviewer and fixer prompts |
| `references/state.md` | the run ledger, its statuses, how to resume |

## Non-negotiables

**1. Never poll.** Launch every agent with `run_in_background: true` and wait for the completion
notification. A writer takes 10-45 minutes and a reviewer 5-20. Sleeping and checking burns the
context this loop exists to protect.

**2. One writer at a time.** Two processes writing the same tree corrupt each other's work. The
lookahead is real parallelism between a writer and a *reviewer*, never between two writers.

**3. Every task commits.** The reviewer pins a worktree to the sha and the fixer targets it with
`--fixup`. A task that ends uncommitted stalls the run — say so and stop rather than continuing.

**4. Fixes never rewrite history while agents are running.** `git commit --fixup`, and one
`git rebase --autosquash` at the very end. A mid-run rebase moves shas a live reviewer is pinned to.

**5. Update the ledger before launching anything.** `run.json` is what makes an interrupted run
resumable, and an interruption is likely on a run this long.

**6. The user approves the plan before the first agent starts.** Everything after that is expensive.

## Workflow

### Step 0: Preflight

```bash
${CLAUDE_SKILL_DIR}/scripts/preflight.sh
```

Exits non-zero naming what is missing. A dirty tree fails it — the run's own commits have to be
separable from whatever was already uncommitted.

Record the starting commit and tell the user. It undoes the entire run: `git reset --hard <sha>`.

### Step 1: The plan

Read `references/plan.md`. Produce a numbered task list where each task carries a title, a
description, acceptance and the files it should touch.

One pair of models runs the whole plan. Resolve it once:

```bash
${CLAUDE_SKILL_DIR}/scripts/pair.sh [<preset>]
```

Pass a preset when the user named one: "build it with astra" means `astra`. With nothing named, `pair.sh` returns the configured default, which the project's own config
may have replaced. Never pick a preset the user did not ask for.

Present the plan as a task list, and name the writer and the reviewer once above it. Ask for a yes.
Changing the split now is free; changing it at task 6 is not.

### Step 2: Open the run

Write `run.json` and `plan.md` under `<state_root>/<run-id>/` per `references/state.md`. The run id is
the ticket key where there is one, otherwise the branch name.

### Step 3: The loop

Keep this schedule. `N` is the lowest task not yet `done` or `rejected`.

1. **Launch the writer for the first `pending` task** whose `blocked_by` is satisfied, in the repo
   root, background. Set the task to `writing`.
2. **On the writer's completion notification**, read the new commit with
   `git log --oneline -1 --format=%H`. Store it, set the task to `committed`.
3. **Immediately launch two things in the same turn:**
   - the **reviewer** for the just-committed task, in a worktree from
     `scripts/worktree.sh add <run-id> <task-id> <sha>`, background, set to `reviewing`
   - the **writer** for the next pending task, in the repo root, background, set to `writing`
4. **On a reviewer's completion notification**, parse the JSON from its output file, store
   `verdict` and `findings`, set the task to `reviewed`, and remove its worktree. If it has no gating
   finding, set it to `done`.
5. **When the main tree comes free** and some task is `reviewed` with a gating finding, launch the
   **fixer** for the oldest such task using that task's *writer* runner. Set it to `fixing`, and to
   `done` when it returns.
6. Repeat until every task is `done` or `rejected`.

Gating severities come from `gate` in the config, `critical` and `major` by default. A minor never
starts a fixer run; minors are what the loop is expected to leave behind for the final review.

The prompts are in `references/prompts.md`. Write each one to
`<state_root>/<run-id>/prompts/task-<n>-<role>.txt` before launching, so an interrupted run can
replay it.

Launching a writer and a reviewer looks like this — both in one turn, both backgrounded:

```bash
"${CLAUDE_SKILL_DIR}/scripts/agent.sh" \
  --runner "$(jq -r '.tasks[1].reviewer' run.json)" \
  --workdir "$wt" --repo "$repo" --role reviewer \
  --prompt "$run/prompts/task-2-reviewer.txt" \
  --out "$run/logs/task-2-reviewer.out" \
  --timeout 20
```

### Step 4: Degradation

An agent that exits non-zero, or exits 124 on its timeout, is **not** a clean result.

- a **writer** that failed left the tree in an unknown state. Stop the loop, show the user
  `git status` and the writer's log, and ask before touching anything.
- a **reviewer** that failed leaves its task `unverified`. Never record that as clean. Retry it once;
  on a second failure, mark it and carry it to the final review.
- **an empty or unparseable reviewer output** is a failure, not a clean review. A model that could
  not do what it was asked often returns nothing at all, and exit 0 does not contradict that. Retry
  once, then treat it as unverified.

### Step 5: Squash and final review

When every task is settled:

```bash
git rebase --autosquash --quiet <base>
```

Each `fixup!` folds into the commit it repaired and the branch is one clean commit per task. Show the
user `git log --oneline <base>..HEAD` and confirm the series reads right.

Then run [revmux](https://github.com/umputun/revmux) over the whole branch, as `final_review.profile` in the config names it — two fresh
models that wrote none of this, reading the branch end to end. Invoke the `revmux` skill rather than
rebuilding its half here.

### Step 6: Clean up

```bash
${CLAUDE_SKILL_DIR}/scripts/worktree.sh prune <run-id>
```

Keep `run.json` and the logs. They are the record of what each model found and are what makes the
next tuning pass possible.

## Resuming

"resume the tandem run" reads `run.json`, finds the first unsettled task and restarts from its
status, per `references/state.md`. A task left at `writing` or `fixing` needs the tree inspected
first — `git log --oneline <base>..HEAD` says whether the work landed before the interruption.

## Configuration

`scripts/config.sh` merges four layers, last wins: the skill's `config.json`, the user's
`~/.config/tandem/config.json`, every **scope** in that file whose path contains the repository, and
finally `./.tandem/config.json` in the repository itself.

A scope configures a whole tree of repositories from one place, which is how a monorepo-shaped
checkout with many worktrees gets one setup without a config file in each one. Scopes match on the
repository root, the longest path wins, and the resolved config reports which ones matched under
`matched_scopes`.

```json
{
  "scopes": [
    {
      "path": "~/Projects/acme",
      "config": {
        "preset": "acme",
        "presets": { "acme": { "writer": "claude-work/opus:medium",
                               "reviewer": "cursor/gpt-5.6-sol:medium" } },
        "worktree_root": "~/Projects/acme/worktrees/tandem"
      }
    }
  ]
}
```

A worktree of a scoped repository still sits under that path, so it resolves to the same setup.

| Key | What it controls |
|---|---|
| `preset` | which preset runs when the user names none |
| `executors.<name>` | the kind, command, env and writer permission mode of one executor |
| `scopes` | per-path-tree overrides, matched against the repository root |
| `presets.<name>` | the writer and reviewer runners that preset uses |
| `gate` | severities that start a fixer run |
| `timeouts` | per-role minutes before an agent is killed |
| `lookahead` | how many tasks ahead the writer may run; `1` is the pair from the diagram |
| `final_review` | whether to finish with revmux, and under which profile |

### Runner strings

A runner is `<executor>/<model>:<effort>`, the same vocabulary revmux uses. Effort is `low`,
`medium`, `high`, `xhigh` or `max`, and defaults to `medium` when the string omits it.

An executor is a config entry, not a hardcoded name. It declares a `kind` that decides the flags, the
`command` to run, and optionally the `env` it needs and the `permission_mode` its **writer** uses.
That is how a second account, or the same model through a different CLI, becomes configuration:

```json
{
  "executors": {
    "claude-work": {
      "kind": "claude",
      "command": ["claude"],
      "env": { "CLAUDE_CONFIG_DIR": "~/.claude-work" },
      "permission_mode": "bypassPermissions"
    }
  }
}
```

| Kind | Binary it usually runs | Models | How a reviewer is held read-only |
|---|---|---|---|
| `claude` | `claude --print` | `opus`, `fable`, `sonnet`, `haiku` | `dontAsk` plus its editing tools removed |
| `codex` | `codex exec` | whatever Codex serves | its own sandbox runs `read-only` |
| `cursor` | `cursor-agent --print` | `cursor-agent --list-models` | plan mode |

**`permission_mode` never reaches a reviewer.** A claude reviewer always runs `dontAsk` with its
editing tools removed, whatever the executor declares, because `bypassPermissions` hands the model a
shell and a read-only review that can write is not a review.

`cursor` reaches models the other two do not serve, or the same model through a different account.
It needs `cursor-agent login` once.

Cursor bakes the effort into the model name rather than taking it as a flag, so `agent.sh` composes
the two: `cursor/gpt-5.6-sol:medium` calls `gpt-5.6-sol-medium`, and `cursor/claude-opus-5:high`
calls `claude-opus-5-high`. Write the effort as `default` to send the name through untouched, which
is how you reach a variant the pattern does not build — `cursor/gpt-5.6-sol-high-fast:default`.
Not every family offers every level: check `cursor-agent --list-models` before inventing one.

### Shipped presets

| Preset | Writer | Reviewer |
|---|---|---|
| `default` | `claude/opus:medium` | `codex/gpt-5.6-sol:medium` |
| `astra` | `codex/gpt-6-astra:high` | `claude/fable:high` |
| `cheap` | `claude/sonnet:medium` | `codex/gpt-5.6-sol:low` |

A project adds its own by writing `./.tandem/config.json`. Presets merge by name, so a project
defines what it needs and inherits the rest:

```json
{
  "preset": "sol-via-cursor",
  "presets": {
    "sol-via-cursor": {
      "writer": "cursor/gpt-5.6-sol:medium",
      "reviewer": "cursor/claude-opus-5:medium"
    }
  },
  "project_rules": "SwiftUI only. No UIKit in new code."
}
```

`project_rules` is pasted into every reviewer prompt at `{{PROJECT_RULES}}`.
