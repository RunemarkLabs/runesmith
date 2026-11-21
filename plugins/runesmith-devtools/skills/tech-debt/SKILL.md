---
name: tech-debt
description: "Scan the workspace for stale, orphaned, or unreferenced artifacts using a cross-reference graph (plans → refs/tickets/decisions → research/source-docs/drafts). Identifies what is ACTUALLY tech debt - content that no longer traces back to a live plan, ticket, or decision. Workspace-side only; never enters source repos. Use after a round of changes, when things feel messy, proactively between work sessions, or to verify cleanliness before a release. Triggers on: \"tech debt\", \"clean up\", \"stale files\", \"what's out of date\", \"is anything orphaned\"."
model: haiku
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Workspace Tech Debt Scanner

Identify workspace content that is no longer alive - orphaned, unreferenced, or superseded - and propose archive/delete actions with user consent.

Tech debt here means **unreferenced** content, not just old content. Age is a weak signal; cross-references are the real test. A 6-month-old reference doc still cited by an active plan is alive. A 1-week-old draft that nobody points to and references a superseded plan is debt.

**Scope is the workspace only.** This skill does not touch source repos. For code-level tech debt (unused functions, dead classes, leftover scaffolding from refactors), see `runesmith-cc:code-tech-debt` - a CC-side skill template deployed by `runesmith-cc:head`.

## References

- `agents/workspace-scanner.md` - subagent for directory walk + raw findings
- `lib/folder-conventions.md` - canonical layout this skill scans against
- `lib/user-prompts.md` - structured-input requirement for any user prompt

## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI. Never freeform plain-text yes/no.

## Pre-Flight Checks

No pre-flight checks needed. This is a read-only scan until the user consents to act on findings.

## When to Use

Use for:
- Proactive workspace hygiene between sessions
- After completing a major project phase
- When the workspace feels cluttered or you suspect orphans
- Before tagging a release - verify no stale plan/draft/research is shipping
- After running `/runesmith-workspace:init` to verify nothing fell through

