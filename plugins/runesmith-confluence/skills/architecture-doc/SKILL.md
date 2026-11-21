---
name: architecture-doc
description: "Create an architecture decision record (ADR) or architecture overview page for Confluence. Template includes context, decision, consequences, alternatives considered, and status. Trigger on \"architecture doc\", \"ADR\", \"document this architecture decision\", \"write an architecture page\", \"architecture record\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Architecture Documentation

Create an ADR or overview page for Confluence.

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
3. Optional plan prefill: list `plans/active/{slug}/plan.md` files; offer user to pick one or more (a single ADR may be derived from one plan; an architecture overview may pull from many).

## When to Use

Use for:
- Significant architectural decisions with trade-offs
- Recording rationale and alternatives for future reference

Do not use for:
- Quick design chats
- Implementation detail (use code comments)
- Tech debt → `known-issues`

## Workflow

### 1. Gather context

- Decision title (e.g. "REST vs. GraphQL for public API")
- Context / problem
- Decision (chosen option + reason)
- Consequences (positive + negative)
- Alternatives considered (each with rejection reason)
- Status: Proposed | Accepted | Superseded | Deprecated

### 2. Draft

Save to `/drafts/project-docs/adr-{slug}.md`:

```markdown
# {Title}

## Context
...

## Decision
...

## Consequences

### Positive
- ...

### Negative
- ...

## Alternatives Considered
1. {A} - rejected because ...
2. {B} - rejected because ...
3. {Chosen} - selected because ...

## Status
Accepted

## References

- `agents/page-publisher.md` - subagent for markdown→XHTML→POST/PUT with version-bump
- [Related ADR](url)

Date: {YYYY-MM-DD}
```

Show in chat for review.

### 3. Get consent

"Publish this ADR to {SPACE_KEY}?" - wait for trigger phrase.

### 4. Publish

Convert markdown → storage XHTML.

```
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
```

### 5. Report

```
✓ ADR published
{Title} - Status: {status}
{page_url}
```

## Guard Rails

- [ ] Credentials, space resolved
- [ ] All sections present (context, decision, consequences, alternatives, status)
- [ ] Alternatives include rejection reasons
- [ ] Markdown → storage XHTML
- [ ] Consent received
- [ ] 200 + page id
- [ ] URL returned

## Error Cases

Same as `feature-doc`. See `confluence-format.md` error table.
