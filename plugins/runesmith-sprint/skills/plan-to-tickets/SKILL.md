---
name: plan-to-tickets
description: "Convert a plan (or several) in plans/active/ into Jira ticket drafts organized by sprint. Drafts persist as JSON under plans/active/{slug}/tickets/{KEY}.json until push; after push they archive to archive/tickets-pushed/{YYYY-MM}/. Use when the user says \"convert this plan to tickets\", \"make tickets from this plan\", \"break down the plan\", \"plan to tickets\", \"ticket up the plan\", or wants to materialize plan work as Jira issues."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Plan to Tickets

Read one or more `plans/active/{slug}/plan.md` files. Decompose into Jira tickets. Write each as JSON under `plans/active/{slug}/tickets/` so the draft state survives across sessions. Organize them into a target sprint (or backlog). User confirms; push via existing ticket flow. After push, archive the JSON drafts to `archive/tickets-pushed/{YYYY-MM}/` for history.

Atlassian-enabled only.

## References

- `lib/folder-conventions.md` - canonical home for ticket drafts (`plans/active/{slug}/tickets/`) and post-push archive (`archive/tickets-pushed/{YYYY-MM}/`)
- `lib/plan-format.md` - how to read plans; directory shape includes `tickets/` subfolder
- `lib/atlassian-rest.md` - endpoints
- `lib/comms-check.md` - runs first
- `lib/atlassian-enabled.md`
- `lib/jira-tags.md` - apply `cowork-planned`, `bootstrap`
- Sibling: `runesmith-jira:ticket` (push flow)
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

### 1. Atlassian enabled

If not: "Atlassian not enabled. Run `/runesmith-sprint:enable` first."

### 2. Plans available

`plans/active/` exists and has at least one plan with `status: open` or `status: building`.

## Workflow

### 1. Pick plans

List all plans in `plans/active/` with `status: open` or `status: building`. Show:

```
Plans available
  [1] {slug}  status: open  ({status sort})
  [2] {slug}  status: building
  ...
```

User picks one or more. Multiple plans can map to one batch of tickets.

### 2. Decompose

For each selected plan, propose a ticket breakdown. Strategy:

- **Plan summary → Epic** (if `status: building` and >5 child tickets, or user opts in).
- **Plan acceptance criteria → Stories** (one ticket per criterion, when criteria are well-formed).
- **Implementation tasks** - derive from plan body (Decision section + any "Implementation" section if the user added one). One Task per discrete work item.
- **Bugs** - only if the plan explicitly identifies known bugs to fix.

Show proposed tickets in a table. For each: Type (Epic / Story / Task / Bug), Summary, Description excerpt, target Sprint (default: backlog; user can pick active sprint).

### 3. Sprint targeting

For each ticket batch:
- Default → Backlog (no sprint id).
- User can route the whole batch into the active sprint or a future sprint.
- Mixed routing supported (some to active sprint, some to backlog).

If targeting a sprint, look up sprint id via `GET /rest/agile/1.0/board/{BOARD_ID}/sprint?state=active` (or future).

### 4. Show full draft + persist as JSON

Render every ticket as the JSON the `runesmith-jira:ticket` skill expects:

```json
{
  "fields": {
    "project":   { "key": "{JIRA_PROJECT_KEY}" },
    "issuetype": { "name": "Task" },
    "summary":   "...",
    "description": {ADF document derived from plan section},
    "labels":    ["cowork-planned", "bootstrap"],
    "priority":  { "name": "Medium" }
  }
}
```

Description ADF includes a link to the plan slug (back-reference).

**Write each ticket JSON to `plans/active/{slug}/tickets/{DRAFT-ID}.json`** where `{DRAFT-ID}` is a deterministic local identifier (e.g. `{slug}-001`, `{slug}-002`). These drafts persist on disk so the plan-to-tickets workflow can resume across sessions and so the user can review them outside chat.

