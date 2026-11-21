# `plan.md` Format

Canonical schema for plan files. Every active plan lives at `plans/active/{slug}/plan.md` and follows this structure exactly.

Plans are **clean, claude-readable markdown** - the source of truth for project intent. Confluence is downstream output, generated on demand. One plan may feed multiple Confluence pages; one Confluence page may pull from multiple plans.

## Directory shape

```
plans/
├── active/
│   └── {slug}/
│       ├── plan.md          this file (required)
│       ├── decisions.md     append-only decision log under this plan (optional)
│       ├── refs/            supporting docs attached to this plan
│       └── tickets/         pre-push Jira ticket JSON drafts
└── archive/
    └── {YYYY-MM}/{slug}/    same shape; preserved when archived (carries refs + tickets)
```

After a ticket is pushed to Jira, its JSON draft is moved to `archive/tickets-pushed/{YYYY-MM}/{KEY}.json` for history (referenced only on demand).

`{slug}` is kebab-case, ≤40 chars, unique within `active/`.

## File template

```markdown
---
slug: {kebab-slug}
status: open | building | blocked | done | superseded
created: YYYY-MM-DD
updated: YYYY-MM-DD
owner: {user}
supersedes: []        # other plan slugs this replaces
related: []           # other plan slugs that share context
tickets: []           # Jira keys spawned from this plan (atlassian-enabled only)
---

# {plan title}

## Problem
What pain or opportunity. One paragraph, plain.

## Decision
What we're going to do, in one paragraph.

## Why now
The trigger - incident, deadline, dependency unblocked, etc.

## Scope
- **In:** ...
- **Out:** ...

## Trade-offs
What we accept by choosing this over alternatives.

## Alternatives considered
1. {option} - rejected because ...

## References
- refs/{file}.md
- {external URL}
```

## Field rules

- **`slug`** - must match the directory name. Skills validate.
- **`status`** -
  - `open` (default) - captured but not started
  - `building` - work in progress
  - `blocked` - waiting on external action
  - `done` - work complete, ready to archive
  - `superseded` - replaced by another plan (set `supersedes:` on the replacement)
- **`created` / `updated`** - ISO date (YYYY-MM-DD).
- **`tickets`** - populated by `runesmith-sprint:plan-to-tickets`. Empty in base config.
- **Sections are fixed** - Problem / Decision / Why now / Scope / Trade-offs / Alternatives / References. Do not rename. Do not add top-level sections. Skills and downstream Confluence generators rely on this.

## Lifecycle

1. **Create** - `runesmith-core:plan` writes a new `plans/active/{slug}/plan.md`. User iterates.
2. **Build** - set `status: building` when work starts. If atlassian-enabled, `runesmith-sprint:plan-to-tickets` writes ticket JSON drafts to `plans/active/{slug}/tickets/`, pushes to Jira on consent, populates the frontmatter `tickets:` array, and moves the pushed JSONs to `archive/tickets-pushed/{YYYY-MM}/`.
3. **Block** - set `status: blocked` while waiting; document reason in `decisions.md`.
4. **Done** - set `status: done` when complete. Run `/runesmith-workspace:init` (idempotent) to move to `plans/archive/{YYYY-MM}/{slug}/`. `refs/` and any remaining unpushed `tickets/` travel with the plan.
5. **Supersede** - when a new plan replaces this one, the new plan lists this slug in `supersedes:`. The old plan's `status` becomes `superseded`. Both end up archived.

## Decisions log (optional)

`plans/active/{slug}/decisions.md` is append-only. Each entry:

```markdown
## YYYY-MM-DD - {decision title}
**What:** ...
**Why:** ...
**Participants:** ...
```

This is plan-scoped. The workspace-level `runesmith-confluence:decisions-log` skill is a separate, broader log.

## References

`plans/active/{slug}/refs/` holds supporting docs. Use relative paths in the plan's References section: `refs/{file}.md`. When a plan archives, refs travel with it - paths stay correct.

## Tickets

`plans/active/{slug}/tickets/` holds pre-push Jira ticket JSON drafts (`{DRAFT-ID}.json` before push, renamed to `{JIRA-KEY}.json` on push). After successful push, drafts move to `archive/tickets-pushed/{YYYY-MM}/{KEY}.json`. Unpushed drafts remain in `tickets/` and travel with the plan to `archive/{YYYY-MM}/{slug}/tickets/` when the plan is archived.

## Skills that read this format

- `runesmith-core:plan` - writes
- `runesmith-workspace:init` - moves between active/archive
- `runesmith-workspace:inbox` - classifies incoming files; routes plan-bound refs to `refs/`, ticket JSONs to `tickets/`
- `runesmith-sprint:plan-to-tickets` - reads plan, writes draft JSONs to `tickets/`, pushes to Jira, archives JSONs to `archive/tickets-pushed/{YYYY-MM}/`
- All Confluence publish skills (`feature-doc`, `architecture-doc`, etc.) - optionally read as prefill source for Confluence content
