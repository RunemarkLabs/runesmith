# Claude Code Workspace Spec

Canonical structure for the `{PROJECT}.cc/` monorepo head. Cowork builds it; Claude Code consumes it. CC never bootstraps itself.

## Naming

Folder name is `{PROJECT}.cc/` where `{PROJECT}` matches the workspace root folder name. Example: a Cowork project at `~/Code/acme-portal/` produces `~/Code/acme-portal/acme-portal.cc/`. The `.cc` suffix is short, distinctive, and shows in Claude Code's open-folder picker so the user always knows which project they're in.

## Two configurations

**Base config:** no Atlassian. Plans drive work. CC works from comms tasks Cowork writes.

**Atlassian-enabled:** plans → Jira tickets → sprints. CC reads sprints via REST. Mutations go through comms.

The `.atlassian-enabled` marker file at workspace root + the `atlassianEnabled` flag in `.claude-code-workspace` distinguishes the two. Default is base.

## Directory shape

```
{workspace-root}/
├── .atlassian-enabled                         (only if atlassian-enabled)
└── {PROJECT}.cc/
    ├── CLAUDE.md                              monorepo constitution
    ├── README.md                              human-readable identifier
    ├── .claude-code-workspace                 marker JSON
    ├── .credentials                           CC's read-only Jira PAT (atlassian-enabled only)
    ├── .credentials.example                   template
    ├── .claude/
    │   ├── settings.json                      guardrail scaffolding + AI attribution off
    │   ├── settings.local.json                gitignored
    │   ├── skills/
    │   │   ├── runesmith-clean-code/          deployed by bootstrap-cc - the builder's code standards
    │   │   ├── code-tech-debt/                deployed by bootstrap-cc - repo-level
    │   │   │   ├── SKILL.md                   code dead-code / unused-export scanner
    │   │   │   └── lib/code-analyzers.md      per-language analyzer registry
    │   │   └── atlassian/                     deployed by /runesmith-sprint:enable
    │   │       └── (sprint-pull, ticket-document, blocker-write, ticket-done)
    │   ├── commands/                          empty
    │   ├── agents/                            empty
    │   └── hooks/                             empty
    ├── comms/
    │   ├── open/{UTC}-{slug}/                 gitignored - task, reply, references/, assets/, evidence/
    │   ├── open/{UTC}-goal-status/            gitignored - the goal status comm
    │   └── archive/{YYYY-MM}/                 committed - audit trail
    ├── .gitignore
    ├── .gitattributes
    └── {repo}/                                cloned/created repos
        └── CLAUDE.md                          repo-shared rules
            (.git/hooks/commit-msg)            strips AI attribution (bootstrap-cc)
```

## Marker file: `.claude-code-workspace`

```json
{
  "project": "{workspace-folder-name}",
  "initialized": "{ISO timestamp}",
  "schemaVersion": 1,
  "atlassianEnabled": false,
  "atlassian": {
    "siteUrl": null,
    "jiraProjectKey": null,
    "jiraProjectId": null,
    "boardId": null,
    "activeSprintId": null,
    "confluenceSpaceKey": null,
    "confluenceSpaceId": null
  },
  "repos": []
}
```

When `runesmith-sprint:enable` runs, it sets `atlassianEnabled: true`, fills the `atlassian` block from user input (the **user's** Jira project - not the bootstrap framework's), and updates `activeSprintId` whenever `start-sprint` or `sprint-status` notice a change.

When `bootstrap-cc` clones or creates a repo, it appends to `repos[]`:
```json
{ "name": "...", "url": "...", "createdBy": "bootstrap-cc", "added": "{ISO}" }
```

## CLAUDE.md (parent)

Generated from `runesmith-cc/skills/head/templates/CLAUDE.parent.md`. That template is the single source; this spec doesn't repeat it, so the two can't drift. It carries:

- the workflow: task comms in `comms/open/{UTC}-{slug}/`, one goal status comm per goal, one reply per task, one banner per goal, no direct contact with the owner;
- the `atlassian-section` markers, empty until `runesmith-sprint:enable`;
- the `agent-ops` markers holding the builder standing rules (goals, replies, git authority, attribution, clean code, testing, the qa checklist, build numbers, changelog, test data, security, the banner and ending a goal without looping).

Refreshing the file rewrites only RuneSmith's own marker sections. Any other marker pair (for example `runestack-credentials`) and anything outside markers is kept byte for byte.

When `runesmith-sprint:enable` runs, it applies an Atlassian section between marker tags:

```markdown
<!-- atlassian-section:start -->
## Atlassian Sprint Workflow

This project is connected to Jira project {PROJECT_KEY} on {SITE}.

Read the active sprint via Jira REST using `.credentials` (read-only token).
Pick the next ticket. Implement.

Document on the ticket itself, with tags:
- `cc-plan` - your implementation plan
- `cc-action` - actions taken (commit, refactor, etc.)
- `cc-decision` - non-obvious decisions
- `cc-blocked` - paired with a blocker comm
- `cc-done` - completed, ready for transition

State changes (transitions, comments to non-CC tags) go through comms:
write a `to: cowork, type: ticket-transition` comm in the task's folder and
the planner makes the change through the Jira REST API on check comms.

See @../plugins/lib/jira-tags.md for the canonical tag taxonomy.
<!-- atlassian-section:end -->
```

`runesmith-sprint:disable` removes content between the markers.

## CLAUDE.md (per-repo)

Stub generated when `bootstrap-cc` clones/creates a repo:

```markdown
# {repo-name}

Repo-shared Claude rules for {repo-name}, part of the {PROJECT} Claude Code workspace.

## Stack
{one-line description - fill in}

## Conventions
- Branch naming: ...
- Commit style: ...
- Test expectations: ...

## Gotchas
<things Claude can't infer; fill in>
```

User fills in. Skills do not auto-populate beyond stubs.

## Comms folder

See `lib/comms-protocol.md` for full spec. Built by `bootstrap-cc`. Includes a `comms/README.md` that documents the protocol so CC can `@reference` it.

## Migration from old `claude-code/`

Both `runesmith-workspace:init` and `runesmith-cc:head` detect an existing `claude-code/` folder at the workspace root and offer the same migration:

1. Snapshot contents to `archive/_pre-cc-bootstrap/{ISO}/`.
2. Rename `claude-code/` to `{PROJECT}.cc/`.
3. Generate or normalize the parent `CLAUDE.md`, `README.md`, `.claude-code-workspace`, `.claude/` dirs, `comms/` dirs, `.gitignore`.
4. Preserve all existing repos as subdirectories of `{PROJECT}.cc/`.
5. If atlassian was previously enabled (detected via existence of section markers in old CLAUDE.md), replay `runesmith-sprint:enable` flow to refresh the applied sections.

Idempotent: re-running on an already-correct `{PROJECT}.cc/` is a no-op.

## Skills that interact with this spec

- `runesmith-cc:head` - creates / migrates the head
- `runesmith-workspace:init` - workspace-level migrations, including CC head migration
- `runesmith-sprint:enable` - wires Atlassian into an existing CC head
- `runesmith-sprint:disable` - unwires
- `runesmith-sprint:start-sprint` / `sprint-status` - read/update `activeSprintId` in marker
- All CC-side skills deployed by `runesmith-sprint:enable` - read `.credentials` and `.claude-code-workspace` for context
