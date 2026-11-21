# How-to: Daily Workflow

What a working day looks like once a project is set up (`docs/howto/new-workspace.md`). Jira is optional; where it changes something, it's noted.

## Who does what

- **You (the owner)** decide, paste `/goal` lines into Claude Code, approve promotions and mark the QA checklist.
- **The planner** (Claude in the Claude Project) plans, writes tasks, verifies Claude Code's work and talks to Jira, Confluence and GitHub. In a code project it writes no application code.
- **The builder** (Claude Code in `{PROJECT}.cc/`) builds, tests and merges, and reports through `comms/`.

## The loop

### 1. Plan

```
/runesmith-core:plan
```

Discuss the change in chat. The skill checks open issues, then writes `plans/active/{slug}/plan.md` and `decisions.md`. With Jira, `/runesmith-sprint:plan-to-tickets` drafts tickets under the plan and pushes them when you say so.

### 2. Hand work to Claude Code

```
/runesmith-sprint:task
```

The planner pressure-tests the request, reads open issues (Jira or GitHub, read only), asks only what is yours to decide, then writes the task comm with Acceptance in `{PROJECT}.cc/comms/open/{UTC}-{slug}/` and logs it in `decisions.md`. It copies screenshots and files Claude Code needs into the task's `references/` or `assets/`.

It ends with a `/goal` line, for example:

```
/goal Don't change the checkout layout. Do comms/open/20261121T173516Z-cancel-order/20261121T173516Z-cancel-order.md. No promotion. Done when each task's Acceptance is met, or each item that needs the owner is named in the reply as an owner action.
```

Paste it into Claude Code, opened in `{PROJECT}.cc/`. If a goal is already running, paste it after that goal's banner.

### 3. Claude Code works the goal

You don't need to watch. It writes a goal status comm first, works each task on its own branch, merges into `dev` when tests pass, numbers the build, writes a reply per task, and prints one banner at the end. The banner's "Needs you" lists anything only you can do.

### 4. Check comms

```
/runesmith-sprint:check-comms
```

Or just say "check comms". The planner reads the goal status, verifies each reply against the repository (read only), looks at the screenshots, archives finished tasks, logs the outcome, and tells you what needs you. If there's more to do, it gives the next `/goal` line.

When Claude Code stopped on a question, the planner shows it to you as a structured prompt, writes the answer comm, and gives the goal line that resumes the work.

### 5. Promote

Say "promote to qa".

```
/runesmith-sprint:promote
```

The chain is `dev` to `qa` to `beta` to `main`, one step at a time and only on your word. Each step is a task with its own goal line.

- **To qa:** Claude Code runs the full suite against `dev` first, then promotes. The planner publishes the QA checklist page and gives you its link.
- **To beta** ("QA passed"): allowed when every checklist item passed and beta isn't held. You can override in your own words; the override is recorded verbatim.
- **To main** ("ship it"): `beta` into `main`.
- **Hold:** "hold beta" stops beta promotions until you lift it.

### 6. Run the QA checklist

Open the page the planner linked. Each item shows its steps and what to expect. Mark it pass or fail; on a fail, describe what you saw. A failure becomes a fix task, and Claude Code opens the GitHub issue (`bug-report`, `env:qa` and a component label when it applies). The page is the same every time; it updates for each build.

## Documentation and tickets

```
/runesmith-confluence:feature-doc         feature specs
/runesmith-confluence:architecture-doc    architecture decision records
/runesmith-confluence:project-overview    project landing pages
/runesmith-confluence:decisions-log       running decisions log
/runesmith-confluence:known-issues        known issues tracker
/runesmith-confluence:roadmap             roadmap
/runesmith-confluence:session-log         session summary
/runesmith-jira:bug-report                a bug, with an optional Confluence page
/runesmith-jira:ticket                    any other Jira issue
```

Each drafts locally, shows you the draft, and writes to Confluence or Jira only after you approve through a structured prompt.

## Housekeeping

- **Inbox:** drop files in `_INBOX/`, then `/runesmith-workspace:inbox` routes them.
- **Workspace debt:** `/runesmith-devtools:tech-debt` finds files no live plan references and asks before changing anything. Inside the repo, Claude Code has `runesmith-code-tech-debt`.
- **Finished plans:** set `status: done`; the next `/runesmith-workspace:init` archives them.
- **Commits in the workspace:** only when you say "commit and push", "push it" or "ship it".

## Rules that don't bend

- Every decision is a structured prompt with the recommended option first.
- Nothing is written to Jira, Confluence or GitHub without your approval.
- Claude Code never talks to you directly, except its one banner per goal.
- The planner never runs git write commands in Claude Code's repos and never edits a reply.
- No AI attribution in commits, pull requests or files.

## Troubleshooting

**Skills don't trigger on plain language.** Use the slash command, or check the triggers with `/runesmith-devtools:help`.

**The planner seems to forget the project.** Both contexts must be present: the Project Instructions and `CLAUDE.md`. Re-run `/runesmith-workspace:init` and paste the fresh instructions block.

**Claude Code keeps going after its banner.** The head's settings cap the stop hook at three; if it loops anyway, re-run `/runesmith-cc:head` to restore the settings.

**A reply says complete but the planner disagrees.** The planner reports what doesn't match and writes a fix task. Replies are never edited.

**`comms/open/` keeps growing.** Run check comms. Owner-only items stay open until you've done them.
