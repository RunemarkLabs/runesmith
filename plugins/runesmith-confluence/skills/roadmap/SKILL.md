---
name: roadmap
description: "Create or update a product/project roadmap page for Confluence. Template includes now/next/later/someday phases with initiatives, owners, status, and dependencies. Trigger on \"roadmap\", \"update the roadmap\", \"create a roadmap\", \"plan the roadmap\", \"what's on the roadmap\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Roadmap

Single Confluence page for project roadmap. Now / Next / Later / Someday framework.

## References

- `agents/page-publisher.md` - subagent for markdown→XHTML→POST/PUT with version-bump

- `lib/atlassian-rest.md`
- `lib/confluence-format.md`
- `lib/credentials.md`
- `lib/consent.md`
- `lib/tokens.md`
- `lib/comms-check.md` - runs first
- `lib/plan-format.md` - for optional plan prefill (active plans inform Now / Next phases)
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved.
2. `{SPACE_ID}` resolved.
3. Optional plan prefill: list `plans/active/` plans grouped by status. `building` → Now phase; `open` → Next; archive recent → Later.
4. Locate existing roadmap (space-scoped):
   ```
   GET {ATLASSIAN_API_URL}/wiki/api/v2/pages?space-id={SPACE_ID}&title=Roadmap&status=current
   ```

## When to Use

Use for:
- Creating / refreshing project roadmap
- Now / Next / Later planning visibility

Do not use for:
- Sprint planning (Jira board)
- Per-task tracking (Jira tickets)

## Workflow

### 1. Gather initiatives

For each: name, description, owner, status (In Progress | Planned | Proposed | Backlog), dependencies.

Group by phase:
- Now (current quarter)
- Next (next quarter)
- Later (2+ quarters)
- Someday

### 2. Compose markdown

Save to `/drafts/project-docs/roadmap.md`. Use a table per phase or grouped sections.

### 3. Get consent

"Publish roadmap to {SPACE_KEY}?" - wait for trigger phrase.

### 4. Publish

If page exists: GET (with `?body-format=storage`) → read `version.number` → PUT with `version.number+1`, full new body.
If not exists: POST new page titled "Roadmap".

Convert markdown → storage XHTML per `confluence-format.md`. Wrap each phase in a `<h2>` heading.

### 5. Report

```
✓ Roadmap updated
Now: n  Next: n  Later: n  Someday: n
{page_url}
```

## Guard Rails

- [ ] Credentials, space resolved
- [ ] Page lookup space-scoped
- [ ] Each phase present (empty allowed)
- [ ] Status values normalized
- [ ] Storage XHTML well-formed
- [ ] Consent trigger received
- [ ] Update path: version+1
- [ ] On 409: re-GET, retry once
- [ ] URL returned

## Error Cases

See `confluence-format.md` error table.
