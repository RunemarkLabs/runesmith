---
name: runesmith-release
description: "How Claude Code numbers builds and runs promotions along dev, qa, beta, main, and the behavior a project's release script must have. Use at the end of every goal (numbering the build), when a task comm asks for a promotion, a merge-back, a drift check or the qa gate, or when a task asks to build or change the release script."
---

# Release (builder)

Promotions run only when a task comm asks, and a task asks only on the owner's word. What each branch deploys, and where, belongs to the project's stack (runestack when in use): this skill moves branches and numbers builds; pushing a branch is what deploys it.

Until the project has a release script, do each step by hand with the same rules. A task that builds or changes the script gets one dry run of the changed command.

## Build numbers

- **MAJOR.MINOR.BUILD**, BUILD a running four-digit number: `1.2.0147`. BUILD never repeats; a bad build keeps its number and the fix takes the next. BUILD keeps counting across MINOR roll-ups and resets to `0001` only when MAJOR rolls up.
- **Every finished goal** takes the next number on `dev` as your last step before the banner: tag the merged `dev` commit `v{number}`, push the tag, and put the number in the replies, the goal status comm and the banner. Running it again on a numbered commit gives the same number. Refuse a commit that isn't on `dev`, or one older than a numbered commit.
- **`qa` and `beta` never take a number:** they carry the promoted build's. A fix into `beta` is a new build and takes the next number.
- **MINOR rolls up** when `beta` ships to `main`: nothing is rebuilt; the next build carries the new MINOR.
- **MAJOR rolls up** only on the owner's word: for 1.0 at the version-1 scope, and later when admins must act on an upgrade. The pull request's changelog line starts "**Before you upgrade:**".
- **Git tags are the only count.** No counter file. The number isn't in the source; the build is given it.
- **A new project** starts at `0.1.0001` (MAJOR stays 0 until the owner calls version 1.0).
- **Starting on a project with history:** earlier versions keep their numbers; BUILD starts after the builds that reached testers or users. Note the switch in the changelog.

## Commands (the release script's behavior)

| Command | Does | Refuses when |
|---|---|---|
| `number` | Tags the current `dev` commit with the next number and pushes the tag | Not on `dev`; older than a numbered commit |
| `promote-qa {number}` | Pull request `dev` into `qa` with "Requested by: {owner's words}"; fast-forwards `qa` to that exact commit after the build check | The commit has no number; drift; the full suite or a live check failed on `dev` at that commit |
| `promote-beta {number}` | Release commit (Unreleased becomes `## {number} ({date})`, naming the goal builds included); pull requests into `qa` and `beta`, both fast-forwarded to it (the first time, `beta` doesn't exist: create it at that commit and push it, never from `main`); merges `qa` back into `dev` | qa gate not clear and no recorded override; beta held; drift |
| `ship-it` | Pull request `beta` into `main` with "Requested by:"; no rebuild | Drift |
| `merge-back` | `beta` into `qa`, `qa` into `dev`, rebuilding the changelog and checklist from both sides rather than leaving it to git | - |
| `drift` | Checks `dev` contains every `qa` commit, `qa` every `beta` commit, `beta` every `main` commit | - |
| `qa-gate` | Reports clear, or what blocks: owner items not passed, an item failing, a hold | - |
| `hold-beta` / `lift-beta-hold` | Records or lifts the owner's hold, in his words | - |

The qa results live on the planner's checklist page, not in the repo: `qa-gate` and `promote-beta` take the planner's answer from the task comm ("qa gate: clear" or the override, verbatim).

## Promotions by hand (no script yet)

- **To qa:**
  1. Run the full suite and every live check on `dev` at the numbered commit, plus the automated checklist items.
  2. If all passed, open the pull request into `qa`; after the build check, fast-forward `qa` to that commit.
  3. Keep qa's data.
  4. In the reply, list the owner items from `qa/checklist.md` and anything the run couldn't check.
- **To beta:**
  1. Make the release commit on `qa`.
  2. Open pull requests into `qa` and `beta` and fast-forward both. The first time, `beta` doesn't exist: create it at the release commit and push it instead (never from `main`).
  3. Merge `qa` back into `dev`.
  4. Push. If `qa` got fixes since the passing run, run the full suite once on this commit first.
- **Ship it:** open the pull request `beta` into `main`. Nothing is rebuilt.
- **A fix found in qa or beta:**
  1. Open a pull request into that branch.
  2. In the same task, merge it back down (`beta` into `qa`, `qa` into `dev`).
  3. Rebuild the changelog and checklist from both sides.

## Rules that never bend

- Never push directly to `dev`, `qa`, `beta` or `main`. Never force-push. Never delete those branches. Never change branch rules.
- Promote one step at a time, and never skip a stage.
- Every reply gives test counts and how long each step took.
