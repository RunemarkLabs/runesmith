# How-to: Daily Workflow

What working day-to-day in a RuneSmith-bootstrapped workspace looks like. Assumes you have the workspace set up (see `docs/howto/new-workspace.md`) and optionally have Atlassian wired in (`docs/howto/enable-atlassian.md`).

## The shape of a session

Every Cowork session starts with the same setup whether you do it explicitly or not:

1. **Cowork loads context.** Project Instructions UI text (behavioral), `CLAUDE.md` (structural), connected MCP servers (Atlassian, GitHub, Slack, etc.).
2. **Cowork checks `comms/open/` on entry.** Any `to: user` items from CC's previous session surface first. Triage before starting new work.
3. **You drive a task.** Plan, draft, ticket, mutation, review, anything.
4. **Optional hand-off to CC.** If repo-internal work is needed, Cowork writes a brief to `{PROJECT}.cc/comms/open/`. CC picks it up next time it runs.

## The three modes of work

### Mode 1: Plan new work

```
/runesmith-core:plan
```

Chat-first. Cowork asks about the problem, walks Decision / Why now / Scope. Writes `plans/active/<slug>/plan.md` when it has enough to capture. Status starts `open`.

Iterate. Re-running the skill on an existing plan refreshes it (the skill detects the slug if you reference it). When you're ready to execute:

- Set `status: building` in the plan frontmatter (manually, or ask Cowork).
- If atlassian-enabled: `/runesmith-sprint:plan-to-tickets`. Drafts Jira ticket JSONs to `plans/active/<slug>/tickets/`. Review on disk. Say "push the tickets" when ready — drafts POST to Jira, archive locally.
- Cowork writes a hand-off brief to `{PROJECT}.cc/comms/open/<iso>-<slug>-task.md` if CC will execute.

### Mode 2: Document something

Pick the right Confluence skill based on shape:

```
/runesmith-confluence:feature-doc          → feature specs
/runesmith-confluence:architecture-doc     → ADRs (Architecture Decision Records)
/runesmith-confluence:project-overview     → project landing pages
/runesmith-confluence:decisions-log        → append-only decision log
/runesmith-confluence:known-issues         → known issues tracker
/runesmith-confluence:roadmap              → product roadmap
/runesmith-confluence:session-log          → session summary
```

Every doc skill follows the same gate:
1. Drafts the page in markdown locally first — to `drafts/project-docs/<slug>/` (general drafts) or `plans/active/<slug>/refs/` (plan-bound).
2. Surfaces the draft for review.
3. When you say "publish the page" / "create the document," converts markdown to Confluence storage XHTML and POSTs.
4. Reports the published URL.

No write happens without the consent trigger. Reads (looking up existing pages) are free.

### Mode 3: Capture a ticket from feedback

For bugs filed during the day:

```
/runesmith-jira:bug-report
```

Cowork asks via structured prompt: what's broken, repro steps, severity, area. Drafts the Jira issue JSON locally. Optionally drafts a Confluence page documenting the bug context (uses `runesmith-confluence:known-issues` indirectly). On "make the ticket," POSTs to Jira and reports the key.

For non-bug issues (story, task, epic):

```
/runesmith-jira:ticket
```

Generic ticket creation, walks issue-type-specific fields. Same draft → confirm → push flow.

## Comms triage

After CC ran (or while CC is asleep):

```
/runesmith-sprint:check-comms
```

Scans `{PROJECT}.cc/comms/open/`. Categorizes:

- `to: user` — questions for you. Cowork drafts a reply for your review, archives the pair to `comms/archive/<YYYY-MM>/` on send.
- `to: cowork` — CC sent a result or blocker, doesn't need user input. Cowork acknowledges, archives.
- Ambiguity items — surfaced as structured prompts. You answer; Cowork replies to CC.

This is also the check-on-entry pattern: every planning skill invokes `check-comms` first so user-facing items don't get buried.

## Periodic maintenance

### Inbox sweep

Files dropped into `_INBOX/` get classified and routed:

```
/runesmith-workspace:inbox
```

Categorizes each file (plan-bound ref, draft material, research notes, ticket draft, source doc, image, superseded). Routes per the destination map in `plugins/runesmith-workspace/lib/folder-conventions.md`. Asks via structured prompt for ambiguous cases.

Run whenever `_INBOX/` has stuff. Idempotent.

### Tech-debt scan

Workspace clutter accumulates. Sweep:

```
/runesmith-devtools:tech-debt
```

Cross-references plans → refs/tickets/decisions → research/source-docs/drafts. Identifies content that's actually tech debt (unreferenced from any live plan or recent note), not just old. Outputs a structured report with delete/archive/keep recommendations. Confirms each before mutating.

