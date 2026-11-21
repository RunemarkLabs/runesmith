---
name: session-log
description: "Create or update a session log to capture decisions, action items, and progress. Use when the user says \"log this session\", \"session notes\", \"write up what we did\", \"capture this\", or at the end of a planning session. Also triggers on \"session summary\", \"what did we decide\", or \"save our progress\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Session Log

Capture session outcomes (decisions, action items, next steps) as a Confluence page.

## References

- `agents/page-publisher.md` - subagent for markdown→XHTML→POST/PUT with version-bump

- `lib/atlassian-rest.md`
- `lib/confluence-format.md`
- `lib/credentials.md`
- `lib/consent.md`
- `lib/tokens.md`
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved.
2. `{SPACE_ID}` resolved.
3. Optional `parentId` (e.g. an "Sessions" parent page).
4. Optional: check for existing session with same date+title and offer update vs. new page.

## When to Use

Use for:
- Documenting decisions + action items after a working session
- Searchable meeting archive

Do not use for:
- Full transcript (just attach the recording link)
- Decision-only records → `decisions-log`
- Per-action tracking → Jira tickets

## Workflow

### 1. Gather details

- Title (e.g. "Roadmap planning")
- Date (ISO YYYY-MM-DD)
- Attendees
- Decisions (bulleted)
- Action items (owner, action, due)
- Next steps
- Related links

### 2. Compose markdown

Save to `/drafts/sessions/YYYY-MM-DD-{slug}.md`. Title as `Session - {Date} - {Topic}` for sortable archive.

### 3. Get consent

"Publish session log to {SPACE_KEY}?" - wait for trigger phrase.

### 4. Publish

POST new page (or PUT existing per pre-flight 4). Convert markdown → storage XHTML.

```
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
```

### 5. Report

```
✓ Session logged
{Topic} - {date}
{decisions} decisions, {actions} actions
{page_url}
```

## Guard Rails

- [ ] Credentials, space resolved
- [ ] Date in ISO format
- [ ] At least one decision OR action item
- [ ] Storage XHTML well-formed
- [ ] Consent trigger received
- [ ] Action items have owner + due (warn if missing)
- [ ] On update: version incremented
- [ ] URL returned

## Error Cases

See `confluence-format.md` error table.
