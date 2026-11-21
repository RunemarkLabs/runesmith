---
name: enable
description: "Turn on Jira and Confluence for this project: record the Jira project, board and Confluence space, apply the Atlassian sections to both CLAUDE.md files, deploy Claude Code's Jira skills, and give the Project Instructions supplement. runesmith-workspace:init runs this when you answer yes to Jira. Use when the user says \"enable atlassian\", \"wire up Jira\", \"turn on Jira\", \"connect Confluence\", or \"make this project use Jira\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Enable Atlassian

Turns on the Jira and Confluence workflow: plans become Jira tickets, sprints become task comms through `runesmith-sprint:start-sprint`, and documents publish to Confluence. Claude Code reads tickets with a read-only token; every Jira change goes through the planner. Idempotent.

## References

- `lib/atlassian-rest.md` - endpoints
- `lib/credentials.md` - the planner's and Claude Code's keys
- `lib/atlassian-enabled.md` - the marker file
- `lib/jira-apply.md` - the exact CLAUDE.md sections applied
- `lib/jira-tags.md` - ticket labels
- `lib/comms-protocol.md` - the `ticket:` field and `ticket-transition`
- `lib/comms-check.md` - runs first
- `lib/user-prompts.md` - structured prompts

## Interview rule

Show first, then ask. Ask only when the answer changes what gets built. When `runesmith-workspace:init` calls this skill, it has already asked; take its answers.

## Pre-Flight Checks

### 0. Comms check

See `lib/comms-check.md`.

### 1. Workspace

From the session's connected folders. Note whether there's a head: code projects get the Claude Code parts (steps 6 to 8); workspace-only projects don't.

### 2. Planner's Atlassian keys

`ATLASSIAN_API_URL`, `ATLASSIAN_API_EMAIL`, `ATLASSIAN_API_TOKEN` in `{WORKSPACE_ROOT}/.credentials`. Missing: follow `runesmith-core:setup` step 3 (tell the owner which keys to paste where), then continue.

## Workflow

### 1. Project values

- **Site:** default from `ATLASSIAN_API_URL`.
- **Jira project key:** text input; then look up its id with `GET {SITE}/rest/api/3/project/{KEY}`.
- **Board:** list the project's boards with `GET {SITE}/rest/agile/1.0/board?projectKeyOrId={KEY}` and pick one.
- **Confluence space key:** text input; then look up its id with `GET {SITE}/wiki/api/v2/spaces?keys={KEY}`.

### 2. Claude Code's token (code projects)

- **Its own read-only token** (default): the owner pastes `CC_ATLASSIAN_API_EMAIL` and `CC_ATLASSIAN_API_TOKEN` into `{PROJECT}.cc/.credentials`. Recommend a token scoped to read Jira.
- **Reuse yours:** the owner pastes his own values under the `CC_` names. Say plainly that Claude Code can then change Jira directly.

Never asked for in chat. `ATLASSIAN_BOARD_ID` is written by this skill (it isn't secret).

### 3. Show the plan, get consent

```
Jira: {SITE} / project {KEY} (id {ID}) / board {BOARD_ID}
Confluence: {SPACE_KEY} (id {SPACE_ID})
Changes:
  {WORKSPACE_ROOT}/CLAUDE.md                 Atlassian section
  {PROJECT}.cc/CLAUDE.md                     Atlassian section (code projects)
  {WORKSPACE_ROOT}/.atlassian-enabled        created
  {PROJECT}.cc/.claude-code-workspace        atlassian block (code projects)
  {PROJECT}.cc/.claude/skills/runesmith-*    Jira builder skills (code projects)
```

Structured prompt: **Apply** (default) / **Cancel**. Skipped when init already had consent.

### 4. Snapshot

Copy the files that will change to `archive/_pre-enable-{UTC}/`.

### 5. Workspace changes

- Apply the workspace section from `lib/jira-apply.md` between `<!-- atlassian-section:start -->` and `<!-- atlassian-section:end -->` in the root CLAUDE.md; add the markers if missing. A start marker without its end: stop and report.
- Write `{WORKSPACE_ROOT}/.atlassian-enabled` (informational; its presence is the signal).

### 6. Head changes (code projects)

- Apply the builder section from `lib/jira-apply.md` between the head CLAUDE.md's `atlassian-section` markers. Nothing else in that file changes.
- Set `atlassianEnabled: true` and the `atlassian` block in `.claude-code-workspace`: site, project key and id, board id, `activeSprintId: null`, space key and id.
- In `{PROJECT}.cc/.credentials`, make sure RuneSmith's "Atlassian (Claude Code, read-only)" block exists (format in `lib/credentials.md`; inside runestack's zone 1 when runestack is in use) and set its `ATLASSIAN_BOARD_ID='{BOARD_ID}'`. Leave the token lines for the owner.

