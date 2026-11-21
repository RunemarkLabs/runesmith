---
name: decisions-log
description: "Create or update a running decisions log page for Confluence. Template includes date, decision, rationale, participants, and status. Log decisions as they are made. Trigger on \"decisions log\", \"log this decision\", \"record the decision\", \"add to decisions log\", \"update the decisions log\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Decisions Log

Append-only log of project decisions on a single Confluence page.

## References

- `agents/page-publisher.md` - subagent for markdown→XHTML→POST/PUT with version-bump

- `lib/atlassian-rest.md`
- `lib/confluence-format.md`
- `lib/credentials.md`
- `lib/consent.md`
- `lib/tokens.md`
- `lib/comms-check.md` - runs first
- `lib/plan-format.md` - for optional source: `plans/active/{slug}/decisions.md`
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved.
2. `{SPACE_ID}` resolved.
3. Optional plan prefill: append entries from one or more `plans/active/{slug}/decisions.md` files into the workspace-level decisions log.
4. Locate existing log page (space-scoped):
   ```
   GET {ATLASSIAN_API_URL}/wiki/api/v2/pages?space-id={SPACE_ID}&title=Decisions%20Log&status=current
   ```
   If exists: capture `id` and current `version.number`. If not: will create new.

## When to Use

Use for:
- Logging decisions as made
- Building decision audit trail

Do not use for:
- Full ADR → `architecture-doc`
- Meeting notes without decisions → `session-log`

## Workflow

### 1. Gather entry

- Date (default today, ISO YYYY-MM-DD)
- Decision (one sentence)
- Rationale
- Participants
- Status: Open | Accepted | Implemented | Superseded
- Related links

### 2. Compose entry (markdown)

```markdown
## {YYYY-MM-DD} - {decision title}

**Decision:** ...
**Rationale:** ...
**Participants:** ...
**Status:** Accepted
**Related:** [Ticket](url)
```

### 3. Get consent

"Append to Decisions Log in {SPACE_KEY}?" - wait for trigger phrase.

### 4. Publish

If page exists:
- GET full page body (`?body-format=storage`) to read current `version.number` and `body.storage.value`
- Append new entry XHTML to existing body
- PUT with `version.number = current + 1`

If not exists:
- POST new page titled "Decisions Log"

Both per `confluence-format.md`. Convert markdown entry → storage XHTML.

### 5. Report

```
✓ Decision logged
{date} - {decision title}
{page_url}
```

## Guard Rails

- [ ] Credentials, space resolved
- [ ] Page lookup space-scoped
- [ ] Date in ISO format
- [ ] Status valid value
- [ ] Storage XHTML well-formed
- [ ] Consent trigger received
- [ ] On update: version incremented; on 409, re-GET and retry once
- [ ] URL returned

## Error Cases

**409 conflict:** Re-GET version, retry PUT once. If still 409, abort and surface to user.
Other errors: see `confluence-format.md`.
