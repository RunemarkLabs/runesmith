---
name: inbox
description: "Process files in _INBOX/ - classify each per lib/folder-conventions.md, propose a destination, route on consent. Use when the user says \"process inbox\", \"check inbox\", \"sort inbox\", \"what's in the inbox\", \"deal with inbox\", \"route these files\", or after dropping new files into _INBOX/."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Inbox Processor

`_INBOX/` is the workspace drop zone - a permanent feature of the canonical structure where the user places files for the inbox skill to classify and route. The skill reads each file, identifies its category via filename + content + frontmatter, proposes a target per the destination map in `lib/folder-conventions.md`, and moves on consent.

After every run, `_INBOX/` ends empty except for items the user explicitly opted to leave (`unclassifiable` + user passes).

## References

- `lib/folder-conventions.md` - **single source of truth** for the destination map. Inbox is the executor.
- `lib/plan-format.md` - for routing plan-bound content into `plans/active/{slug}/`
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured-input requirement for any user prompt
- `lib/consent.md` - consent-trigger phrases for sensitive routes

## User input rules

Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

### 1. Locate `_INBOX/`

Workspace root must have `_INBOX/`. If missing, suggest `/runesmith-workspace:init`.

If empty: report "Inbox empty. Nothing to process." and exit clean.

## When to Use

Use for:
- After dropping files into `_INBOX/` to be sorted
- Periodic cleanup of accumulated inbox content
- Onboarding a batch of supporting documents into active plans

Do not use for:
- Files already inside `plans/`, `drafts/`, etc. - those are already routed
- Bulk auto-archive of canonical-home contents (different concern - see `runesmith-devtools:tech-debt`)

## Workflow

### 1. List inbox

Read every file in `_INBOX/` (recurse one level for user-created subdirs).

### 2. Classify each

For each file, determine category by filename + content sniff + frontmatter. Order of evaluation:

| Signal | Category |
|---|---|
| Filename starts with `{YYYY-MM-DD}-handoff-` OR content describes a session-bridge state (status / what's done / what's next) | `handoff` |
| Frontmatter has `slug:` + `status:` + Problem/Decision sections (matches `lib/plan-format.md`) | `plan-proposal` |
| Filename matches `decisions*.md` or content has `## YYYY-MM-DD -` decision-log headers | `decision-record` |
| Frontmatter has `from:` + `to:` + `type:` matching comms types | `misplaced-comm` |
| JSON with Jira issue fields (`fields.summary`, `fields.issuetype`, etc.) | `ticket-draft` |
| Markdown matching feature/bug/architecture template structure (Confluence draft) | `draft-feature` / `draft-bug` / `draft-project-doc` |
| Markdown content reads as analysis / comparison / evaluation (no plan frontmatter) | `research` |
| PDF, DOCX, XLSX, audio, raw transcript, vendor doc - external source | `source-doc` |
| Image (PNG/JPG/SVG), screenshot | `image` |
| Plain markdown - no other category fits | `note` |
| Anything else | `unclassifiable` |

### 3. Propose route

Per `lib/folder-conventions.md` destination map:

- **`handoff`** → `notes/{YYYY-MM-DD}-handoff-{slug}.md`. Add date prefix if missing; derive slug from filename or content title.
- **`plan-proposal`** → `plans/active/{slug}/plan.md` (slug from frontmatter). If slug exists, structured prompt: replace / version / rename.
- **`decision-record`** → structured prompt: which active plan? Append to `plans/active/{slug}/decisions.md`, or fall back to `notes/{YYYY-MM-DD}-decisions.md` if not plan-bound.
- **`misplaced-comm`** → `{PROJECT}.cc/comms/open/{filename}`. Warn user: comms shouldn't normally arrive via inbox.
- **`ticket-draft`** → structured prompt: which plan slug does this ticket belong to? Route to `plans/active/{slug}/tickets/{KEY}.json`. If user can't say, offer `archive/superseded/{YYYY-MM}/tickets-orphan/`.
- **`draft-feature`** → `drafts/features/{slug}/{slug}.md`.
- **`draft-bug`** → `drafts/bugs/{slug}/{slug}.md`.
- **`draft-project-doc`** → `drafts/project-docs/{slug}/{slug}.md`.
- **`research`** → structured prompt: is this tied to an active plan?
  - If yes: `plans/active/{slug}/refs/{filename}`
  - If no: `research/{topic}/{filename}` (prompt for topic)
