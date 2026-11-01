---
name: land-my-prs
description: Move every open PR I authored one stage closer to the default branch by fixing red checks, answering review threads, getting approved PRs a QA build, and merging what QA verified on the right build. Use when asked to take care of, land, push forward, babysit or ship my PRs, or to merge what passed QA.
---

# Land My PRs

Walk every open PR you authored, one at a time, and move each one stage further. A PR **lands** when it is merged and its ticket is closed.

Status names below are examples. Use whatever the project's tracker calls them.

## 1. Collect

```bash
gh pr list --repo <owner>/<repo> --author @me --state open \
  --json number,title,headRefName,headRefOid,baseRefName,reviewDecision,mergeable,isDraft
```

Read each PR's ticket and its comments. Work each PR in its own worktree, detached from `origin/<headRefName>`, and remove the worktree when that PR is finished. When subagents take PRs, run at most five at once.

## 2. Per PR, in this order

Stop at the first stage the PR has not passed. That stage is this run's work for the PR.

### 2.1 Checks green

A red test means fixing the test or the code it caught. A red title, coverage or merge gate means fixing that. Done when the new head is green.

### 2.2 Review threads

Every unresolved thread ends in one of two states:

- **fixed**: the change is pushed and the thread gets a reply naming the commit
- **declined**: a reply gives the reason, and the thread stays open for the reviewer to resolve

Done when every unresolved, non-outdated thread has your reply as its last comment.

### 2.3 Approval

Without `reviewDecision == APPROVED`, move the ticket to `PR Review` if it is earlier, and report the PR as awaiting review.

### 2.4 QA build

An approved PR needs a QA build of its head commit. If the project tags builds, check for one:

```bash
git tag --points-at <headRefOid> --list '<qa-tag-pattern>'
```

No build means triggering one the way the project does. Once it exists, move the ticket to `QA`.

### 2.5 QA verdict

Only a ticket in `QA Complete` goes on. QA's comment should name the build it tested.

The tested build is **right** when its commit carries the same PR changes as the head, so that only clean merges from the default branch came after it. Comparing SHAs would reject those merges, so compare patch IDs:

```bash
pr_patch() { git diff "$(git merge-base origin/main "$1")" "$1" | git patch-id --stable | cut -d' ' -f1; }
[ "$(pr_patch <tested sha>)" = "$(pr_patch <headRefOid>)" ]
```

A mismatch, or no build named, means the head changed after QA. Build again, post what to test on the new build, and report the PR as needing a re-test.

### 2.6 Merge

Merge only when the ticket is `QA Complete` on this head build. The owner merges everything else. Re-read the ticket status and `mergeable` right before merging. Retarget any PR stacked on this branch first, because `--delete-branch` closes it.

```bash
gh pr list --repo <owner>/<repo> --base <headRefName>
gh pr edit <N> --repo <owner>/<repo> --base main
gh pr merge <N> --repo <owner>/<repo> --squash --delete-branch
```

Then close the ticket if the tracker did not do it on merge.

## 3. Report

One line per PR: the stage it reached this run, what you did, and the blocker that remains (reviewer, QA re-test, or a decision).
