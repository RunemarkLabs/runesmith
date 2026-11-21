---
name: plan
description: "Plan a change before executing - capture problem, decision, why-now, scope, trade-offs to a clean markdown file under plans/active/. Use when the user says \"plan this\", \"let's plan\", \"draft a plan for\", \"spec this out\", \"I want to plan\", or wants to think through a substantial change before any writes happen. Chat-first, file-last workflow."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Plan a Change

Capture a project plan as `plans/active/{slug}/plan.md`: clean markdown that is the source of truth for project intent, with an append-only `decisions.md` beside it. The planner reads and keeps plans; Claude Code never reads them directly. What it needs from a plan goes into its task comms.

This skill performs no API calls. It writes one local file (plus optional decisions log + refs dir).

## References

- `lib/plan-format.md` - canonical plan.md schema
- `lib/comms-check.md` - check-on-entry pattern
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. If any `to: user` comms are open, surface and let user decide before proceeding.

### 1. Workspace shape

Verify `plans/` exists at workspace root. If not, suggest running `/runesmith-workspace:init` first.

## When to Use

Use for:
- Substantial restructuring or refactoring
- Architectural decisions with trade-offs
- Multi-part work that needs the *why* recorded
- Establishing context Claude Code should read when working

Do not use for:
- Small obvious fixes the user just asked for explicitly
- Read-only queries
- Pure conversation / brainstorming (unless that converges into a plan)

## Workflow

### 1. Issues first (projects with a repository)

If the project has a Claude Code head, read the repository's open issues before discussing (Jira when Atlassian is enabled, otherwise GitHub; read only). Fold the ones that belong with this plan into its Problem and Scope, and name them in References. The planner never writes to the issue tracker.

### 2. Discuss

Pressure-test first: lead with the weakest point of the idea. Then surface what the user wants to plan. Ask only what's needed to fill the schema:
- Problem (what pain or opportunity)
- Decision (what we're going to do)
- Why now (the trigger)
- Scope (in / out)
- Trade-offs
- Alternatives considered
- References

Iterate in chat until the user converges.

### 3. Propose slug

Generate a short kebab-case slug from the title. Verify it's unique within `plans/active/`. If collision, append `-2`.

### 4. Show draft

Show the proposed `plan.md` content per `plan-format.md`. Frontmatter:

```yaml
---
slug: {kebab-slug}
status: open
created: YYYY-MM-DD
updated: YYYY-MM-DD
owner: {user}
supersedes: []
related: []
tickets: []
---
```

Body uses the canonical sections from `plan-format.md`.

### 5. Get consent

Structured single-pick prompt, with the draft shown above it:
- **Save the plan** (default)
- **Keep refining**
- **Cancel**

Do not write without consent.

### 6. Write

Create:
```
plans/active/{slug}/
├── plan.md           the plan
├── decisions.md      empty stub with H2 ready for entries
└── refs/             empty dir
```

`decisions.md` stub:
```markdown
# Decisions for {slug}

Append-only log of decisions made under this plan.

## YYYY-MM-DD - {decision title}
**What:** ...
**Why:** ...
**Participants:** ...
```

### 7. Report

```
Plan created: plans/active/{slug}/plan.md (status: open)
Decisions log: plans/active/{slug}/decisions.md
```

Next step, by project:
- Atlassian-enabled: `/runesmith-sprint:plan-to-tickets` drafts Jira tickets from the plan.
- Has a Claude Code head: `/runesmith-sprint:task` writes the task comms and gives the `/goal` line.
- Otherwise: carry on in this chat, or publish with a `runesmith-confluence` skill.

## Changing a plan later

- Every decision is appended to `decisions.md`: the date, what was decided, who decided it. Never edit or remove past entries.
- When scope changes, snapshot `plan.md` to `archive/_pre-plan-edit-{UTC}/` and edit it.

## Guard Rails

- [ ] Comms check ran first
- [ ] Slug is kebab-case, unique within active/
- [ ] All required schema sections present
- [ ] Open issues read first when the project has a repository
- [ ] User consented through a structured prompt
- [ ] No file written without consent
- [ ] Plan dir contains plan.md, decisions.md stub, refs/

## Error Cases

**`plans/` missing:** "Workspace doesn't have plans/ yet. Run `/runesmith-workspace:init` first to set up the structure."
**Slug collision:** Auto-append `-2`, surface to user, get re-confirmation.
**User keeps editing without converging:** After ~3 rounds, offer the consent prompt from step 5 again so the draft can be saved and refined on disk
**Empty required section:** "Section {name} is empty. Plans must have all of Problem, Decision, Why now, Scope. Add content or skip the plan."