### 7. Claude Code's Jira skills (code projects)

Copy each from `cc-skill-templates/` into its own prefixed folder, one level under `.claude/skills/`:
- `runesmith-sprint-pull/` (reads the current task's tickets; never picks work)
- `runesmith-ticket-document/`
- `runesmith-blocker-write/`
- `runesmith-ticket-done/`

Copy `lib/jira-tags.md` into each that references it. Keep a copy the project changed; report it. Move legacy `.claude/skills/atlassian/` to the snapshot once the prefixed copies are in place.

### 8. Check Claude Code's token

Once the owner says the token is pasted: `GET {SITE}/rest/api/3/myself` with the `CC_` keys. Report the result; tell an allowlist refusal apart from a 401.

### 9. Project Instructions supplement

The owner pastes this at the end of the Project's instructions on claude.ai. `runesmith-workspace:init` includes it automatically in its full block, so after init there's nothing extra to paste.

```
<!-- runesmith:atlassian-start -->
## ATLASSIAN
This project uses Jira and Confluence. Plans become Jira tickets; decisions and design documents become Confluence pages.

- Jira holds work state. Confluence holds lasting documents.
- Reading is free. Creating a ticket, publishing a page, moving a ticket or commenting needs the owner's explicit word: "make the ticket", "create the document", "publish the page".
- Claude Code reads tickets with a read-only token. When it needs a ticket moved, it writes a `ticket-transition` comm in its task's folder, and the planner moves the ticket through the Jira REST API on check comms.
<!-- runesmith:atlassian-end -->
```

### 10. Report

```
Jira and Confluence on
Jira: {KEY} on {SITE}, board {BOARD_ID}
Confluence: {SPACE_KEY}
Sections applied: {WORKSPACE_ROOT}/CLAUDE.md{, {PROJECT}.cc/CLAUDE.md}
Claude Code skills: runesmith-sprint-pull, runesmith-ticket-document, runesmith-blocker-write, runesmith-ticket-done
Claude Code's token: ok | missing: paste CC_ATLASSIAN_API_EMAIL and CC_ATLASSIAN_API_TOKEN into {PROJECT}.cc/.credentials
Snapshot: archive/_pre-enable-{UTC}/
Next: /runesmith-sprint:start-sprint turns the active sprint into task comms
```

## Re-running

Asks the project values again with the current ones as defaults, replaces the sections between markers, refreshes the marker block and the skills (keeping project-changed copies).

## Guard Rails

- [ ] No credential asked for in chat, printed or masked
- [ ] Planner's keys at the workspace root; Claude Code's in the head; none in a repo folder
- [ ] Snapshot and consent before any change
- [ ] Only the `atlassian-section` markers edited in either CLAUDE.md; a damaged marker stops the run
- [ ] Skills deployed one level under `.claude/skills/` with the `runesmith-` prefix
- [ ] No Jira writes; reads only, to look up ids
- [ ] Every value from the owner or the credentials file; no company-specific defaults

## Error Cases

**Project key not found:** ask again; check the owner can see the project.
**No boards:** say so, with the address to create one.
**Claude Code's token can't read Jira:** say so; it needs at least read access.
**Workspace CLAUDE.md missing:** run `runesmith-workspace:init` first.
**Lookup refused by the session's network allowlist:** say the host isn't reachable from this session; nothing is written.
