# Comms Protocol

File-based message exchange between Cowork and Claude Code, plus the user as a routed audience.

Comms is a **local accelerator only** - fast, offline, structured. Persistent records of work (plans, decisions, ticket history) live elsewhere: in `plans/active/{slug}/` markdown for plans, in Jira tickets + tags for atlassian-enabled work. Comms is not the durable record.

## Why files

- Both Cowork and CC can read/write disk; no broker required.
- Survives session restarts on either side.
- Greppable, diffable, auditable.
- Same protocol works in base config and atlassian config - the only difference is whether messages reference Jira tickets.

## Folder layout

```
{PROJECT}.cc/comms/
├── open/                                       active or recently-resolved messages
│   └── {PREFIX}-{NNN}-{slug}/                  one folder per work item
│       ├── {PREFIX}-{NNN}-{slug}.md            the task (from Cowork)
│       ├── {PREFIX}-{NNN}-{slug}-reply.md      the answer (from CC)
│       └── attachments/                        files CC needs from outside the repo
├── archive/{YYYY-MM}/                          resolved pairs Cowork has triaged
│   └── {PREFIX}-{NNN}-{slug}/                  the whole folder moves on archive
│       ├── {PREFIX}-{NNN}-{slug}.md
│       └── {PREFIX}-{NNN}-{slug}-reply.md
├── README.md                                   summary of the protocol - readable by CC via @comms/README.md
└── .gitkeep                                    keep dirs in git even when empty
```

`open/` is gitignored (ephemeral, per-session). `archive/` is committed (audit trail).

## Comm ID

`{PREFIX}-{NNN}-{slug}` where:

- `{PREFIX}` is the project short code (e.g. `RU` for RuneSmith, `MT` for Mix Tape, `AC` for Acme). 2-4 letters.
- `{NNN}` is an incrementing zero-padded integer, **never skipped or reused**.
- `{slug}` is short kebab-case for grep-friendliness.
- Sub-tasks of one effort use A/B/C suffixes immediately after the number: `{PREFIX}-{NNN}A-{slug}`, `{PREFIX}-{NNN}B-{slug}`.

No ISO timestamps in IDs. Order is by number, human-scannable, multi-project-safe.

## File format

Every comms file is markdown with YAML frontmatter:

```markdown
---
id: {PREFIX}-{NNN}-{slug}        # unique within this project
from: cowork | cc | user
to:   cowork | cc | user
type: task | answer | blocker | ambiguity
parent: {id}                     # for replies - links to the comm being answered
ticket: {KEY}                    # Jira key (atlassian-enabled only; omit otherwise)
plan: {slug}                     # plan slug (when relevant)
status: open | resolved
created: {ISO timestamp}
resolved: {ISO timestamp}        # populated when status flips to resolved
---

# {human-readable title}

## Body
What needs to be communicated.

## Acceptance
What's needed before the sender can move forward (sender-authored only).
```

## Types

Four core values, two gated extras.

| Type | From → To | Purpose |
|---|---|---|
| `task` | cowork → cc | Cowork hands CC a discrete work item |
| `answer` | cc → cowork | CC's reply - the work is done |
| `blocker` | cc → cowork | CC cannot proceed; describes the blocker |
| `ambiguity` | cc → cowork | CC needs a decision before continuing |

Gated extras:

| Type | From → To | When |
|---|---|---|
| `ticket-transition` | cc → cowork | Atlassian-enabled projects only - CC asks Cowork to transition a Jira ticket via MCP |
| `user-action` | cc → user (via cowork) | Manual user step required (create a repo, click in a UI, paste a value) |

The four core types always apply. The two gated extras only appear in projects that need them. `session-init`, `confirmation`, `handshake` are no longer in the active enum.

## Lifecycle

1. **Cowork writes the task** to `comms/open/{PREFIX}-{NNN}-{slug}/{PREFIX}-{NNN}-{slug}.md` with `from: cowork, to: cc, type: task, status: open`. Files CC needs from outside the repo go under that folder's `attachments/`.
2. **CC executes** on its next session.
3. **CC writes the reply** in the SAME folder as `{PREFIX}-{NNN}-{slug}-reply.md` with `from: cc, to: cowork, type: answer | blocker | ambiguity, parent: {PREFIX}-{NNN}-{slug}, status: resolved`. CC also sets the task file's frontmatter to `status: resolved`.
4. **CC banners** as the last thing in the response.
5. **CC LEAVES both files in `comms/open/`.** Archiving is not CC's job. CC's last filesystem action on a comm is writing the reply.
6. **Cowork triages** via `runesmith-sprint:check-comms`: reads the reply, verifies the behavioral proof, moves the entire folder to `archive/{YYYY-MM}/{PREFIX}-{NNN}-{slug}/`.

This split resolves an earlier three-way contradiction (CC parent said "CC archives", check-comms said "Cowork archives", protocol doc said "whichever notices last"). The canonical rule: CC writes + flips status, Cowork moves.

## Push policy (CC side)

- Clean completion (`status: complete` with verification passing) → push to `origin/dev`, then banner.
- Partial / blocked / failed / ambiguity → commit + stage but do **NOT** push. Banner so the halt is visible.
- **Never push `main` directly.** Promotion (dev → main) is a user/Cowork operation.

This overrides the generic agent-ops "never push, stop at staged" default for CC repos.

## Boundaries

- **CC cannot read outside its repo.** Any path Cowork references that lives outside (the workspace root, sibling repos, etc.) must be attached under the comm's `attachments/` folder OR the task must explicitly tell CC to use defaults. CC flags the gap in its reply rather than guessing silently.
- **CC never