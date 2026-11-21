---
name: bug-report
description: "Report a bug - document it, publish to Confluence, create a Jira ticket. Use when the user says \"there's a bug\", \"something broke\", \"this isn't working\", \"found an issue\", \"report a bug\", or describes unexpected behavior. Also triggers on \"file a bug\", \"bug report\", or \"this is broken\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Report Bug

Document a bug in Confluence and create a tracking ticket in Jira.

One workflow: capture issue → draft Confluence page → publish → create linked Jira Bug.

## References

- `lib/atlassian-rest.md` - endpoints
- `lib/confluence-format.md` - markdown→storage conversion
- `lib/credentials.md` - auth
- `lib/consent.md` - trigger phrases
- `lib/tokens.md` - `{SPACE_ID}`, `{PROJECT_KEY}`
- `lib/comms-check.md` - runs first
- Sibling skill `ticket` - Jira create flow
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved (`credentials.md`).
2. `{SPACE_ID}` resolved: `ATLASSIAN_CONFLUENCE_SPACE_ID` from `.credentials`, then CLAUDE.md, else ask.
3. `{PROJECT_KEY}` resolved: same order.
4. Confirm user has page-create permission in space (warn that 403 will surface if not).

## When to Use

Use for:
- Documenting unexpected behavior with reproduction steps
- Creating linked Confluence + Jira record

Do not use for:
- Quick fixes that need no record
- Updating existing bug records (Jira UI)
- Vague complaints with no repro

## Workflow

### 1. Gather details

- Summary
- Environment (OS, browser, app version)
- Steps to reproduce (numbered)
- Expected behavior
- Actual behavior
- Root cause (if known)
- Severity → maps to Jira `priority` unless `ATLASSIAN_BUG_SEVERITY_FIELD` set

### 2. Draft Confluence page

Save markdown draft to `/drafts/bugs/{slug}.md` with sections: Environment, Steps to Reproduce, Expected, Actual, Root Cause, Status, Linked Ticket (placeholder).

Show draft in chat for review.

### 3. Get consent

Ask: "Publish this bug report to {SPACE_KEY} and create the Jira ticket?"

Wait for trigger phrase per `consent.md`.

### 4. Publish to Confluence

Convert markdown → storage XHTML per `confluence-format.md`. Then:

```
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
```

Body shape per `confluence-format.md`. Capture response `id` and `_links.webui` for the page URL.

### 5. Create linked Jira Bug

Per `ticket` skill flow. Description ADF must include a paragraph linking to the Confluence page:

```json
{
  "type": "paragraph",
  "content": [
    { "type": "text", "text": "Bug report: " },
    { "type": "text", "text": "{page_url}", "marks": [{ "type": "link", "attrs": { "href": "{page_url}" } }] }
  ]
}
```

```
POST {ATLASSIAN_API_URL}/rest/api/3/issue
```

`fields.issuetype.name = "Bug"`. `priority.name` mapped from severity.

### 6. Backlink: update Confluence page with Jira key

GET the page to read current version, then PUT with version+1 and the Jira key inserted in the "Linked Ticket" section. See `confluence-format.md`.

### 7. Report

```
✓ Bug reported
Confluence: {page_url}
Jira: {ATLASSIAN_API_URL}/browse/{KEY}
```

## Guard Rails

- [ ] Credentials resolved
- [ ] Space + project resolved
- [ ] Repro steps numbered (≥1)
- [ ] Markdown converted to storage XHTML
- [ ] Consent trigger phrase received
- [ ] Confluence 200; page id captured
- [ ] Jira 201; key captured
- [ ] Backlink PUT succeeds (version incremented)
- [ ] Both URLs in output

## Error Cases

**Confluence 400:** Storage XHTML malformed. Validate against `confluence-format.md` mappings, retry.
**Confluence 403:** No create permission in space. Abort, do not attempt Jira.
**Jira 400 - severity:** Severity is custom field. Set `ATLASSIAN_BUG_SEVERITY_FIELD` or fall back to `priority`.
**Backlink 409:** Re-GET page version, retry PUT once.
**No consent:** Hold drafts, surface "Say 'make the ticket' or 'publish the page' to proceed."
