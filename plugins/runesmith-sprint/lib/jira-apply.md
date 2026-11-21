# Jira Section Apply - CLAUDE.md sections

Exact content `runesmith-sprint:enable` writes into the workspace and CC parent CLAUDE.md files. Idempotent - uses marker tags so re-running replaces in place without duplicating.

## Workspace `CLAUDE.md` application

Inserted between `<!-- atlassian-section:start -->` and `<!-- atlassian-section:end -->`. If markers don't exist, append both with the section between.

```markdown
<!-- atlassian-section:start -->
## Atlassian Interconnect

This project is connected to Jira project **{JIRA_PROJECT_KEY}** and
Confluence space **{CONFLUENCE_SPACE_KEY}** at `{SITE_URL}`.

### Workflow
- Plans live in `plans/active/{slug}/plan.md`.
- Plans become Jira tickets via `/runesmith-sprint:plan-to-tickets`. Tickets
  organize into sprints on board {BOARD_ID}.
- Claude Code works the active sprint from the `{PROJECT}.cc/` workspace.
- CC reads sprint tickets directly via Jira REST (read-only token in
  `{PROJECT}.cc/.credentials`).
- CC mutations to Jira (transitions, status changes) go through comms -
  CC writes a `type: ticket-transition` comm in the task's folder and the
  planner makes the change through the Jira REST API on check comms.

### Comms checking
Every planning skill on this project runs a comms-check on entry. Open
comms in `{PROJECT}.cc/comms/open/` are surfaced before the parent skill
proceeds.

Run `/runesmith-sprint:check-comms` any time to check Claude Code's work.

### Tags on tickets
Both Cowork and CC tag tickets to keep the work record on Jira. See the
canonical taxonomy in `plugins/lib/jira-tags.md` (or the user-
facing summary on board {BOARD_ID}).
<!-- atlassian-section:end -->
```

## CC parent `CLAUDE.md` application

Inserted between `<!-- atlassian-section:start -->` and `<!-- atlassian-section:end -->` (already present in the parent template - see `devtools/skills/bootstrap-cc/templates/CLAUDE.parent.md`).

```markdown
<!-- atlassian-section:start -->
## Atlassian Sprint Workflow

This project is connected to Jira project **{JIRA_PROJECT_KEY}** on
**{SITE_URL}**. Active sprint is tracked in `.claude-code-workspace`
under `atlassian.activeSprintId`.

### How you work
1. At session start, read the active sprint via Jira REST. Use the
   read-only token in `.credentials`.
2. Pick the next ticket from the active sprint. Read its description
   and acceptance criteria.
3. Implement.
4. Document on the ticket itself. Use these tags:
   - `cc-plan` - your implementation plan
   - `cc-action` - actions taken (commit, refactor, push)
   - `cc-decision` - non-obvious decisions worth recording
   - `cc-blocked` - paired with a blocker comm
   - `cc-done` - work complete, ready for transition

5. State changes (transitions, comments to non-CC tags) go through comms.
   Write a `type: ticket-transition` comm requesting the change.
   Cowork executes the Jira mutation. Do not attempt writes to Jira
   yourself - your token is read-only by design.

### Skills available to you
Deployed by `/runesmith-sprint:enable` into `.claude/skills/atlassian/`:
- `sprint-pull` - read active sprint, list ticket details
- `ticket-document` - append plan/action/decision to a ticket as a comment
- `blocker-write` - declare a blocker, write a comm, tag the ticket
- `ticket-done` - write a comm requesting Done transition

### Comms protocol
Same as base config - see `@comms/README.md`. Comms files MAY include
`ticket: {KEY}` in frontmatter to associate with a Jira ticket.

### Tag taxonomy
See `@.claude/skills/atlassian/jira-tags.md` (deployed by `enable`).
<!-- atlassian-section:end -->
```

## Token substitution

Both applications substitute these tokens at apply time:

- `{JIRA_PROJECT_KEY}` → user's Jira project key (e.g. "ACME")
- `{CONFLUENCE_SPACE_KEY}` → user's Confluence space key
- `{SITE_URL}` → user's Atlassian site URL (e.g. "https://acme.atlassian.net")
- `{BOARD_ID}` → user's board id

Values come from the marker file written by `runesmith-sprint:enable`.

## Idempotency

`runesmith-sprint:enable` re-running:
1. Reads current CLAUDE.md files.
2. Locates `<!-- atlassian-section:start -->` and `<!-- atlassian-section:end -->`.
3. Replaces content between markers with freshly-tokenized version.
4. If markers absent, appends a new section.

Result: re-runs always produce the same file content (modulo updated marker values), never duplicate the section, never clobber user content outside the markers.

## Disable

`runesmith-sprint:disable`:
1. Removes content between markers in both CLAUDE.md files (leaves the empty marker pair behind for future re-enable).
2. Removes `{workspace-root}/.atlassian-enabled` file.
3. Sets `atlassianEnabled: false` in CC marker, clears `atlassian` block.
4. Removes deployed skills from `{PROJECT}.cc/.claude/skills/atlassian/`.
5. Leaves `{PROJECT}.cc/.credentials` and existing comms untouched (user can clean up manually).
