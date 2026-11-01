---
name: work-the-queue
description: Turn "what should I work on" into a ranked list from the issue tracker and GitHub, then drive every item with parallel subagents and report as each lands. Use when asked what to do next, for a start-of-day review, to "work the queue", "do all of that", or to take care of everything assigned to me.
---

# work-the-queue

The user is the engineer and you are the dispatcher. One pass of recon, one ranked list, then one subagent per independent item while you stay free to answer the user.

Status names below are examples. Use whatever the project's tracker calls them.

## 1. Recon in one pass

Collect every fact in one round of parallel calls. Read-only, change nothing yet.

Probe the tracker first with one cheap call. When it fails, the connector needs re-auth: stop, tell the user what failed, and dispatch nothing. A round without the tracker ranks the wrong items and moves no tickets, and an unattended run otherwise spends the whole day on it.

- Tracker: issues assigned to me in all states, unread notifications, and new high-priority items in my team's backlog.
- GitHub: my open PRs with `reviewDecision`, `mergeable`, `statusCheckRollup` and unresolved review threads (GraphQL `reviewThreads.isResolved`), plus PRs requesting my review.
- Default branch health: the latest run of every push workflow and scheduled lane, with the failing test names of each red run read from its log (`gh run view <id> --log-failed`). Compare them with the previous run of the same lane, so a newly failing test reads as new.
- Any red check gets its failing step and first real error line now, in the same pass, so the list ranks it correctly.

Recon ends when every in-flight ticket has its PR, every open PR has its ticket and check state, and every test red on the default branch has its name and the run it last failed in.

## 2. Rank

Order by who is waiting:

0. **Default branch red**: one item per failing test, above everything else, because every PR and every QA build inherits it. An item names its owner: an open PR that fixes it, a dispatched agent, or the user's stated decision. A test with none is dispatched this round.
1. **Blocked by me, others waiting**: a QA build that fails to upload, a review someone requested, a red check on a PR that QA needs.
2. **Merge-ready**: QA passed, PR approved, checks green.
3. **QA handoff**: fixes pushed after a QA round while the tickets still sit in review, or no note on what to test.
4. **Coding**: in progress with no PR, newly assigned high-priority bugs, regressions QA filed against one of my builds.
5. **Stale**: in progress with no activity for a week, and low-priority bugs. Group small ones so one PR carries two tickets.

Cap the visible list at five and keep the rest for the next round. Reply with the list, one line of evidence per item, and one next action. When the user only asked what to do, stop here. "Do it" starts the dispatch.

## 3. Dispatch

One subagent per independent item, in the background, at most five at once. Launch the first five in one message and start the next only after one hands back, because a large batch drains the spend limit mid-round. The user decides which items to skip, and that holds for the whole session.

- Anything that writes code gets its own worktree and checks the target branch out fresh from `origin`. Two writers never share files.
- Read-only items (triage a ticket, verify a claim, review a PR) run in the shared checkout on a cheaper model.
- Every brief carries the exact facts recon found (ticket IDs, PR numbers, commit SHAs, the failing step), what done looks like, what stays untouched, the cleanup expected, and a report of at most ten lines.
- A brief for a bug carries the reproduction input verbatim. When the ticket has a screen recording, ask before downloading it, extract a contact sheet (`ffmpeg -vf "fps=4,scale=300:-1,tile=8x4"`), read it, and put what it shows into the brief. The ticket text is usually missing the one precondition that matters.

## 4. Gates the agents enforce

- **Merge** only a PR whose ticket passed QA on a build equal to the current head, compared by patch ID as in `land-my-prs`. Production code after the verified build means the QA status is stale: move the ticket back to QA, say what to test on the new head, and stop.
- **Red check**: read the failing test's result from the run artifact. A crash with no assertion and the same signature on an unrelated branch is a runner flake, proven by three green local runs of that test class. Rerun it, then stop polling.
- **Bug that does not reproduce**: a fix would be speculation, so there is none. Report what was tried with the exact input, what single code path could produce the symptom, and what question settles it.
- **Review**: approve working code, and request changes only on bugs, spec misses or policy reach.

## 5. Report as they land

Each hand-back becomes two to four lines for the user: what changed with links, what the agent refused to do and why, what the user must decide. Stop an agent that keeps re-reporting while it polls CI. Remove each finished agent's worktree.

A fix for a red lane is proven only by that lane's next green run on a commit that contains it, and a merged PR is only a claim. Until that run exists, report the item as "fix merged, waiting on run N". Before saying the next run will tell, read the lane's latest run, because it may already have answered.

The round is complete when every dispatched item has a hand-back, every agent worktree is gone, every test red on the default branch has an owner, and the reply holds one open decision at most.
