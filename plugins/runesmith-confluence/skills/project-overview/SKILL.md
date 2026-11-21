---
name: project-overview
description: "Create a project overview page for Confluence - the landing page for a project space. Template includes project name, description, team, tech stack, architecture summary, current phase, and links. Trigger on \"project overview\", \"create the overview page\", \"set up the project page\", \"overview page\", \"landing page for the project\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Project Overview

Create the landing page for a project's Confluence space.

## References

- `agents/page-publisher.md` - subagent for markdown→XHTML→POST/PUT with version-bump

- `lib/atlassian-rest.md`
- `lib/confluence-format.md`
- `lib/credentials.md`
- `lib/consent.md`
- `lib/tokens.md`
- `lib/comms-check.md` - runs first
- `lib/plan-format.md` - for optional plan prefill
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved.
2. `{SPACE_ID}` resolved.
3. Optional plan prefill: a project-overview may pull "current phase / what's shipping" from active plans (`plans/active/`).
4. Check for existing overview page in space:
   ```
   GET {ATLASSIAN_API_URL}/wiki/api/v2/pages?space-id={SPACE_ID}&title=Project%20Overview&status=current
   ```
   If exists, ask user: replace (PUT) or abort.

## When to Use

Use for:
- New project space landing page
- Refresh existing overview after major changes

Do not use for:
- Feature specs → `feature-doc`
- Roadmap → `roadmap`
- ADRs → `architecture-doc`

## Workflow

### 1. Gather details

- Project name
- One-line description
- Team members (names, roles)
- Tech stack
- Architecture summary (1-2 paragraphs)
- Current phase (Discovery | Planning | Building | Launched | Maintenance)
- Key links (repo, board, roadmap, ADR index)

### 2. Draft

Save to `/drafts/project-docs/overview.md`. Use `{COMPANY}` if part of title.

### 3. Get consent

"Publish project overview to {SPACE_KEY}?" - wait for trigger.

### 4. Publish or update

Convert markdown → storage XHTML.

If new: `POST /wiki/api/v2/pages`
If update: `GET` page → read `version.number` → `PUT` with `number+1`. See `confluence-format.md`.

### 5. Report

```
✓ Project overview published
{page_url}
```

## Guard Rails

- [ ] Credentials, space resolved
- [ ] Existence check done
- [ ] Storage XHTML well-formed
- [ ] Consent received
- [ ] On update: version incremented
- [ ] URL returned

## Error Cases

**409 on PUT:** Re-GET version, retry once.
Other errors: see `confluence-format.md`.
