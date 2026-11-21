---
name: project-status
description: "Get a quick project status from Jira. Use when the user says \"what's the status\", \"where are we\", \"what's in progress\", \"what's in the backlog\", \"project update\", \"show me the board\", or asks about current work state. Also triggers on \"any blockers\", \"what's next\", or \"sprint status\"."
model: haiku
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Project Status

Quick status check from Jira - what's in progress, done, blocked, backlog.

Read-only. No consent gate required.

## References

- `lib/atlassian-rest.md` - `/search/jql` POST
- `lib/credentials.md`
- `lib/tokens.md`
- `lib/comms-check.md` - runs first
- See also `runesmith-sprint:sprint-status` for atlassian-enabled sprint-aware view

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved.
2. `{PROJECT_KEY}` resolved.

## When to Use

Use for:
- Quick board view in chat
- Sprint planning context
- Blocker scan

Do not use for:
- Creating / updating tickets
- Long-form status report → `status-report` (in operations plugin)

## Workflow

### 1. Query Jira

```
POST {ATLASSIAN_API_URL}/rest/api/3/search/jql
{
  "jql": "project = {PROJECT_KEY} ORDER BY updated DESC",
  "fields": ["summary", "status", "assignee", "priority", "labels", "updated"],
  "maxResults": 50
}
```

(Do NOT use deprecated `GET /rest/api/3/search`.)

### 2. Group results

By `status.name`:
- In Progress
- Blocked (status=Blocked OR labels contain "blocker")
- Selected for Development / To Do
- Done (last 7 days only)

### 3. Output

```
{PROJECT_KEY} status

In Progress (n)
- KEY-1 summary - assignee
- KEY-2 summary - assignee

Blockers (n)
- KEY-3 summary

Next up (top 3)
- KEY-4 summary
- KEY-5 summary

Recently done (last 7d)
- KEY-6 summary

Board: {ATLASSIAN_API_URL}/jira/software/projects/{PROJECT_KEY}/boards
```

## Guard Rails

- [ ] Credentials, project key resolved
- [ ] Query uses `/search/jql` POST, not GET `/search`
- [ ] Counts accurate
- [ ] Blockers separated
- [ ] Output scannable

## Error Cases

**401:** Re-read `.credentials`, retry once, then "Run `/runesmith-core:setup`."
**404:** "Project {PROJECT_KEY} not found."
**410 / endpoint gone:** Re-check `atlassian-rest.md` for current path.
**Empty:** "No tickets in {PROJECT_KEY}. Try /runesmith-jira:ticket."