Companion `code-tech-debt` skill deployed inside CC heads handles repo-internal code debt (dead exports, unused deps, etc.).

### Plan archival

When a plan's work is done:

- Set `status: done` in the plan frontmatter.
- Run `/runesmith-workspace:reallocate`. The skill moves `done` plans to `plans/archive/<YYYY-MM>/<slug>/`. `refs/` and unpushed `tickets/` travel with it.

## What happens at session start

Whatever skill you call first, the marketplace's behavior is consistent:

1. **Comms check on entry.** Any `to: user` items in `comms/open/` surface before the requested work. You triage; the skill then continues.
2. **Resolve `.credentials`** and project values. Skill confirms via structured prompt if a required value is missing.
3. **Gather details.** Skill asks structured-prompt questions to nail down the request.
4. **Draft locally** to `drafts/`, `plans/active/`, or chat. No external writes yet.
5. **Wait for explicit consent trigger.** "Make the ticket", "publish the page", "do it", "push the tickets", "ship it". Per `plugins/*/lib/consent.md`.
6. **Convert + POST/PUT** against canonical Cloud endpoints. Confluence storage XHTML for pages; Jira ADF for issue descriptions.
7. **Report URLs / file paths.** No commentary. Single structured summary.

If something doesn't fit this flow, the skill is wrong (or the request is). Push back; don't bend the gate.

## The trigger phrases (a partial catalog)

| Action | Trigger phrases (any of) |
|---|---|
| Make a Jira ticket | "make the ticket", "create the ticket", "push the ticket to Jira" |
| Make multiple tickets | "push the tickets", "make the tickets in Jira", "send to Jira" |
| Publish a Confluence page | "publish the page", "create the document", "ship the doc" |
| Push commits | "push it", "commit and push", "ship it" |
| Delete files | "delete it", "remove them", explicit per-skill structured prompt |
| Apply reallocate / migration | "apply", "do it" (after the structured prompt offers `apply/preview/cancel`) |

`plugins/*/lib/consent.md` has the per-plugin canonical list. Skills that don't see the trigger don't mutate.

## What CC does in parallel

Cowork drives planning + mutations. CC drives code. Coexistence pattern:

- Cowork writes `comms/open/<iso>-<task>.md` for CC to pick up.
- You launch CC against `{PROJECT}.cc/<repo>/`. CC reads its CLAUDE.md (agent-ops + guardrail rules apply), reads the task brief, executes.
- CC writes `comms/open/<iso>-<task>-result.md` when done (or `-blocker.md` if stuck, `-ambiguity.md` if it needs user input).
- CC never contacts the user directly. User reaches CC only through Cowork.

CC's read-write split on Atlassian (if enabled):
- CC reads sprints, tickets, comments via the read-only token.
- CC writes structured comms back to Cowork for any Jira/Confluence mutation. Cowork executes the mutation via MCP.

## Daily rhythm (example)

Morning:
- Open Cowork. Comms check runs implicitly on the first skill call.
- Triage anything from CC's overnight run.
- Plan the day: `/runesmith-core:plan` for any new work or `cat plans/active/<slug>/plan.md` for ongoing.

Mid-day:
- Drive a feature: plan → tickets → handoff brief.
- Write docs: `runesmith-confluence:feature-doc` for the feature, publish on consent.
- Field bugs: `runesmith-jira:bug-report`.

End of day:
- Wrap session: `runesmith-confluence:session-log` if you want a Confluence trail of what got decided.
- Push commits if you have them: `git status`, then "push it" / "ship it".
- Inbox sweep if `_INBOX/` filled up: `/runesmith-workspace:inbox`.

## Troubleshooting

**Skills don't trigger on natural language.** Check the skill's name in `/runesmith-devtools:help`. Slash commands work too (`/runesmith-jira:ticket`). Natural-language triggers are listed in each skill's `SKILL.md` description.

**Cowork seems to forget the project.** Both surfaces of project context must be present: Project Instructions UI text (behavioral) and `CLAUDE.md` (structural). Re-run `/runesmith-workspace:reallocate` to refresh the marker sections and re-emit Project Instructions text. Paste that text back into the UI.

**Plans pile up.** Set `status: done` and run reallocate. Or `status: superseded` if a newer plan replaces it.

**Comms folder fills up.** `/runesmith-sprint:check-comms` triages and archives resolved pairs to `comms/archive/<YYYY-MM>/`.

**External writes feel slow.** Every mutation has the explicit-consent gate by design. If you find yourself fighting the gate, that's a sign the request might not be as well-formed as it feels — refine in chat first, then trigger.
