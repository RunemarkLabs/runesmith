---
name: start-sprint
description: "Hand a Jira sprint to Claude Code: turn the sprint's tickets into task comms and give the /goal line that starts them. Use when the user says \"start sprint\", \"begin sprint\", \"start sprint X\", \"kick off the sprint\", \"kick off the next sprint\", or wants to hand a sprint's work to Claude Code."
compatibility: Runs in the planner chat with the project's workspace folder connected. Atlassian-enabled projects only.
---

# Start Sprint

Read the sprint from Jira, turn its tickets into task comms through `runesmith-sprint:task`, record the sprint as active, and give one `/goal` line. Claude Code works from task comms, not by picking tickets itself.

## References

- `lib/atlassian-enabled.md` - must be enabled
- `lib/atlassian-rest.md` - sprint and issue endpoints
- `lib/comms-protocol.md` - task comm layout and the `ticket:` field
- `lib/planner-task-method.md` - task template and goal line rules
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured prompts for every decision

## User input rules

Every decision that is the owner's is a structured prompt with the recommended option first. Ask only when the answer changes what gets written.

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. If a goal is running, everything this skill writes is for after its banner.

### 1. Atlassian enabled

If not: say so and point at `runesmith-sprint:enable`.

### 2. Head exists

`{PROJECT}.cc/comms/open/` must exist. If not: point at `runesmith-workspace:init`.

## Workflow

### 1. Pick the sprint

Default: the board's active sprint, `GET {SITE_URL}/rest/agile/1.0/board/{BOARD_ID}/sprint?state=active`. An explicit sprint id from the owner wins. Several active sprints: structured pick. None active: list future sprints for a structured pick, or say to start one in Jira.

### 2. Read the tickets

`GET {SITE_URL}/rest/agile/1.0/sprint/{SPRINT_ID}/issue`. Skip tickets already done, and tickets already named in a task comm in `open/` (the `ticket:` field).

### 3. Group them

Show the tickets as a table: key, summary, status. Propose task groupings: related tickets combine into one task; tickets the owner will want to see separately go in separate goals. One structured prompt to accept or adjust the grouping.

### 4. Write the tasks

For each group, run the `runesmith-sprint:task` workflow: issues first, the template, `ticket: {KEY}` in front matter (the first key when a task covers several, all keys in the `Issues:` line), references copied in, the decision logged.

### 5. Record the sprint

Set `atlassian.activeSprintId` in `{PROJECT}.cc/.claude-code-workspace`.

### 6. Give the goal line

One line chaining the tasks of the first goal, per `lib/planner-task-method.md`. If the grouping made several goals, give the first and list the rest as queued.

### 7. Report

```
Sprint {SPRINT_ID} ({SPRINT_NAME}): {n} tickets, {m} tasks written
Tasks: comms/open/{UTC}-{slug}/ ...
Logged: plans/active/{plan}/decisions.md
Goal line (paste into Claude Code{, after the current goal's banner}):

/goal ...
```

## Guard Rails

- [ ] Comms check ran first; a running goal respected
- [ ] Sprint confirmed (active by default; explicit id wins)
- [ ] Tickets already done or already in a task skipped
- [ ] Grouping shown and accepted before writing
- [ ] Every task written through the `task` workflow, with `ticket:` set
- [ ] Marker `activeSprintId` updated
- [ ] No Jira writes (reads only)

## Error Cases

**No sprints on the board:** say so; give the board's address so the owner can create one.
**Sprint id doesn't exist:** check with `GET /rest/agile/1.0/sprint/{id}`; on 404, say so and ask again.
**Jira read refused (allowlist, 401 or 403):** say which; nothing is written.
**Every ticket already in a task:** say so; give the goal line for the open tasks if none is running.
