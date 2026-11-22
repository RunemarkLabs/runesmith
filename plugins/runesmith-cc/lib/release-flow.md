# Release flow

The one description of how code moves from a goal to production in a RuneSmith project. Every skill that touches branches, builds or promotions follows this file; the planner's CLAUDE.md and the builder's CLAUDE.md each carry a summary of it.

What each branch deploys, where it runs, and the CI workflow that produces the build check belong to the stack tooling (runestack when installed). RuneSmith owns the process: branches, who moves them and when, protection, gates, build numbers and the changelog.

## Branches

| Branch | Stage | Created by | When |
|---|---|---|---|
| `main` | prod | the repository | already there |
| `dev` | dev | `runesmith-cc:head` | at setup, from `main`; Claude Code's working branch |
| `qa` | qa | `runesmith-cc:head` | at setup, from `main` |
| `beta` | beta | Claude Code | on the first promotion to beta, at the build being promoted from `qa`; never from `main`, never at setup |
| goal branches | none | Claude Code | one per goal, from `dev`; deleted after merge |

Existing branches are never moved, rewritten or deleted by setup.

## Protection

One repository ruleset ("Protected branches") names `dev`, `qa`, `beta` and `main`, so `beta` is protected the moment it exists. Rules: pull request required (no approvals), no force-push, no deletion, the build check once the project's CI reports one. No rule on creating branches, so Claude Code can create `beta`. The owner's admin role bypasses it for promotion fast-forwards. `runesmith-cc:head` sets it with `RUNESMITH_GITHUB_PAT`, adding missing names and rules and never removing any.

## The chain

1. **Goal to dev.** Claude Code works on the goal's branch, tests, opens one pull request into `dev`, merges after the build check, and numbers the build (`MAJOR.MINOR.BUILD`, BUILD a running four-digit number, tag `v{number}`). The changelog gets the goal's lines under `## Unreleased`.
2. **dev to qa** (owner: "promote to qa"). The full suite and every live check run on `dev` at that build. Only if all pass: pull request into `qa`, fast-forward `qa` to exactly that commit. `qa` carries the build's number. The planner publishes the qa checklist page.
3. **qa to beta** (owner: "QA passed", "promote to beta"). Gate: every owner item on the checklist page passed and beta isn't held, or the owner overrides in his own words (recorded verbatim). A release commit turns `## Unreleased` into `## {number} ({date})`. `qa` and `beta` move to it by pull request; on the first promotion `beta` is created at that commit instead. `qa` merges back into `dev`.
4. **beta to main** (owner: "ship it"). Pull request `beta` into `main`. Nothing is rebuilt; the next build carries the new MINOR.

One step per promotion, never skipping a stage. Every promotion runs only on the owner's word, through a task comm the planner writes with `runesmith-sprint:promote`, carried out by Claude Code with its `runesmith-release` skill.

## Fixes, holds, drift

- **A fix found in qa or beta:** a pull request into that branch, merged back down in the same task (`beta` into `qa`, `qa` into `dev`). A fix into beta takes the next build number.
- **Hold:** "hold beta" stops promotions to beta until the owner lifts it; recorded in `decisions.md` in his words.
- **Drift** (`dev` lacks a `qa` commit, `qa` lacks a `beta` commit, `beta` lacks a `main` commit): promotions refuse until a merge-back task fixes it.

## Who does what

- **Owner:** says when to promote, tests qa against the checklist, says "ship it".
- **Planner:** writes the promotion task and `/goal` line, reads the qa gate, records holds and overrides. Never runs git write commands in the builder's repositories.
- **Claude Code:** creates and moves branches, numbers builds, writes the changelog, runs the suite. Never pushes directly to `dev`, `qa`, `beta` or `main`, never force-pushes, never changes branch rules.
