# Comms - file-based exchange between Cowork and Claude Code

This folder is the local channel between Cowork (planning) and Claude Code
(execution). Cowork writes here when it needs CC to do something. CC writes
here when it has questions, blockers, or needs the user.

## Folder layout

```
comms/
├── open/                                       active or recently-resolved (gitignored)
│   └── {PREFIX}-{NNN}-{slug}/                  one folder per work item
│       ├── {PREFIX}-{NNN}-{slug}.md            the task (from Cowork)
│       ├── {PREFIX}-{NNN}-{slug}-reply.md      the answer (from CC)
│       └── attachments/                        files CC needs from outside the repo
└── archive/{YYYY-MM}/                          resolved folders (committed audit trail)
    └── {PREFIX}-{NNN}-{slug}/                  the whole folder moves on archive
```

## Comm IDs

`{PREFIX}-{NNN}-{slug}` where:

- `{PREFIX}` is the project's 2-4 letter short code (e.g. `RU`, `MT`, `AC`)
- `{NNN}` is an incrementing zero-padded integer, never skipped or reused
- `{slug}` is short kebab-case
- Sub-tasks of one effort use A/B/C suffixes: `{PREFIX}-{NNN}A-{slug}`, `{PREFIX}-{NNN}B-{slug}`

No ISO timestamps in IDs. Numbering is human-scannable and per-project so multiple projects never collide.

## Message format

Each file is markdown with YAML frontmatter:

```markdown
---
id: {PREFIX}-{NNN}-{slug}
from: cowork | cc | user
to:   cowork | cc | user
type: task | answer | blocker | ambiguity
parent: {id of comm being answered, if any}
ticket: {Jira KEY}     # only when atlassian is enabled
plan: {slug}            # when relevant
status: open | resolved
created: {ISO}
resolved: {ISO}         # when status flips
---

# {human-readable title}

## Body
...

## Acceptance
What's needed before sender can move forward (sender-authored).
```

## Types

Four core values:
- `task` - cowork -> cc, the work item
- `answer` - cc -> cowork, done
- `blocker` - cc -> cowork, cannot proceed
- `ambiguity` - cc -> cowork, need a decision

Two gated extras:
- `ticket-transition` - atlassian-enabled projects only; CC asks Cowork to transition a Jira ticket via MCP
- `user-action` - cc -> user via cowork; manual user step (create a repo, paste a value, click in a UI)

## Lifecycle

1. Cowork writes the task to `open/{PREFIX}-{NNN}-{slug}/{PREFIX}-{NNN}-{slug}.md`. Any files CC needs from outside the repo go under that folder's `attachments/`.
2. CC executes on its next session.
3. CC writes the reply in the SAME folder as `{PREFIX}-{NNN}-{slug}-reply.md`. CC sets BOTH task and reply to `status: resolved` and LEAVES them in `open/`. Archiving is Cowork's job.
4. CC banners at the end of its response (high-visibility markdown block as the last thing in the message). No banner = task not done.
5. Cowork (via `/runesmith-sprint:check-comms`) triages the reply and moves the entire folder to `archive/{YYYY-MM}/{PREFIX}-{NNN}-{slug}/` as a single rename.

## Push policy (CC side)

- Clean completion (verification passing) -> push to `origin/dev`, then banner.
- Partial / blocked / failed / ambiguity -> commit + stage but do NOT push. Banner so the halt is visible.
- Never push `main` directly. Promotion (dev -> main) is a user/Cowork operation.

## Rules

- The user is reached only through Cowork. CC never asks the user directly.
- CC can only read files INSIDE this repo. If a task references paths outside the repo and they aren't attached under `attachments/`, CC uses defaults and FLAGS the gap in the reply.
- Comms is a local accelerator only - durable records of work live in plans (`../plans/active/{slug}/`) or in Jira tickets when atlassian is enabled.
- `open/` is gitignored; `archive/` is committed. Don't `git add open/`.
- All of the above hold on a freshly `/clear`-ed CC session. They live in the CC head `CLAUDE.md` and don't depend on chat history.

## Skills

Cowork side:
- `/runesmith-sprint:check-comms` - manual triage of open comms; owns the archive move
- All planning skills run a check-on-entry of `open/`

CC side (deployed by `/runesmith-sprint:enable`):
- `sprint-pull`, `ticket-document`, `blocker-write`, `ticket-done` -
  read sprint, document on tickets, write blocker comms, request transitions

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