- **`source-doc`** → structured prompt for topic: `source-docs/{topic}/{filename}`.
- **`image`** → structured prompt: is this still needed?
  - "Reference material for a draft" → `drafts/{bucket}/{slug}/assets/{filename}` (prompt for bucket+slug)
  - "Already consumed for content" → `archive/superseded/{YYYY-MM}/images/{filename}`
  - "Source material" → `source-docs/{topic}/{filename}`
- **`note`** → `notes/{YYYY-MM-DD}-{slug}.md`. Add date prefix if missing.
- **`unclassifiable`** → leave in `_INBOX/`. Surface to user with file head + filename for manual review.

### 4. Show batch + consent

Group up to 10 routes per consent prompt. Show:

```
{N} files to route:

  [handoff]         2026-05-10-handoff-pre-publish.md → notes/2026-05-10-handoff-pre-publish.md
  [plan-proposal]   plan-acme-portal-rewrite.md       → plans/active/acme-portal-rewrite/plan.md
  [research]        edge-comparison.md                → plans/active/acme-portal-rewrite/refs/edge-comparison.md
  [source-doc]      vendor-api-spec.pdf               → source-docs/acme-portal-rewrite/vendor-api-spec.pdf
  [draft-feature]   billing-integration.md            → drafts/features/billing-integration/billing-integration.md
  [image]           screenshot-2026-04-06.png         → archive/superseded/2026-05/images/screenshot-2026-04-06.png
  [note]            standup-notes.md                  → notes/2026-05-10-standup-notes.md
  [unclassifiable]  random-attachment.zip             → leave in _INBOX/

Surface a structured single-pick prompt: question "Apply these routes?", options "Apply all" / "Edit per-file" / "Cancel".
```

"Edit per-file" lets the user override individual targets before applying via per-row structured prompts.

### 5. Move

Per row:
- Create destination dirs as needed.
- Move file (preserve mtime).
- Verify target exists, source removed.

### 6. Log

Append to `notes/{YYYY-MM-DD}-inbox.md` (one log file per day, append across runs):

```markdown
## {ISO timestamp} - inbox run

- moved {N} files
- left {M} unclassifiable

| source | target | category |
| --- | --- | --- |
| _INBOX/plan-acme-portal-rewrite.md | plans/active/acme-portal-rewrite/plan.md | plan-proposal |
| _INBOX/edge-comparison.md          | plans/active/acme-portal-rewrite/refs/edge-comparison.md | research |
| _INBOX/screenshot-2026-04-06.png   | archive/superseded/2026-05/images/screenshot-2026-04-06.png | image |
| _INBOX/random-attachment.zip       | (left in inbox) | unclassifiable |
```

### 7. Report

```
✓ Inbox processed
Routed: {N} files
Left in inbox: {M} unclassifiable
Audit log: notes/{YYYY-MM-DD}-inbox.md

Next: /runesmith-core:plan, /runesmith-workspace:init, or run inbox again to handle remainder.
```

## Guard Rails

- [ ] Comms check ran first
- [ ] _INBOX/ located; skip clean if empty
- [ ] Every file classified
- [ ] Routes follow `lib/folder-conventions.md` destination map
- [ ] Ticket drafts route under their plan (`plans/active/{slug}/tickets/`), never to a root `tickets/`
- [ ] Plan-bound routes confirmed against existing slugs
- [ ] User consented per batch (10-file batches) via structured prompt
- [ ] No file overwritten without explicit consent
- [ ] Unclassifiable files left in place, never deleted
- [ ] Audit log appended for every run
- [ ] No file deletion ever - only moves

## Error Cases

**Inbox empty:** "Nothing to process." Exit clean.
**Plan slug doesn't exist for a routing target:** Structured prompt - pick existing plan / create new plan via `/runesmith-core:plan` / route to `research/{topic}/` if research / route to `archive/superseded/{YYYY-MM}/` if stale.
**Filename collision at destination:** Show diff if both are text; structured prompt: keep existing / replace / rename.
**File appears to be a comm:** "This file looks like a comms message. It belongs in `{PROJECT}.cc/comms/open/`. Move there or treat as note?" Structured single-pick.
**Permission error on move:** Skip that file, log, continue with the rest, report skipped at end.
**User wants to defer all routing:** Structured "Cancel" option exits without moves. Items remain in `_INBOX/` for next run.
