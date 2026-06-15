---
name: enable
description: "Wire Atlassian into this project - collect Jira project + Confluence space details, apply workflow rules into both CLAUDE.md files, deploy CC-side skills, and write the .atlassian-enabled marker. Use when the user says \"enable atlassian\", \"wire up Jira\", \"connect Atlassian to this project\", \"turn on atlassian\", \"set up sprint workflow\", or \"make this project use Jira\"."
compatibility: Requires Cowork desktop app environment.
---

# Enable Atlassian Interconnect

Turn on the Atlassian-driven workflow for the current project: plans → Jira tickets → sprints, with CC reading sprints and routing mutations through comms.

Idempotent. Re-running refreshes applied sections in place without duplicating.

## References

- `lib/atlassian-rest.md` - endpoints
- `lib/credentials.md` - auth
- `lib/comms-check.md` - runs first
- `lib/atlassian-enabled.md` - marker semantics
- `lib/jira-apply.md` - exact applied content
- `lib/sprint-handshake.md` - first-sprint comm flow
- `lib/jira-tags.md` - tag taxonomy
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`.

### 1. Workspace state

- Workspace root resolved.
- `{PROJECT}.cc/` exists (with valid `.claude-code-workspace` marker). If not: "Run `/devtools:bootstrap-cc` first."
- Atlassian credentials present in `.credentials` (full-access for Cowork-side operations).

### 2. Detect existing enable

Check `<workspace-root>/.atlassian-enabled` and CC marker `atlassianEnabled` flag. If both set: "Already enabled. Re-run will refresh applied sections and revalidate config."

## When to Use

Use for:
- First-time Atlassian setup on a project
- Refreshing the section markers after CLAUDE.md template updates
- Re-pointing the project at a different Jira project / Confluence space (effectively a re-enable)

Do not use for:
- Disabling → `/atlassian:disable`
- Changing only one field - re-run is fine, asks every value

## Workflow

### 1. Gather Atlassian project values

Prompt user for the **user's** Atlassian configuration (not the marketplace's):

- **Site URL** - e.g. `https://acme.atlassian.net`. Default from `ATLASSIAN_API_URL` in `.credentials`.
- **Jira project key** - e.g. `ACME`. Default from `ATLASSIAN_JIRA_PROJECT_KEY` if set.
- **Jira project id** - auto-discover via `GET {site}/rest/api/3/project/{key}` (capture `id`).
- **Board id** - list user's boards via `GET {site}/rest/agile/1.0/board?projectKeyOrId={key}` and let them pick. Capture `id`.
- **Confluence space key** - e.g. `ACME`. Default from `ATLASSIAN_CONFLUENCE_SPACE_ID` if set.
- **Confluence space id** - auto-discover via `GET {site}/wiki/api/v2/spaces?keys={key}`.

### 2. Read-only Jira PAT for CC

Ask user to provide a separate **read-only Jira API token** for CC's `.credentials`. Open <https://id.atlassian.com/manage-profile/security/api-tokens> in instructions. Recommend a scoped token with read-only Jira access if Atlassian Cloud supports scoped tokens for the user's plan.

If the user prefers, they can re-use the Cowork token (security trade-off - flag clearly).

### 3. Show application plan

Present the full plan:

```
Project values:
  Jira:        {SITE_URL} / project {JIRA_PROJECT_KEY} (id {JIRA_PROJECT_ID}) / board {BOARD_ID}
  Confluence:  {CONFLUENCE_SPACE_KEY} (id {CONFLUENCE_SPACE_ID})

Files to modify:
  <workspace-root>/CLAUDE.md          apply Atlassian Interconnect section
  <workspace-root>/{PROJECT}.cc/CLAUDE.md   apply Atlassian Sprint Workflow section
  <workspace-root>/.atlassian-enabled  create marker file
  <workspace-root>/{PROJECT}.cc/.claude-code-workspace  set atlassianEnabled: true + atlassian block
  <workspace-root>/{PROJECT}.cc/.credentials  add CC-side Jira token
  <workspace-root>/{PROJECT}.cc/.claude/skills/atlassian/  deploy CC skill templates (4 skills + jira-tags.md)

Proceed?
```

### 4. Get consent

Wait for trigger phrase ("enable", "yes", "do it", "wire it up").

### 5. Snapshot

Backup files that will be modified to `archive/_pre-atlassian-enable/<ISO>/`.

### 6. Apply CLAUDE.md sections

Per `lib/jira-apply.md`:

For workspace `CLAUDE.md`:
- If `<!-- atlassian-section:start --> ... <!-- atlassian-section:end -->` exists, replace content between markers.
- Else append a new section with markers.

For `{PROJECT}.cc/CLAUDE.md`:
- Markers exist (template includes them). Replace content between.

Substitute tokens (`{SITE_URL}`, `{JIRA_PROJECT_KEY}`, `{CONFLUENCE_SPACE_KEY}`, `{BOARD_ID}`).

### 7. Write `.atlassian-enabled`

```
<workspace-root>/.atlassian-enabled
```

Contents (informational only - presence of file is the signal):

```
Atlassian interconnect enabled for this project.
Wired by atlassian:enable on {ISO}.
See plugins/lib/atlassian-enabled.md for details.
```

### 8. Update CC marker

Read `{PROJECT}.cc/.claude-code-workspace`. Set:

```json
{
  "atlassianEnabled": true,
  "atlassian": {
    "siteUrl": "{SITE_URL}",
    "jiraProjectKey": "{JIRA_PROJECT_KEY}",
    "jiraProjectId": {JIRA_PROJECT_ID},
    "boardId": {BOARD_ID},
    "activeSprintId": null,
    "confluenceSpaceKey": "{CONFLUENCE_SPACE_KEY}",
    "confluenceSpaceId": {CONFLUENCE_SPACE_ID}
  }
}
```