Do **not** use for:
- Scanning source-repo tech debt (use `/runesmith-cc:code-tech-debt` deployed inside `{PROJECT}.cc/{repo}/`)
- Workspace structure migration (that's `/runesmith-workspace:init`)
- Bulk auto-deletion (always ask before any move)

## Boundary

Tech-debt **never enters `{PROJECT}.cc/{repo}/`**. The CC head's repos are CC's territory. The workspace's job ends at the boundary.

Tech-debt **does** scan `{PROJECT}.cc/comms/archive/` if asked (rare - archive is the audit trail, usually preserved).

## Workflow

### 1. Build cross-reference graph (on the fly by default)

Walk the canonical workspace dirs and build an in-memory graph:

**Nodes** (the things that can be alive or dead):
- Each `plans/active/{slug}/` plan + its `decisions.md` + `refs/{file}` + `tickets/{id}.json`
- Each `plans/archive/{YYYY-MM}/{slug}/` plan
- Each `notes/{file}.md`
- Each `drafts/{features,project-docs,bugs}/{slug}/` draft
- Each `research/{topic}/{file}`
- Each `source-docs/{topic}/{file}`
- Each `archive/superseded/{YYYY-MM}/{entry}`
- Each `archive/tickets-pushed/{YYYY-MM}/{KEY}.json`
- Each operation snapshot under `archive/_pre-*/{ISO}/`
- Each `plugins/{plugin}/` (for marketplace dev workspaces)

**Edges** (the references that keep nodes alive):
- Active plan `plan.md` cites `refs/{file}.md` in its References section → that ref is referenced
- Active plan frontmatter `tickets:` array → those Jira keys are referenced (the archived JSON in `archive/tickets-pushed/{YYYY-MM}/{KEY}.json` is alive as history)
- Active plan `decisions.md` mentions another plan slug → that plan is referenced
- Plan `supersedes:` field → the superseded plan is referenced (as a history pointer)
- `notes/{file}.md` content mentions a plan slug or draft slug → that slug is referenced
- A draft folder's slug appears in any active plan → the draft is referenced
- `{PROJECT}.cc/comms/open/` content mentions a plan slug → that plan is referenced

**Liveness rules**:
- `status: open | building | blocked` plan = ALIVE
- `status: done | superseded` plan in `plans/active/` = should-be-archived (debt: structural)
- Plan in `plans/archive/` = preserved history, not debt
- Anything referenced (transitively) from an alive plan = ALIVE
- Anything not referenced by an alive plan or a recent (< 30 day) note = ORPHAN candidate

**Toggle for cached graph**:
- Default: rebuild graph on every run (on-the-fly).
- `--cached` flag (structured prompt option "Use cached graph if available"): read graph from `archive/_workspace-index/{ISO}.json` if present and less than 24 hours old; else rebuild and cache.
- Build the cache as a side effect of any full scan. The graph is small (file paths + edges, no content), so caching costs little.
- If the graph is heavy on a particular workspace (lots of plans, big notes), surface that in the report and recommend the cached flag for subsequent runs.

### 2. Classify findings

For each node, assign a status:

- **alive** - referenced by an active plan, recent note, or open comm
- **structural-debt** - wrong location for its status (e.g. `status: done` plan still in `plans/active/`, pushed ticket draft still in `plans/active/{slug}/tickets/`)
- **orphan** - no live references; candidate for archive
- **superseded-history** - referenced only via `supersedes:` from a newer plan; preserve as history
- **operation-snapshot-stale** - `archive/_pre-*/` snapshot older than 90 days
- **broken** - structural issue (e.g. plugin missing `.claude-plugin/plugin.json`, ticket JSON whose plan slug doesn't exist)
- **unknown** - outside the canonical layout (shouldn't exist after reallocate; flag for inbox routing)

### 3. Group findings + propose action

```
Workspace tech debt scan ({N} nodes, {M} edges)

Structural debt (wrong location)
  plans/active/old-rewrite/  status: done  → plans/archive/2026-05/old-rewrite/?
  plans/active/api-v2/tickets/draft-001.json  pushed as PROJ-42  → archive/tickets-pushed/2026-05/?

Orphans (no live references)
  research/edge-comparison/  last referenced never  → archive/superseded/2026-05/research-edge-comparison/?
  drafts/features/billing-old/  references superseded plan billing-v1  → archive/superseded/2026-05/draft-billing-old/?
  source-docs/vendor-api-v0/  consumed by archived plan api-v1  → archive/superseded/2026-05/source-vendor-api-v0/?
  notes/2025-12-15-thoughts.md  no slug mentions, >90 days old  → archive/superseded/2026-05/notes/?

Operation snapshots (stale)
  archive/_pre-migration/2026-01-15T.../  > 90 days  → safe to delete
  archive/_pre-cc-bootstrap/2026-02-03T.../  > 90 days  → safe to delete

Broken
  plans/active/orphan-tickets/tickets/draft-007.json  plan dir doesn't exist  → route via inbox?
  plugins/runesmith-broken/  missing .claude-plugin/plugin.json  → fix or remove?

Alive (informational)
  {N} active plans, {M} live refs, {P} draft slugs in-flight
```

### 4. Get cleanup approval (structured, per category)

Surface a structured multi-pick:

```
What do you want to act on?
  [ ] Structural debt (move to canonical location)
  [ ] Orphans (archive to archive/superseded/{YYYY-MM}/)
  [ ] Operation snapshots > 90 days (delete)
  [ ] Broken items (review individually)
  [ ] Nothing - preview only
```

Then per selected category, a per-item structured prompt or batch-confirm.

Trigger phrase ("clean up", "archive them", "apply") gates the destructive moves per `lib/consent.md`.

### 5. Execute cleanup

Per approved row:
- Snapshot to `archive/_pre-tech-debt/{ISO}/` before any move or delete
- Move per the proposed target (or delete for operation snapshots)
- Update graph cache if `--cached` was used

### 6. Report

```
✓ Workspace tech debt addressed
Snapshot: archive/_pre-tech-debt/{ISO}/

Resolved: {N} items
  - structural debt: {n}
  - orphans archived: {n}
  - operation snapshots deleted: {n}
  - broken items: {n} fixed, {n} surfaced for manual review

Workspace state: {clean | needs review | major-debt}
Live graph: {N} active plans, {M} references, {O} orphans remaining
```

## Guard Rails

- [ ] Scan is read-only until user explicitly consents to act
- [ ] Reference graph built per `lib/folder-conventions.md` taxonomy
- [ ] On-the-fly by default; cached mode opt-in via structured option
- [ ] Boundary respected: never enters `{PROJECT}.cc/{repo}/`
- [ ] Snapshot to `archive/_pre-tech-debt/{ISO}/` before any move or delete
- [ ] Per-category consent via structured multi-pick
- [ ] Broken items surfaced, never auto-fixed without per-item user input
- [ ] Reallocate-style structural moves (e.g. `status: done` plan to archive) handled here, not duplicating reallocate's job
- [ ] No code analysis - that's `runesmith-cc:code-tech-debt`

## Error Cases

**No tech debt found:** "Workspace is clean. {N} active plans, {M} alive references, 0 orphans."
**Reference graph fails to build:** Surface the path that broke, abort the scan, suggest running `/runesmith-workspace:init` first if structure is non-canonical.
**Orphan's content suggests it might still be relevant:** Surface the head + filename; ask user to confirm orphan status before archive (don't auto-archive content with recent edits or referenced filenames in headers).
**Plan slug referenced by note but plan doesn't exist:** Flag the note as having a stale reference; surface for user to update.
**Cache exists but is older than 24 hours:** Rebuild silently; offer to use cache anyway via structured prompt if user wants fast preview.

## Relationship to reallocate

`reallocate` does one-shot structural migration (initialize / restructure / normalize). `tech-debt` does ongoing hygiene within the canonical structure. Some overlap is intentional:

- Reallocate: "Is the workspace shaped correctly?"
- Tech-debt: "Within the correct shape, is anything stale or orphaned?"

If a workspace fails both checks (non-canonical AND has orphans), run reallocate first, then tech-debt.
