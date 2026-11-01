# skills

[![CI](https://github.com/anq-no-one/skills/actions/workflows/ci.yml/badge.svg)](https://github.com/anq-no-one/skills/actions/workflows/ci.yml)

Skills I use to run coding agents on real mobile work. Each one is a folder with a `SKILL.md` that Claude Code, Codex and other compatible agents load on demand.

| Skill | What it does |
|---|---|
| [tandem](skills/tandem) | Builds a plan with two models. One writes a commit per task, the other reviews each commit in a pinned worktree while the next task is already being written. |
| [iphone-duo-support](skills/iphone-duo-support) | Audits an iOS app for the foldable iPhone and walks it through size classes, arrangements, reserved regions and a pose matrix. |
| [work-the-queue](skills/work-the-queue) | Ranks my tickets, PRs and red tests by who is waiting, then gives each independent item to its own agent. |
| [land-my-prs](skills/land-my-prs) | Moves each of my open PRs one stage closer to merge, and checks that QA tested the same changes as the head. |

## Why these exist

**tandem** started from a cost problem. Reviewing a finished branch is too late: a wrong decision in task 1 that surfaces after task 8 means seven rewrites. Reviewing every task is cheap only if the writer doesn't have to wait, so the writer keeps going while the reviewer reads a worktree that can't move under it. Fixes land as `fixup!` commits, and history is rewritten once, when nothing is running.

**land-my-prs** exists because of one failure: a PR passes QA, gets one more commit, and merges with a stale approval. Comparing SHAs doesn't catch this cleanly, because merging the default branch into a PR changes the SHA without changing the PR. The skill compares patch IDs instead, so a merge passes and a new commit sends the ticket back to QA.

**iphone-duo-support** collects what I had to read across Apple's docs and tech talks, including the traps: Xcode 27.2 doesn't have the Duo SDK, the inner display still reports `.phone`, and an orientation lock doesn't stop the resize.

## Install

Copy or link a skill into the directory your agent reads:

```sh
git clone https://github.com/anq-no-one/skills
ln -s "$PWD/skills/skills/tandem" ~/.claude/skills/tandem
ln -s "$PWD/skills/skills/tandem" ~/.codex/skills/tandem
```

`tandem` needs `git`, `jq`, at least one of `claude`, `codex` or `cursor-agent`, and [revmux](https://github.com/umputun/revmux) unless you turn its final review off. `land-my-prs` and `work-the-queue` need `gh` and access to your issue tracker. `iphone-duo-support` needs Xcode 27.1.

## Tests

```sh
shellcheck scripts/*.sh skills/tandem/scripts/*.sh
scripts/check-skills.sh
bats skills/tandem/tests
```

The tandem tests run its scripts against stub CLIs and a real temporary git repository. The ones that matter most prove that a reviewer can't write under any executor config, and that a review worktree stays pinned while the main tree moves. The kill-on-timeout path isn't covered, because the shortest timeout the script accepts is one minute.

The other three skills are instructions with no code to test. `iphone-duo-support` ships eval prompts in `evals/`, and they need an agent to run.

## License

[MIT](LICENSE)
