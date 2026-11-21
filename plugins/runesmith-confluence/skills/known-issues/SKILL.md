---
name: known-issues
description: "Create or update a known issues and tech debt tracker page for Confluence. Template includes issue description, severity, workaround, status, and linked tickets. Trigger on \"known issues\", \"document known issues\", \"known bugs\", \"tech debt list\", \"known issues page\", \"update known issues\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Known Issues Tracker

Single Confluence page tracking known bugs, tech debt, and workarounds.

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
3. Locate existing page (space-scoped):
   ```
   GET {ATLASSIAN_API_URL}/wiki/api/v2/pages?space-id={SPACE_ID}&title=Known%20Issues&status=current
   ```
   Capture `id` and `version.number` if exists.

## When to Use

Use for:
- Documenting known bugs + workarounds
- Tech debt visibility list
- Linking issues to Jira tickets

Do not use for:
- Active bug tracking → Jira
- Feature requests → `feature-doc`

## Workflow

### 1. Gather entry

- Issue title
- Severity: Critical | High | Medium | Low
- Description
- Impact (who is affected?)
- Workaround (if any)
- Status: Open | In Progress | Blocked | Mitigated
- Linked Jira ticket
- Expected fix (timeline, optional)

### 2. Compose entry (markdown table row + detail section)

```markdown
| {issue title} | {severity} | {status} | [{KEY}](url) | {expected fix} |
```

Plus detail block appended below the table:

```markdown
### {issue title}
- **Severity:** ...
- **Description:** ...
- **Impact:** ...
- **Workaround:** ...
- **Jira:** [KEY](url)
```

### 3. Get consent

"Append to Known Issues in {SPACE_KEY}?" - wait for trigger phrase.

### 4. Publish

If page exists:
- GET full body, append entry, PUT with `version.number+1`
If not:
- POST new page titled "Known Issues" with template structure (table header + first entry)

Per `confluence-format.md`. Convert markdown → storage XHTML.

### 5. Report

```
✓ Issue logged
{issue title} - {severity} - {status}
Known Issues: {page_url}
Jira: {ticket_url}
```

## Guard Rails

- [ ] Credentials, space resolved
- [ ] Page lookup space-scoped
- [ ] Severity is one of allowed values
- [ ] Storage XHTML well-formed
- [ ] Consent received
- [ ] Update path: version+1
- [ ] On 409: re-GET, retry once
- [ ] URL returned

## Error Cases

See `confluence-format.md` error table.
