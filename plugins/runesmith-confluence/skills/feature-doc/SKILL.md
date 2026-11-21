---
name: feature-doc
description: "Create a feature specification page for Confluence. Template includes overview, goals, scope (in/out), behavior, technical notes, acceptance criteria, and related links. Trigger on \"feature doc\", \"write a feature document\", \"spec this feature\", \"create a feature spec\", or \"document this feature\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Feature Specification

Create a feature spec page for Confluence with goals, scope, and acceptance criteria.

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
3. Optional `parentId`: ask user, or default to space root.
4. Optional plan prefill: list `plans/active/{slug}/plan.md` files; offer user to pick one or more as content source. Confluence may need richer prose than the plan; user adjusts in step 2 if so.

## When to Use

Use for:
- New product feature specs
- Defining scope and acceptance criteria
- Engineering-shareable specifications

Do not use for:
- Architecture decisions → `architecture-doc`
- Project landing pages → `project-overview`
- Quick feedback → Jira comments

## Workflow

### 1. Gather details

If plan prefill selected: read each picked plan's `plan.md`. Map sections:
- Plan **Problem** → feature **Overview** (expand to Confluence prose)
- Plan **Decision** → feature description / **Goals**
- Plan **Scope** → feature **Scope** (use as-is)
- Plan **Trade-offs** → feature **Technical Notes** (expand)
- Plan acceptance criteria absent? Ask user to fill.

For any unfilled or richer-than-plan content, ask user:
- Feature name
- Problem / why it matters
- Target users
- In scope (list)
- Out of scope (list)
- User-facing behavior (steps / interactions)
- Technical notes (integrations, data model)
- Acceptance criteria (numbered)
- Related links

Audience reminder: Confluence pages may require more detail than the source plans, and one feature page may pull from multiple plans. Synthesize.

### 2. Draft markdown

Save to `/drafts/features/{slug}.md`:

```markdown
# {Feature Name}

## Overview
...

## Goals
- ...

## Scope

### In Scope
- ...

### Out of Scope
- ...

## Behavior
...

## Technical Notes
...

## Acceptance Criteria
1. ...

## Related
- [Jira ticket](url)
```

Show in chat for review.

### 3. Get consent

"Publish this feature spec to {SPACE_KEY}?" - wait for trigger phrase.

### 4. Publish

Convert markdown → storage XHTML per `confluence-format.md`.

```
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
```

Body: `spaceId`, `title`, optional `parentId`, `body.representation=storage`, `body.value={XHTML}`.

### 5. Report

```
✓ Feature spec published
{Feature Name}
{page_url}
```

## Guard Rails

- [ ] Credentials resolved
- [ ] Space resolved
- [ ] All sections present
- [ ] Acceptance criteria ≥1, numbered
- [ ] Markdown converted to storage XHTML
- [ ] Consent trigger received
- [ ] 200 response, page id captured
- [ ] URL returned

## Error Cases

**400 - body malformed:** Validate XHTML, retry.
**403 - no create permission:** Abort.
**404 - space/parent not found:** Verify ids.
**No consent:** Hold draft.
