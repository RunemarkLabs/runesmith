# Agent Primer

How RuneSmith works, end to end. Read this once. The guides under `docs/howto/` are recipes; this is the model behind them.

## Roles

Three parties work on a RuneSmith project:

- **Owner:** the person. Decides every product question, approves every promotion, marks the QA checklist.
- **Planner:** Claude in chat (a Claude Project), working on the workspace folder. Plans, writes task comms and `/goal` lines, answers the builder, verifies its replies against the repository, archives finished work, and talks to Jira, Confluence and GitHub. In a code project it writes no application code. In front matter it is `cowork`.
- **Builder:** Claude Code, running in `{PROJECT}.cc/`. Works one goal at a time: builds, tests, opens and merges pull requests, numbers the build, writes replies, prints one banner. It never talks to the owner directly. In front matter it is `cc`.

They talk through files in `{PROJECT}.cc/comms/`, never directly.

The marketplace is generic. No company names, project keys or site addresses are baked in; every tenant detail comes from the owner's answers or `.credentials` at runtime.

## Two kinds of project context

| Surface | Holds | Why |
|---|---|---|
| **Project Instructions** (the Claude Project's instructions field) | Behavior: what the project is, the planner's role, rules for every conversation. No file paths. | Doesn't change when files move. |
| **`CLAUDE.md`** (workspace root) | Structure: folder layout, where things live, current work, operating rules tied to paths. | Changes as the workspace grows. |

"Every decision is a structured prompt" is behavior, so it goes in Project Instructions. "Plans live at `plans/active/{slug}/`" is structure, so it goes in `CLAUDE.md`. `/runesmith-workspace:init` writes both: the file directly, the instructions as a block for the owner to paste.

Claude Code has no instructions field. Its context is `{PROJECT}.cc/CLAUDE.md`, which carries the builder's standing rules.

## Workspace layout

`/runesmith-workspace:init` lays this down and `STRUCTURE.md` documents it.

```
{PROJECT}/                          workspace root
├── _INBOX/                         drop zone; /inbox routes it
├── plans/
│   ├── active/{slug}/
│   │   ├── plan.md
│   │   ├── decisions.md            required, append-only
│   │   ├── refs/
│   │   └── tickets/                Jira ticket drafts before push
│   └── archive/{YYYY-MM}/{slug}/
├── notes/
├── drafts/{features,project-docs,bugs,handoffs}/{slug}/
├── research/{topic}/
├── source-docs/{topic}/
├── archive/
│   ├── _pre-{operation}-{UTC}/     snapshots before any move, delete or large edit
│   ├── superseded/{YYYY-MM}/
│   └── tickets-pushed/{YYYY-MM}/
├── {PROJECT}.cc/                   Claude Code head (code projects only)
│   ├── CLAUDE.md                   builder standing rules
│   ├── .claude/                    settings, hooks, runesmith-* skills
│   ├── .credentials                Claude Code's keys
│   ├── comms/                      planner and builder channel
│   └── {repo}/                     the code repo, one or more
├── CLAUDE.md
├── STRUCTURE.md
└── .credentials                    the planner's keys
```

- The root stays clean. New files go to `_INBOX/`.
- Tickets live with their plan; pushed tickets move to `archive/tickets-pushed/`.
- Consumed content goes to `archive/superseded/{YYYY-MM}/`.
- Init is safe to re-run. It snapshots before it moves anything.

## Marker sections

Skills own sections of `CLAUDE.md` between marker lines; everything outside them belongs to the project.

```
<!-- folder-conventions:start -->    init (workspace)
<!-- agent-ops:start -->             init (workspace)
<!-- atlassian-section:start -->     sprint:enable and sprint:disable (workspace and head)
```

Each has a matching `:end` line. Re-running the owning skill refreshes only its section. A start marker with no end marker stops the skill: the file is damaged, and it reports rather than appending a second copy. Sections owned by other tools (for example `runestack-credentials` or `runestack-stack`) are preserved byte for byte.

In Project Instructions, the Jira supplement sits between `<!-- runesmith:atlassian-start -->` and `<!-- runesmith:atlassian-end -->`.

## Plans

Every substantive change opens a plan first.

1. **Create:** `/runesmith-core:plan` writes `plans/active/{slug}/plan.md` and `decisions.md`, after checking open issues. Status `open`.
2. **Build:** status `building`. With Jira, `/runesmith-sprint:plan-to-tickets` drafts tickets under the plan.
3. **Execute:** `/runesmith-sprint:task` turns the plan's work into task comms for the builder.
4. **Record:** every decision and test finding goes into `decisions.md`, with who set it and when.
5. **Done:** status `done`; init archives the plan to `plans/archive/{YYYY-MM}/{slug}/`.
6. **Supersede:** a new plan lists the old slug in `supersedes:`; both archive.

## The comms loop

```
{PROJECT}.cc/comms/
├── open/                                active work (not committed)
│   ├── {UTC}-{slug}/
│   │   ├── {UTC}-{slug}.md              the task (planner)
│   │   ├── {UTC}-{slug}-reply.md        the reply (builder)
│   │   ├── references/  assets/         from the planner
│   │   └── evidence/                    from the builder
│   └── {UTC}-goal-status/               the goal status comm (builder)
├── archive/{YYYY-MM}/                   finished work (committed; the audit trail)
└── README.md
```

1. The planner writes a task with Acceptance, and anything from outside the repo copied into `references/` or `assets/`.
2. The planner gives the owner a `/goal` line. Its fixed ending: "Done when each task's Acceptance is met, or each item that needs the owner is named in the reply as an owner action."
3. The builder writes the goal status comm first, then works each task on a goal branch and merges into `dev` when tests pass.
4. Each reply starts with a STATUS line: `complete`, `partial`, `blocked` or `failed`.
5. The builder prints one banner at the end of the goal and stops. The head's settings cap the stop hook at three blocks (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=3`), so it can't loop.
6. `/runesmith-sprint:check-comms` reads the goal status comm, verifies each reply against the repository (read only), archives finished folders, and logs the outcome in `decisions.md`.

When a task hits a question, the builder writes an `ambiguity` or `blocker` comm in its folder, marks it blocked, finishes the goal's other tasks, and names it under "Needs you" in the banner. The planner answers with an `answer` comm and a new `/goal` line.

The builder never archives. The planner never edits a reply. Full rules: `lib/comms-protocol.md`.

## Branches, builds and promotions

- Branches: `dev`, `qa`, `beta`, `main`. The whole flow is in `lib/release-flow.md` (runesmith-cc, runesmith-sprint, runesmith-workspace). The head creates `dev` and `qa` from `main` on a new repo; Claude Code creates `beta` on the first promotion to beta. One repository ruleset protects all four by name, beta included before it exists: pull request required, no force-push, no deletion, plus the build check once the project's CI reports one. Protection is a guardrail on Claude Code, so RuneSmith sets it; the CI that produces the check belongs to the stack tooling.
- Every project names one GitHub account. Each repo's address is `https://{account}@github.com/{owner}/{repo}.git`, so a machine with several accounts always pushes as the right one.
- Every goal gets its own branch and a pull request into `dev`.
- Build numbers: `MAJOR.MINOR.BUILD` with a four-digit build, one per finished goal, tagged `v{number}`. A new project starts at `0.1.0001`.
- `/runesmith-sprint:promote` moves `dev` to `qa` to `beta` to `main`, only on the owner's word. Before `qa`, the builder runs the full test suite against `dev`.
- The builder keeps the repo's `CHANGELOG.md` for the readers init recorded (default: users and admins).

## The QA checklist

- The source is `qa/checklist.md` in the repo: one `### Title` per item, a `Build:` line, Steps, Expect, and the checker line. The builder adds items as it builds.
- `/runesmith-sprint:qa-checklist` publishes one Claude artifact page per project (never a new one each time) and stores the checklist and results in the page's database.
- The owner marks each item pass or fail on the page. An item's key is the first 16 hex characters of the sha256 of its title, steps and expect lines, so a changed item needs checking again.
- A failure becomes a fix task. The builder opens the GitHub issue with the `bug-report` and `env:{dev|qa|beta|prod}` labels, plus `component:{name}` when it applies.

## Jira is optional

- **Without Jira:** plans and comms drive the work.
- **With Jira:** `/runesmith-sprint:enable` writes the `atlassian-section` into both `CLAUDE.md` files, drops `.atlassian-enabled` at the root, deploys the builder's ticket skills, and asks the owner to paste Claude Code's read-only token. The builder reads sprints; when a ticket must move, it writes a `ticket-transition` comm and the planner moves it. `/runesmith-sprint:disable` reverses it.

## Credentials

Keys live where the thing that uses them runs:

- Planner keys: `{WORKSPACE_ROOT}/.credentials`. Claude Code never reads this file.
- Claude Code keys: `{PROJECT}.cc/.credentials`, beside the repos and never inside one.

Values are single-quoted. Skills report each key as set or missing, never print a value, and never ask for a secret in chat. Full rules: `lib/credentials.md`.

## The project-boundary guardrail

Two layers keep each Claude Code session inside its project:

- **Rules:** the builder's `CLAUDE.md` forbids cross-project paths and reading credential-class files.
- **Enforcement:** a user-level block in `~/.claude/settings.json` (`defaultMode: "dontAsk"` with allow and deny lists) and a `PreToolUse` hook that checks shell commands.

`/runesmith-cc:guardrail` copies a one-shot installer into the workspace and gives the one command to run; it takes `verify` and `uninstall` too. The head's `.claude/settings.json` has an empty `permissions.additionalDirectories` list for legitimate cross-project access; `.claude/README.md` explains it and records each approved path.

Known gaps, documented and not solved:

- Subagents launched through the Task tool don't inherit hooks or permission rules. Only the written rules apply there.
- Shell commands on Windows aren't sandboxed; indirect invocation can slip past the hook. It catches accidents, not attacks.
- MCP tool calls aren't boundary-aware.

## Operating principles

Source: `lib/agent-operating-principles.md`; the summary lives in the `agent-ops` section of every workspace `CLAUDE.md`.

- **Files:** direct file tools first. File chores are the agent's, never the owner's.
- **Destructive work:** snapshot first to `archive/_pre-{operation}-{UTC}/`. Confirm scope before changing anything outside the workspace. Commit and push only on the owner's word.
- **Questions:** every decision is a structured prompt with the recommended option first. Never a freeform yes or no. Ask only when the answer changes what gets built.
- **Placeholders:** curly braces only.
- **Boundaries:** stay in the launch project. Never read another project; write a handoff the owner carries.
- **Credential-class files:** never read or echo them.
- **No AI attribution** in commits, pull requests or files.

## Boundaries with other tools

RuneSmith decides how work is run: workspace, planning, comms, gates, documentation. It never decides tech stack, environments, hosting or continuous integration, and never requires another marketplace. When a stack tool such as runestack is installed, init calls its init and leaves its skills (`runestack-*`) and marker sections alone.

## How a request flows

1. The owner asks the planner for a feature.
2. `/runesmith-core:plan` writes `plans/active/feature-x/`.
3. With Jira, `/runesmith-sprint:plan-to-tickets` drafts tickets and pushes them on the owner's word.
4. `/runesmith-sprint:task` writes the task comm and the `/goal` line.
5. The owner pastes the line into Claude Code. The builder works the goal and prints one banner.
6. `/runesmith-sprint:check-comms` verifies and archives, and gives the next `/goal` line if there is one.
7. `/runesmith-sprint:promote` moves the build to `qa` on the owner's word; the owner runs the checklist page.
8. Promotions to `beta` and `main` follow the same gate. The plan is marked done.

## What the libraries pin down

Each plugin carries its own `lib/`. A library shared by several plugins is identical in every copy, and the audit checks it.

| Library | Pinned |
|---|---|
| `comms-protocol.md` | Comms layout, types, status values, STATUS line, goal lines, archiving |
| `comms-check.md` | Check on entry for planner skills |
| `planner-task-method.md` | How a task and its Acceptance are written |
| `qa-checklist.md` | Checklist format, item keys, the page and its database |
| `credentials.md` | Where keys live, key names, the zone format |
| `agent-operating-principles.md` | The `agent-ops` section |
| `folder-conventions.md` | The workspace layout |
| `cc-workspace.md` | The Claude Code head layout |
| `consent.md` | Structured prompts that gate writes |
| `install-paths.md` | Where plugins and deployed skills live |
| `plan-format.md` | `plan.md` schema |
| `tokens.md` | Canonical substitution tokens |
| `confluence-format.md`, `atlassian-rest.md` | Storage format and current Cloud endpoints |
| `atlassian-enabled.md`, `jira-apply.md`, `jira-tags.md` | Jira detection, the applied sections, the tag set |

Change a convention in its library, then run `/runesmith-devtools:skill-updater` to carry it everywhere.

## Where to go next

- New project: `docs/howto/new-workspace.md`
- Existing workspace: `docs/howto/migrate-workspace.md`
- Daily work: `docs/howto/daily-workflow.md`
- Add a repo: `docs/howto/add-repo.md`
- Jira: `docs/howto/enable-atlassian.md`
- Guardrail: `docs/howto/install-guardrail.md`
- Confluence: `docs/howto/publish-to-confluence.md`
