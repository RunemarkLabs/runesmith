---
name: sprint-pull
description: "Read the Jira tickets named in the current task comm, plus the active sprint for context. Use when a task comm carries a ticket: field, or to see where the sprint stands. Never picks work: the planner assigns work through task comms. Runs in Claude Code."
compatibility: Runs in Claude Code, inside the project's head.
---

# Sprint Pull (CC-side)

Read the tickets a task comm names (its `ticket:` field and `Issues:` line), and the active sprint for context, through Jira REST with Claude Code's read-only token. This skill reads only and never picks work: the planner turns sprint tickets into task comms, and the owner starts them with a `/goal` line.

This skill is deployed to `{PROJECT}.cc/.claude/skills/atlassian/` by `/runesmith-sprint:enable` running in Cowork. Do not edit it directly here unless you intend the change to flow to all future enables.

## References

- `.claude-code-workspace` (marker, in CC root) - for `atlassian.activeSprintId`, `boardId`, `jiraProjectKey`, `siteUrl`
- `.credentials` (in CC root) - for auth
- `@lib/jira-tags.md` - tag taxonomy

## Pre-Flight Checks

### 1. Marker exists

Read `.claude-code-workspace`. Verify `atlassianEnabled: true`. If false: report and exit. CC is in a non-atlassian workspace.

### 2. Credentials

The head's `.credentials` has `CC_ATLASSIAN_API_EMAIL`, `CC_ATLASSIAN_API_TOKEN` and `ATLASSIAN_BOARD_ID`; the site address comes from the marker's `atlassian.siteUrl`. Read each key only inside the command that uses it; never print it. If missing: write a `user-action` comm in the current task's folder asking the owner to re-run `/runesmith-sprint:enable`, and mark the task blocked.

## Workflow

### 1. Determine target sprint

Read `atlassian.activeSprintId` from marker. If null, look up active sprint:

```
GET {SITE_URL}/rest/agile/1.0/board/{BOARD_ID}/sprint?state=active
```

Pick first; cache as `activeSprintId` in marker (write back).

### 2. Fetch sprint tickets

```
POST {SITE_URL}/rest/api/3/search/jql
{
  "jql": "sprint = {SPRINT_ID} ORDER BY status ASC, priority DESC",
  "fields": ["summary", "description", "status", "assignee", "priority",
             "labels", "issuelinks", "customfield_10014"],
  "maxResults": 100
}
```

(`customfield_10014` is the Jira default Epic Link field; may differ - discover via `GET /rest/api/3/field` once per session.)

### 3. Filter by current state

Categorize tickets:
- **Available** - `status: "To Do"` or `status: "Selected for Development"`, NOT `cc-blocked`
- **In progress** - `status: "In Progress"`, possibly with my prior `cc-plan` / `cc-action` activity
- **Blocked** - labels include `cc-blocked` (these need human attention via comms; CC should not pick these)
- **Done** - `status: "Done"`

### 4. Read the task's tickets

For each key the current task names, read the full description, acceptance criteria and linked issues. The sprint list below is context only:

```
Sprint {SPRINT_ID} - {SPRINT_NAME}

In progress (n)
  {KEY-1}  {priority}  {summary}
Available (n)
  {KEY-2}  {priority}  {summary}
  {KEY-3}  {priority}  {summary}
Blocked (n)
  {KEY-X}  cc-blocked   {summary}   (skip - needs Cowork or user)
Done (n)
  {KEY-Y}  cc-done      {summary}   (awaits transition)
```

Work only what the task comm asks. Use the `ticket-document` skill to record your plan as a `cc-plan` comment before starting. A ticket outside the current task is never started on your own.

## Guard Rails

- [ ] Read-only - never POST/PUT/DELETE to Jira from this skill
- [ ] Marker `activeSprintId` cached and updated when sprint changes
- [ ] Never picks or starts a ticket the current task doesn't name
- [ ] Surface up to first 100 tickets; paginate if more
- [ ] No company-specific assumptions about field ids - discover via `GET /rest/api/3/field`

## Error Cases

**No active sprint:** Report it in the reply; the task's own tickets are still read by key.
**401:** Token expired or wrong. Write a `user-action` comm in the task's folder: "Claude Code's read-only Jira token failed. Re-run `/runesmith-sprint:enable` to refresh it." Mark the task blocked.
**Ticket named in the task doesn't exist:** Write an `ambiguity` comm in the task's folder naming the key, and mark the task blocked.
**Network failure:** Retry once. If still failing, write a `blocker` comm in the task's folder and mark the task blocked.

---

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