### 9. Write CC `.credentials`

```
ATLASSIAN_API_URL={SITE_URL}
ATLASSIAN_API_EMAIL={user-email-for-readonly-token}
ATLASSIAN_API_TOKEN={readonly-token}
ATLASSIAN_JIRA_PROJECT_KEY={JIRA_PROJECT_KEY}
ATLASSIAN_BOARD_ID={BOARD_ID}
```

Mode `0600`. Add to CC `.gitignore` if not already.

### 10. Deploy CC skills

Copy from `plugins/atlassian/cc-skill-templates/` to `{PROJECT}.cc/.claude/skills/atlassian/`:
- `sprint-pull/`
- `ticket-document/`
- `blocker-write/`
- `ticket-done/`

Also copy `plugins/lib/jira-tags.md` → `{PROJECT}.cc/.claude/skills/atlassian/jira-tags.md` so CC can `@reference` it.

### 11. Trigger first sprint handshake (optional)

Ask user: "Start the active sprint now? (Cowork will write a sprint-init task comm to CC.)"

If yes: hand off to `/atlassian:start-sprint` with `sprintId = current-active`. If no: skip; user can run `/atlassian:start-sprint` later.

### 11a. Emit Project Instructions supplement (CRITICAL - don't skip)

Cowork's Project Instructions UI field is invisible to the agent. Enable cannot edit it directly. It MUST surface text for the user to paste.

Reallocate emits the BASE Project Instructions (no Atlassian content - see `runesmith-workspace/lib/project-instructions.md`). Sprint:enable adds the Atlassian supplement, wrapped in HTML-comment markers so disable can identify and remove it later.

Surface in the final report inside a clearly-labelled code block:

```
─────────────────────────────────────────────────────────────
PROJECT INSTRUCTIONS - atlassian supplement

Cowork's Project Instructions field (app sidebar → project
settings → Instructions) does not get edited automatically.
Append the block below to your existing Project Instructions
in Cowork's UI - the markers let /runesmith-sprint:disable
remove it cleanly later.
─────────────────────────────────────────────────────────────

<!-- runesmith:atlassian-start -->
## ATLASSIAN
This project uses Atlassian Cloud (Jira + Confluence). Sprint workflow is
active; plans flow into Jira tickets, decisions and design docs flow into
Confluence pages.

- Jira owns work state. Confluence owns durable docs.
- Read freely. Mutations (ticket create, page publish, transition, comment)
  require an explicit user trigger phrase: "make the ticket", "create the
  document", "publish the page".
- For Claude Code-side work on tickets, see the comms-protocol details in
  @CLAUDE.md.

### Atlassian-supplemental comm type

This project's comms enum adds one gated value on top of the four core types
(`task | answer | blocker | ambiguity`):

- `ticket-transition` (cc -> cowork) - CC has read-only Jira access; when CC
  needs to transition a ticket (e.g. "Done"), it writes a comm of this type
  and Cowork executes the transition via MCP on triage.

The other gated value, `user-action`, is still available across all projects
(cc -> user via cowork, manual step). `session-init`, `confirmation`, and
`handshake` are not in the active enum.
<!-- runesmith:atlassian-end -->
```

Substitute no tokens - the block is generic across Atlassian-enabled projects.

### 12. Report

```
✓ Atlassian enabled
Project: {JIRA_PROJECT_KEY} on {SITE_URL}
Board:   {BOARD_ID}
Space:   {CONFLUENCE_SPACE_KEY}

Applied sections in:
  <workspace>/CLAUDE.md
  <workspace>/{PROJECT}.cc/CLAUDE.md

Deployed CC skills:
  {PROJECT}.cc/.claude/skills/atlassian/  (sprint-pull, ticket-document, blocker-write, ticket-done)

Snapshot: archive/_pre-atlassian-enable/<ISO>/

Next:
  /atlassian:start-sprint   - hand the active sprint to CC
  /atlassian:plan-to-tickets - convert plans to Jira tickets
```

## Idempotent re-run

- Re-collects project values (defaults populated from existing marker).
- Replaces application content between markers (never duplicates).
- Refreshes CC marker `atlassian` block.
- Re-deploys CC skills (overwrites templates with current versions; preserves user-customized skills if file changed since deploy).
- Suggests `/atlassian:start-sprint` if `activeSprintId` is null.

## Guard Rails

- [ ] Comms check ran first
- [ ] CC head exists; bootstrap-cc was already run
- [ ] Cowork credentials present
- [ ] User explicitly provided project values (defaults shown but confirmed)
- [ ] Read-only Jira token gathered separately for CC
- [ ] Snapshot before any modify
- [ ] Consent received before any write
- [ ] Application uses marker tags; idempotent
- [ ] Marker file + JSON updated atomically
- [ ] CC `.credentials` mode 0600
- [ ] CC `.gitignore` includes `.credentials`
- [ ] No company-specific defaults - every value comes from user input or `.credentials`
- [ ] No Atlassian writes attempted in this skill (only reads for project/board/space discovery)

## Error Cases

**No CC head:** "Run `/devtools:bootstrap-cc` first to create `{PROJECT}.cc/`."
**Project key not found:** Re-prompt user; verify they have permission on the Jira project.
**Board lookup empty:** Project has no board. Ask user to create one in Jira UI; provide direct URL.
**Read-only token also lacks read scope:** "Token must have at least Jira read access. Re-mint at <id-url>."
**Workspace `CLAUDE.md` missing:** Create it from a minimal template (just the project header) before applying.
**Existing section markers but file content was hand-edited inside markers:** Snapshot, replace anyway, surface the diff so user can re-apply intentional edits.
