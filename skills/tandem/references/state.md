# The run ledger

One run is one branch. Its state lives outside the repository, under `state_root` from the config,
so nothing derived lands in the tree being changed.

```
~/.cache/tandem/runs/<run-id>/
├── run.json          the ledger below
├── plan.md           the plan, as tasks
├── prompts/          task-1-writer.txt, task-1-reviewer.txt, task-1-fixer.txt
└── logs/             task-1-writer.out, task-1-reviewer.out, ...
```

`run.json`:

```json
{
  "run_id": "ISSUE-42",
  "repo": "/home/me/projects/app",
  "branch": "feature/ISSUE-42-session-store",
  "base": "9f3a1c2",
  "preset": "default",
  "started": "2026-09-20T19:00:00Z",
  "tasks": [
    {
      "id": 1,
      "title": "Extract the session store behind a protocol",
      "description": "...",
      "acceptance": "...",
      "files": ["Sources/Session/Store.swift"],
      "writer": "claude/fable:high",
      "reviewer": "codex/gpt-6-astra:high",
      "status": "pending",
      "commit": null,
      "verdict": null,
      "findings": []
    }
  ]
}
```

## Status values

| status | meaning |
|---|---|
| `pending` | nobody has started it |
| `writing` | the writer holds the main tree |
| `committed` | the writer committed; the sha is in `commit` |
| `reviewing` | the reviewer is reading a worktree pinned at that sha |
| `reviewed` | findings are in `findings` and `verdict` is set |
| `fixing` | the writer is repairing it in the main tree |
| `done` | clean, or every gating finding fixed |
| `rejected` | the writer argued a finding down; the reason is in `findings[].rejected` |

A task is finished only at `done` or `rejected`. Any other status on an interrupted run is where the
run resumes.

## Resuming

Read `run.json`, find the first task not at `done` or `rejected`, and restart from its status. A task
at `writing` or `fixing` needs the main tree checked first — `git log --oneline <base>..HEAD` says
whether the work landed before the interruption.

## Invariants

- **One writer at a time.** Only one process ever holds the main working tree. Reviewers read
  detached worktrees and never write.
- **One commit per task.** The reviewer needs a sha to pin a worktree to, and the fixer needs a
  target for `--fixup`.
- **Fixes never rewrite history mid-run.** They land as `fixup!` commits and squash once, at the end.
- **The ledger is the truth.** Update `run.json` after every state change, before launching the next
  process, so an interruption is always recoverable.
