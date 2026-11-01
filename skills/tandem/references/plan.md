# Getting a plan worth running

The run is only as good as the task split. A plan that hides a design decision inside task 4 costs a
rewrite of tasks 5 through 8, which is the failure this whole loop exists to catch early.

## Where a plan comes from

| The user said | Do this |
|---|---|
| a path to a plan file | read it |
| an issue id, or "take ISSUE-42" | read the issue and its comments, then write the plan |
| "plan and build X" | write the plan yourself, then confirm it before any agent starts |
| nothing — a plan is already in this conversation | write it to `plan.md` verbatim and confirm |

## What a task must carry

Each task needs four things, and a task missing any of them is not ready to hand to a model that
cannot ask questions.

- **A title** naming the change, not the area.
- **A description** stating what to do, in enough detail that two different models would build the
  same thing.
- **Acceptance** — the observable condition that says it is finished. "The store compiles" is not
  acceptance. "`SessionStore` is reached only through `SessionStoring`, and the existing tests pass
  unchanged" is.
- **The files it is expected to touch.** This is what keeps two tasks from fighting over the same
  file while one is under review and the next is being written.

## Shaping the split

- **One commit's worth each.** A task that cannot be committed on its own is two tasks.
- **Order by dependency.** Task N may rely on task N-1 being committed. It may not rely on task N+1.
- **No two adjacent tasks writing the same file.** Task N+1 starts while task N is under review, so
  overlapping files mean the fix for N lands on top of edits from N+1. Where an overlap is
  unavoidable, mark the later task `blocked_by` the earlier one and run them in sequence.
- **Put the risky decision first.** The loop's value is catching a bad premise at task 1 rather than
  at task 8, and that only works if the premise is in task 1.
- **Six to ten tasks is a comfortable run.** Past that, split the branch.

## Before starting

Show the user the task list, with the writer and reviewer named once above it, and get a yes. The
plan is the cheapest thing in the run to change.