If targeting a sprint, also include sprint assignment via `POST /rest/agile/1.0/sprint/{SPRINT_ID}/issue` after creates.

### 5. Get consent

```
{N} tickets to create:
  Epic:   1   {summary}
  Story:  3   ...
  Task:   5   ...
  Bug:    0

Target: {sprint name | Backlog}

Push these tickets to {JIRA_PROJECT_KEY}?
```

Wait for trigger phrase ("push", "make the tickets", "create them", "yes").

### 6. Push (delegated to ticket skill flow)

For each ticket, call the same REST flow as `runesmith-jira:ticket`:

```
POST {SITE_URL}/rest/api/3/issue
```

Capture each response key.

After all tickets created, if any are sprint-targeted:
```
POST {SITE_URL}/rest/agile/1.0/sprint/{SPRINT_ID}/issue
{ "issues": [{list of new keys}] }
```

If Epic created, link Stories/Tasks to it via the Epic Link custom field (auto-discover via `GET /rest/api/3/field`).

### 7. Update plan

Append the new ticket keys to the plan's frontmatter `tickets:` array. Edit `plan.md` in place (preserving the rest):

```yaml
tickets:
  - {KEY-1}
  - {KEY-2}
```

Touch `updated:` to today's date. If plan was `status: open`, optionally bump to `status: building` (ask user via structured prompt).

### 8. Archive pushed drafts

Per `lib/folder-conventions.md`, after successful Jira push:

- Rename each pushed JSON from `plans/active/{slug}/tickets/{DRAFT-ID}.json` → `plans/active/{slug}/tickets/{JIRA-KEY}.json` (so the on-disk name matches the issued key).
- Move the renamed file to `archive/tickets-pushed/{YYYY-MM}/{JIRA-KEY}.json` for history.
- `plans/active/{slug}/tickets/` ends empty (or holds only unpushed drafts if user partially confirmed).

If any push failed, leave its draft JSON in `plans/active/{slug}/tickets/` for retry; record the failure in the report.

### 9. Report

```
✓ Tickets created from plan(s)
Plans:    {slug-1}, {slug-2}
Tickets:  {N} created
  {KEY-1}  Task   {summary}  → {sprint name | Backlog}
  ...

Sprint assignments: {n}
Plan(s) updated with ticket references.
Drafts archived: archive/tickets-pushed/{YYYY-MM}/

Next: /runesmith-sprint:start-sprint to hand the active sprint to CC, or
      /runesmith-sprint:sprint-status to see board state.
```

## Guard Rails

- [ ] Comms check ran first
- [ ] Atlassian enabled
- [ ] At least one plan selected
- [ ] Ticket types match plan content (no bugs unless plan identifies them)
- [ ] All tickets carry `cowork-planned` + `bootstrap` labels
- [ ] Description ADF includes plan slug back-reference
- [ ] Draft JSON written to `plans/active/{slug}/tickets/` BEFORE push consent
- [ ] User explicitly consented before push
- [ ] Each ticket POST succeeds before sprint assignment
- [ ] Plan(s) updated with new keys
- [ ] Pushed drafts archived to `archive/tickets-pushed/{YYYY-MM}/{KEY}.json`
- [ ] Failed pushes leave draft JSON in `plans/active/{slug}/tickets/` for retry
- [ ] No duplicate ticket creation if plan was previously processed (skill checks plan's existing `tickets:` and asks before adding more)

## Error Cases

**No plans with status open or building:** "No active plans to convert. Create one with `/runesmith-core:plan` first."
**Plan body missing acceptance criteria:** Skill asks user to add them inline before decomposition, or proceeds with Task-only breakdown.
**Sprint id lookup fails:** Default to Backlog; surface the failure but continue.
**Ticket create 400 (custom field required):** Surface field name; ask user to fill or use a Story type that doesn't require it.
**Plan already has tickets[] populated:** Show existing keys; ask "Add more, replace, or skip?"
**Sprint full / capacity warning:** Note in report, doesn't block.
