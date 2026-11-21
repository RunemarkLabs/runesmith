---
name: disable
description: "Turn off Jira and Confluence for this project: empty the Atlassian sections in both CLAUDE.md files, clear the head's Atlassian settings, remove Claude Code's Jira skills, and give the Project Instructions removal. The inverse of enable. Use when the user says \"disable atlassian\", \"turn off Jira\", \"unwire Jira\", or \"remove atlassian from this project\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Disable Jira and Confluence

The inverse of `runesmith-sprint:enable`. Safe to re-run. Comms, plans, ticket history and credentials stay as they are.

## References

- `lib/atlassian-enabled.md` - the marker file
- `lib/jira-apply.md` - the sections enable applied
- `lib/credentials.md` - why credentials are left alone
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured prompts

## User input rules

Every decision is a structured prompt with the recommended option first, per `lib/user-prompts.md`. Never a freeform yes or no.

## Pre-Flight Checks

### 0. Comms check

See `lib/comms-check.md`. Open `ticket-transition` comms are named in the plan below: after disable, the planner no longer moves tickets.

### 1. State

Read `{WORKSPACE_ROOT}/.atlassian-enabled` and, when there's a head, `atlassianEnabled` in `{PROJECT}.cc/.claude-code-workspace`.
- Both off: say "Jira is already off for this project" and stop.
- They disagree: say which says what; the plan below turns off both.

## Workflow

### 1. Show the plan, get consent

```
Turn off Jira and Confluence for {PROJECT}
Changes:
  {WORKSPACE_ROOT}/CLAUDE.md                  Atlassian section emptied (markers kept)
  {PROJECT}.cc/CLAUDE.md                      Atlassian section emptied (code projects)
  {WORKSPACE_ROOT}/.atlassian-enabled         removed
  {PROJECT}.cc/.claude-code-workspace         atlassianEnabled false, atlassian null
  {PROJECT}.cc/.claude/skills/runesmith-sprint-pull, -ticket-document, -blocker-write, -ticket-done   moved to the snapshot
Kept: credentials files, comms, plans and their tickets/, archive/tickets-pushed/, everything in Jira and Confluence
Open ticket-transition comms: {n, or none}
```

Structured prompt: **Turn off Jira** (default) / **Cancel**.

### 2. Snapshot

Copy every file that will change or move to `archive/_pre-disable-{UTC}/`.

### 3. Empty the CLAUDE.md sections

In the root `CLAUDE.md` and, for code projects, `{PROJECT}.cc/CLAUDE.md`: replace what's between `<!-- atlassian-section:start -->` and `<!-- atlassian-section:end -->` with one empty line. Keep the markers so a later enable is clean. Nothing outside them changes. A start marker without its end: stop and report.

### 4. Head marker file (code projects)

In `{PROJECT}.cc/.claude-code-workspace`, set `atlassianEnabled` to `false` and `atlassian` to `null`. Keep every other field.

### 5. Remove the marker file

Remove `{WORKSPACE_ROOT}/.atlassian-enabled`. Deleting needs the folder's delete permission; ask once if it isn't granted. If declined, move the file to `_to_delete/` and say so.

### 6. Claude Code's Jira skills (code projects)

Move `runesmith-sprint-pull/`, `runesmith-ticket-document/`, `runesmith-blocker-write/` and `runesmith-ticket-done/` from `{PROJECT}.cc/.claude/skills/` into the snapshot. A legacy `.claude/skills/atlassian/` folder goes the same way. Never touch other `runesmith-*` or `runestack-*` skills.

### 7. Project Instructions

This session can't edit the Project's instructions. Tell the owner to delete the block from `<!-- runesmith:atlassian-start -->` through `<!-- runesmith:atlassian-end -->`, both lines included, from the Project's instructions on claude.ai. Or re-run `runesmith-workspace:init`, whose fresh block leaves it out.

### 8. Report

```
Jira and Confluence off
Sections emptied: {WORKSPACE_ROOT}/CLAUDE.md{, {PROJECT}.cc/CLAUDE.md}
Removed: .atlassian-enabled; Claude Code's Jira skills (in the snapshot)
Kept: credentials (remove the Atlassian keys yourself if you want them gone), comms, plans, ticket history
Project Instructions: delete the runesmith:atlassian block
Snapshot: archive/_pre-disable-{UTC}/
Turn it back on with /runesmith-sprint:enable
```

## Guard Rails

- [ ] Comms check ran first
- [ ] Consent through a structured prompt; never a freeform yes
- [ ] Snapshot before any change
- [ ] Only the `atlassian-section` content emptied; markers kept; a damaged marker stops the run
- [ ] Only the four Jira skills moved; no other skill touched
- [ ] No credentials file edited
- [ ] No comms, plans or Jira data touched

## Error Cases

**Already off:** say so and stop.
**Marker and head disagree:** report both values; the plan turns off both.
**No head:** workspace changes only; say there's no head.
**Delete permission declined:** move `.atlassian-enabled` to `_to_delete/` and tell the owner.
