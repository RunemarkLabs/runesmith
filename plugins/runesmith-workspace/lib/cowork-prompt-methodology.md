# Cowork Prompt Methodology - writing task comms that a context-fresh CC can act on

Battle-tested principles for how Cowork writes task comms to Claude Code. Each principle is here because skipping it caused a real miss. Apply when authoring any `type: task` comm bound for CC.

Source: extracted from Resume Unbound 2026-05-26 -> 2026-06-02 hand-refinements and Mix Tape 2026-06 handoff brief. Battle-tested in two live projects.

## The eight principles

### 1. Every comm is SELF-CONTAINED

A context-fresh CC remembers nothing. Each comm restates its MODEL / context, what prior work already shipped (by commit hash or "this exists now"), its scope, and its acceptance. Never write "as we discussed." If CC has been `/clear`-ed between comms, the previous chat is gone; only what's in the comm file (and CLAUDE.md) is real.

### 2. Acceptance is BEHAVIORAL, not "it compiles"

The single most important rule. "Done" = SHOW the result (paste DB rows, rendered output, real numbers, `git log --oneline`), NOT "typecheck + build pass." A rename can compile green and return zero rows at runtime. Compile-green is necessary, never sufficient.

Spell out exactly what a human must SEE in the reply. Require CC to paste the evidence. If CC can't produce the evidence, the acceptance directs it to STOP and banner rather than declare done.

### 3. Describe the PROBLEM + end-state, not the implementation

Tell CC what's wrong and what "right" looks like. Let CC choose the mechanism. Over-prescribing makes CC build the wrong thing precisely. Trust the agent to find the right code path; verify behaviorally.

### 4. Break big work into a TRAIN of small, ordered, self-contained cars

When changes span data + behavior + UI, or when CC's context will fill, split into cars (`{PREFIX}-{NNN}A-{slug}`, `-{NNN}B-{slug}`, `-{NNN}C-{slug}`). Each car restates the model and declares what the previous car committed (by hash). Cars land in order. A context-limited CC can be `/clear`-ed between cars.

Beats one mega-comm: in a mega-comm, individual pieces can pass acceptance while the whole stays broken because no single test exercises the seam.

### 5. STOP + banner built into the acceptance

Tell CC to halt and banner - not push through - on data-loss risk, an under-specified migration, an ambiguous decision, any blocker. Build "STOP + banner if X" directly into the acceptance section. A blocked comm that banners is the system working; a comm that silently does the wrong thing is the failure.

### 6. Numbering discipline

`{PREFIX}-{NNN}-{slug}`, incrementing, never skipped, never reused. Sub-tasks get A/B/C suffixes. The numbering convention is what makes triage scannable across weeks.

### 7. Confirm scope before far-reaching or destructive work

Restate the plan, get explicit go before mutating. Snapshot before any destructive move/delete. The user's "do it" is the trigger; absent that, surface the plan and wait.

### 8. Standard comm body structure

Every task comm body follows this skeleton:

```
## Context        - one paragraph: why this comm exists, what's in flight
## Model          - (if needed) compact restatement of the shared mental model
## Scope          - numbered: every file/route/behavior to change
## Out of scope   - explicit defer list
## Preserve       - what CC must NOT break (existing flows, prior phases, the test oracle)
## Acceptance     - BEHAVIORAL: what to SHOW + paste; "STOP + banner if it can't be shown"
## Notes          - branch, migrations, push instruction, reply filename, "Banner at end"
```

Every comm body ends with a "Banner at end" reminder in `## Notes` - reinforces the CC-side banner contract at the point of execution.

## How this applies

`runesmith-workspace:reallocate` writes a reference to this file into the workspace's `CLAUDE.md` agent-ops section so every Cowork session in the workspace inherits the methodology. The reference is informational - the full content is here in the plugin lib.

When Cowork is about to write a task comm for CC, agents should:

1. Pick the next `{NNN}` for the project's prefix.
2. Create the folder `comms/open/{PREFIX}-{NNN}-{slug}/`.
3. Write the task file using the standard body structure above.
4. If CC needs files from outside the repo, copy them into the folder's `attachments/`.
5. Verify the acceptance section is behavioral and includes a "STOP + banner if X" clause.

Skills that author task comms (planning, sprint, plan-to-tickets, etc.) should follow these principles directly or reference this file in their workflow.

## Worked example

```markdown
---
id: RU-042-rename-user-table
from: cowork
to: cc
type: task
status: open
created: 2026-06-14T09:30:00Z
---

# RU-042: Rename user table from `users` to `accounts`

## Context
The `users` table holds what the product calls "accounts" everywhere except the
schema. The naming mismatch is a recurring source of confusion. RU-041 prepared
the migration scaffolding (commit `a1b2c3d`); this comm executes the rename.

## Model
- Postgres 15, single primary
- The app reads/writes `users` from ~12 call sites (server/db/users.ts and friends)
- No downstream consumers depend on the table name (verified RU-041)

## Scope
1. Migration: rename table `users` -> `accounts`, plus all FK constraints
2. Update server/db/*.ts to reference `accounts`
3. Update tests to reflect new name
4. Add a migration rollback path

## Out of scope
- Renaming the API field `user` -> `account` (separate comm RU-043)
- Updating the frontend (RU-044)

## Preserve
- The login flow must still work end-to-end
- Existing user data must round-trip after migration

## Acceptance
- Migration runs clean against a copy of prod (you have access via the test runner)
- Paste `\d accounts` output showing the renamed table + FKs
- Paste `npm test` output showing all tests green
- Paste a curl-and-response showing /login still works with an existing test account
- If migration fails or any test breaks: STOP and banner with the failure - do NOT continue.

## Notes
- Branch: `feature/rename-users-to-accounts`
- Push to `origin/dev` on clean complete per CC push policy
- Reply file: `comms/open/RU-042-rename-user-table/RU-042-rename-user-table-reply.md`
- Banner at end.
```

The acceptance is behavioral (paste output, run actual queries) and has an explicit STOP clause. The notes section reminds CC of the banner contract.
