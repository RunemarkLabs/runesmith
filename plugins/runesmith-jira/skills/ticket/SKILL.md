---
name: ticket
description: "Create, format, and push Jira ticket drafts for any issue type (Task, Story, Bug, Epic). Includes JSON format specification, field guidance per issue type, and the push-to-Jira workflow. Trigger on \"create a ticket\", \"make a Jira ticket\", \"write a ticket for this\", \"draft a ticket\", \"create a task for\", \"make the ticket\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Create Jira Ticket

Create, format, and push Jira tickets with proper structure and field guidance.

Supports Task, Story, Bug, Epic with issue-type-specific fields and acceptance criteria.

## References

- `lib/atlassian-rest.md` - endpoints + ADF body
- `lib/credentials.md` - auth resolution
- `lib/consent.md` - trigger phrases for push
- `lib/tokens.md` - `{PROJECT_KEY}`, `{LEAD_ACCOUNT_ID}`
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Resolve `.credentials` per `credentials.md`. Required: `ATLASSIAN_API_URL`, `ATLASSIAN_API_TOKEN`, `ATLASSIAN_API_EMAIL`. If missing → "Run `/runesmith-core:setup`."
2. Resolve `{PROJECT_KEY}`: `ATLASSIAN_JIRA_PROJECT_KEY` from `.credentials`, then CLAUDE.md, else ask user.
3. Resolve assignee `accountId`: if user provides email, look up via `GET /rest/api/3/user/search?query={email}`. If no assignee given, leave unset.
4. Discover priority/severity field if needed: `GET /rest/api/3/field`. Use `priority` by default. Map to `ATLASSIAN_BUG_SEVERITY_FIELD` only if set.

## When to Use

Use for:
- Creating Task, Story, Bug, or Epic tickets
- Pushing approved drafts to Jira after explicit consent

Do not use for:
- Updating existing tickets (use Jira UI or a future update skill)
- Bulk creation
- Auto-creation without consent (see `consent.md`)

## Workflow

### 1. Gather details

For all types:
- Summary (title, < 255 chars)
- Description (markdown, will convert to ADF)
- Assignee email (optional)
- Labels (optional)
- Priority: Highest / High / Medium / Low / Lowest

For Task/Story:
- Acceptance criteria (numbered)
- Story points (optional, custom field id varies - discover via `/rest/api/3/field`)

For Bug:
- Environment (OS, version, browser)
- Steps to reproduce (numbered)
- Expected vs actual
- Severity → mapped to `priority` unless `ATLASSIAN_BUG_SEVERITY_FIELD` configured

For Epic:
- Epic Name (required, custom field id varies)
- Initiative / goal
- Timeline estimate

### 2. Format JSON

Convert markdown description to ADF (see `atlassian-rest.md`). Minimal example:

```json
{
  "fields": {
    "project":   { "key": "{PROJECT_KEY}" },
    "issuetype": { "name": "Task" },
    "summary":   "Short summary",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        { "type": "paragraph", "content": [{ "type": "text", "text": "Body paragraph" }] }
      ]
    },
    "labels":    ["bootstrap"],
    "assignee":  { "accountId": "{LEAD_ACCOUNT_ID}" },
    "priority":  { "name": "Medium" }
  }
}
```

### 3. Review & Approve

Show formatted JSON in chat. Ask: "Push this ticket to {PROJECT_KEY}?"

Wait for consent trigger phrase per `consent.md`. Do not push without it.

### 4. Push to Jira

```
POST {ATLASSIAN_API_URL}/rest/api/3/issue
```

On success, response includes `key` and `self`. Construct browse URL:
```
{ATLASSIAN_API_URL}/browse/{key}
```

### 5. Report

```
✓ {KEY} created
{summary}
{ATLASSIAN_API_URL}/browse/{KEY}
```

## Guard Rails

- [ ] Credentials resolved per `credentials.md`
- [ ] Project key confirmed
- [ ] Description converted to ADF
- [ ] Assignee resolved to `accountId` (not email/name)
- [ ] User issued consent trigger phrase before push
- [ ] API response 201; `key` captured
- [ ] Browse URL returned
- [ ] No credentials echoed

## Error Cases

| Status | Response | Action |
|---|---|---|
| 400 | `errorMessages: ["customfield_X is required"]` | Discover field via `/rest/api/3/field`, prompt user |
| 401 | invalid auth | Re-read `.credentials`, retry once, then "Run `/runesmith-core:setup`." |
| 403 | no permission to create in project | Surface, abort |
| 404 | project not found | Confirm `{PROJECT_KEY}` |
| 429 | rate limit | Honor `Retry-After`, retry once |

**No consent given:** Hold the draft, do not push. Tell user "Say 'make the ticket' to push."

**Severity field missing:** "Severity is a custom field. Set `ATLASSIAN_BUG_SEVERITY_FIELD` in `.credentials` or use Priority."
