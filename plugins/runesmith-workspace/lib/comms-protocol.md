# Comms Protocol

How the planner (the chat session, `cowork` in front matter) and the builder (Claude Code, `cc`) talk. The owner is reached only through the planner, and through the builder's one banner at the end of a goal.

Comms is the working channel, not the record. Plans and decisions live in `plans/active/{slug}/plan.md` and `decisions.md`; in Atlassian-enabled projects, Jira holds work state. The audit trail of what was asked and done is `comms/archive/`.

## Roles

- **Owner:** decides. Every product decision, promotion, hold and override is the owner's word.
- **Planner:** turns the owner's intent into task comms and `/goal` lines, answers the builder's questions, verifies replies against the repository and archives finished work. Writes no application code. Never runs git write commands, including fetch, in the builder's repositories.
- **Builder:** works goals: builds, tests, opens and merges pull requests, numbers the build, writes reply and status comms, prints one banner per goal. Never talks to the owner directly.

## Folder layout

```
{PROJECT}.cc/comms/
├── open/                                    active work (git-ignored)
│   ├── {UTC}-{slug}/                        one folder per task
│   │   ├── {UTC}-{slug}.md                  the task (planner)
│   │   ├── {UTC}-{slug}-reply.md            the reply (builder)
│   │   ├── references/                      planner: screenshots, source files, the owner's evidence
│   │   ├── assets/                          planner: designs and files to use
│   │   └── evidence/                        builder: screenshots, logs, read-backs
│   └── {UTC}-goal-status/
│       └── {UTC}-goal-status.md             the goal status comm (builder)
├── archive/{YYYY-MM}/                       finished work (committed; the audit trail)
│   ├── {UTC}-{slug}/                        the whole task folder moves here
│   └── goal-status/{UTC}-goal-status/
└── README.md                                short summary of this protocol for the builder
```

- `{UTC}` is the task's creation time in compact form: `20261121T173516Z`. It orders comms without a counter and can't collide between writers.
- `{slug}` is short kebab-case, grep-friendly: `checkout-cancel-later`.
- The reply lives in the task's folder and carries the task's `{UTC}`, so the folder always moves as one unit.
- The comm `id` is the file stem: `20261121T173516Z-checkout-cancel-later`, and `...-reply` for the reply.
- Comms that aren't tasks (an `ambiguity`, `blocker`, `answer` or `user-action` about a task) are files in that task's folder: `{UTC}-{slug}-{type}-{n}.md` with `n` counting from 1.

## Front matter

```yaml
---
id: {UTC}-{slug}                 # the file stem
from: cowork | cc
to: cc | cowork | user
type: task | reply | status | ambiguity | blocker | user-action | answer
parent: {id this answers, or empty}
plan: {plan slug}
ticket: {KEY}                    # Atlassian-enabled projects only; omit otherwise
status: open | in-progress | done | resolved
created: {ISO time, UTC}
---
```

## Types

| Type | From | Use |
|---|---|---|
| `task` | planner | One piece of work with Acceptance |
| `reply` | builder | The result of a task: what merged, proof, owner actions |
| `status` | builder | The goal status comm: written first in every goal, kept current |
| `ambiguity` | builder | Needs a decision before that task can go on |
| `blocker` | builder | Can't go on without something only the owner or planner can provide |
| `user-action` | either | Something only the owner can do: a setting, a secret, a click, a promotion word |
| `answer` | planner | Answers an `ambiguity` or `blocker` (`parent:` set) |
| `ticket-transition` | builder | Atlassian-enabled projects only: asks the planner to move a Jira ticket |

`answer` means the planner answering the builder. The builder's report on a finished task is always a `reply`.

## Every reply starts with a STATUS line

Right after the title, before anything else:

- `STATUS: complete`: every Acceptance item is met, or each item that needs the owner is named as an owner action.
- `STATUS: partial`: some items met. A `Why partial:` line follows.
- `STATUS: blocked`: nothing landed. A `Blocker:` line follows, and an `ambiguity` or `blocker` comm sits in the folder.
- `STATUS: failed`: tried and errored. An `Error:` line follows, with the message exactly as printed.

## Lifecycle

1. **The planner writes the task** in `open/{UTC}-{slug}/`, with anything the builder needs from outside the repository copied into `references/` or `assets/`.
2. **The owner pastes the `/goal` line** the planner gives him into the builder.
3. **The builder writes the goal status comm first,** then works the goal's tasks in order.
4. **Per task, the builder writes its reply** in the task's folder and sets the task and reply to `status: done`. It leaves everything in `open/`.
5. **The builder prints one banner** at the end of the goal.
6. **The planner checks comms:** it reads the goal status comm first, verifies each reply against the repository, archives each finished task folder to `archive/{YYYY-MM}/` and the status comm to `archive/{YYYY-MM}/goal-status/`, and logs the outcome in the plan's `decisions.md`.
7. **Owner-only items** (a token, a click, a promotion word) stay in `open/` as `user-action` comms until the owner has done them.

The builder never archives. The planner never edits a reply.

## The goal status comm

Before any other work in a goal, the builder writes `open/{UTC}-goal-status/{UTC}-goal-status.md` (`from: cc`, `to: cowork`, `type: status`, `status: in-progress`). It holds:

- the goal text exactly as given;
- the task comms it covers, in order;
- each task's state: not started, working, blocked, or merged as pull request #{n};
- anything the owner added or changed mid-goal, in his words, with what changed.

The builder updates it whenever a task changes state or a new `/goal` arrives. At the banner it sets `status: done` and adds the build number. The planner reads this instead of asking the owner what's running.

## A stop in the middle of a goal

When one task hits an ambiguity or blocker:

1. The builder writes the `ambiguity` or `blocker` comm in that task's folder, and the task's reply with `STATUS: blocked`.
2. It marks the task blocked in the goal status comm and moves on to the goal's other tasks.
3. The banner names the blocked task under "Needs you" and points at its reply.
4. The planner writes the `answer` comm in the same folder. The work resumes with a new `/goal` line.

## Rules

- **Side answers go into the task comm they affect,** before its goal starts. Never as a separate step in a goal line.
- **A change to a task whose goal has started** goes in a new task comm with a new goal line. The builder reads a task when it starts it and may not see a later edit.
- **The builder reads only inside its head.** A task that refers to files outside it must carry them in `references/` or `assets/`. If one is missing, the builder uses a reasonable default and names the gap in its reply. It never reaches across the workspace.
- **The builder never asks the owner directly.** Everything goes through comms. The banner's "Needs you" lists owner actions and names the reply with the details.
- **`open/` is not committed.** `archive/` is.

## Atlassian-enabled additions

- `ticket: {KEY}` in front matter names the Jira ticket a comm is about.
- `ticket-transition` lets the builder, which has read-only Jira access, ask the planner to move a ticket. The planner does it through the Jira REST API on check comms and writes an `answer`.

## What comms is not

- **Not the plan.** Plans live in `plans/active/{slug}/`.
- **Not the record of decisions.** That's `decisions.md`.
- **Not a message to the owner.** Owner-facing text goes through the planner's chat, or the builder's banner.

## Skills that read or write comms

- `runesmith-sprint:task`: writes task comms and the `/goal` line.
- `runesmith-sprint:check-comms`: reads replies, verifies, archives, logs, gives the next goal line.
- `runesmith-sprint:start-sprint`: writes a sprint's task comms through `task`.
- Every planning skill runs the on-entry check in `lib/comms-check.md`.
- Builder-side skill templates (`blocker-write`, `ticket-done` and others) write `from: cc` comms in the task's folder.
