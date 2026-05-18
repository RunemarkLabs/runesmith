# Agent Primer

How the RuneSmith marketplace actually works, end to end. Read this once. The how-to guides under `docs/howto/` are recipes; this is the model that makes the recipes make sense.

## The shape of the system

RuneSmith is a plugin marketplace for two Anthropic agent products that coexist on the same project:

- **Cowork** — the desktop app for non-developer / planning work. Reads project context, drives chat-first plans, dispatches mutations to external systems (Jira, Confluence, GitHub).
- **Claude Code (CC)** — the CLI tool for repo-internal coding work. Runs inside a `{PROJECT}.cc/<repo>/` directory. Reads tasks dispatched from Cowork, executes code changes.

Both load `CLAUDE.md` at session start. Both follow the same operating principles. They communicate via files in `{PROJECT}.cc/comms/` (the comms protocol), never directly.

The marketplace is generic and single-tenant configurable. Plugins ship with no company names, project keys, or site URLs baked in. Every tenant detail lands at runtime from user input or `.credentials`.

## Two-tier project context

Every RuneSmith-bootstrapped project carries context across two surfaces. They look similar; they hold different things.

| Surface | Carries | Why it lives there |
|---|---|---|
| **Project Instructions** (Cowork UI field) | **Behavioral** — project mission, Cowork's role, rules that apply to every conversation | Doesn't change with files. Loaded as system prompt for every chat. |
| **`CLAUDE.md`** (file at workspace root) | **Structural** — folder layout, where things live, plugin paths, file conventions | Changes as the workspace grows. Auto-loaded as file context at session start. |

The line is **behavior vs structure**. "Use structured prompts" → behavioral → Project Instructions. "Plans live at `plans/active/<slug>/`" → structural → CLAUDE.md.

Why this matters: if behavior bleeds into CLAUDE.md, the role drifts when the file structure changes. If structure bleeds into Project Instructions, the role goes stale when a folder moves. They have different update cadences.

Project Instructions is a Cowork-only feature. Claude Code has no Project Instructions UI — its project context is the `CLAUDE.md` inside the repo. So Cowork-side skills produce Project Instructions text for the user to paste; CC-side skills don't.

## Workspace structure

Every RuneSmith workspace follows the same canonical layout. The `runesmith-workspace:reallocate` skill enforces it; the `STRUCTURE.md` file at workspace root documents it.

```
{PROJECT}/                          workspace root
├── _INBOX/                         drop zone — run /inbox to classify
├── plans/
│   ├── active/<slug>/
│   │   ├── plan.md                 canonical plan format
│   │   ├── decisions.md            optional append-only log
│   │   ├── refs/                   supporting docs
│   │   └── tickets/                pre-push Jira ticket JSON drafts
│   └── archive/<YYYY-MM>/<slug>/
├── notes/                          working notes across sessions
├── drafts/{features,project-docs,bugs}/<slug>/
├── research/<topic>/               pre-decision analysis
├── source-docs/<topic>/            external uploads being processed
├── archive/
│   ├── _pre-{operation}/<ISO>/     destructive-op snapshots
│   ├── superseded/<YYYY-MM>/       consumed content
│   └── tickets-pushed/<YYYY-MM>/   Jira ticket draft history
├── {PROJECT}.cc/                   CC head (gitignored — its own git repo)
│   ├── CLAUDE.md                   CC-side project context
│   ├── .claude/                    CC scaffolding (skills, commands, agents, hooks)
│   ├── comms/                      Cowork ↔ CC handoff
│   └── <repo-folder>/              actual code repo, one or more
├── CLAUDE.md                       workspace-side project context
├── STRUCTURE.md                    canonical layout reference
└── .credentials                    gitignored secrets
```

**Rules:**
- Root stays clean. Marketplace standard files + canonical dirs only.
- New files go to `_INBOX/`. Run `/runesmith-workspace:inbox` to classify and route.
- Tickets live under their plan: `plans/active/<slug>/tickets/<KEY>.json`. Pushed tickets archive to `archive/tickets-pushed/<YYYY-MM>/`.
- Consumed or superseded content goes to `archive/superseded/<YYYY-MM>/`. Never park transients at root.

To migrate a non-conforming workspace, run `/runesmith-workspace:reallocate`. Idempotent. Snapshots first.

## Marker-bounded skill-managed sections

`CLAUDE.md` is part skill-managed, part user-managed. Skills own marker-bounded sections; everything outside the markers is yours.

Three marker blocks ship today:

```
<!-- folder-conventions:start -->  managed by reallocate
...
<!-- folder-conventions:end -->

<!-- agent-ops:start -->            managed by reallocate (workspace) and bootstrap-cc (CC head)
...
<!-- agent-ops:end -->

<!-- runesmith:atlassian-start -->  managed by sprint:enable / sprint:disable (workspace only)
...
<!-- runesmith:atlassian-end -->
```

Re-running the owning skill refreshes the content between its markers. User additions outside the markers are preserved.

Same pattern in Cowork Project Instructions: `runesmith-sprint:enable` emits a `<!-- runesmith:atlassian-start/end -->` block for the user to append; `runesmith-sprint:disable` emits removal instructions for the same range. Reallocate's base emission carries no atlassian markers.

## The plan-driven workflow

RuneSmith is plan-driven. Every substantive change opens a plan first.

**Plan lifecycle:**

1. **Create** — `/runesmith-core:plan` writes `plans/active/<slug>/plan.md`. Status: `open`. User iterates on Problem / Decision / Why now / Scope / Trade-offs.
2. **Build** — set `status: building` when work starts. If atlassian-enabled, `/runesmith-sprint:plan-to-tickets` converts the plan into Jira ticket JSON drafts under `plans/active/<slug>/tickets/`.
3. **Push tickets** — on consent ("push the tickets"), drafts POST to Jira, pushed JSONs archive to `archive/tickets-pushed/<YYYY-MM>/`, plan frontmatter `tickets:` array populates.
4. **Execute** — Cowork hands off to CC via `comms/open/<id>-task.md` for repo-internal work. CC reports back via `comms/open/<id>-result.md`. User triages on `/runesmith-sprint:check-comms`.
5. **Done** — set `status: done`. `/runesmith-workspace:reallocate` moves to `plans/archive/<YYYY-MM>/<slug>/`. Refs + unpushed tickets travel with it.
6. **Supersede** — when a new plan replaces this one, the new plan lists this slug in `supersedes:`. Old plan's status flips to `superseded`. Both archive.

Plans are the source of truth for project intent. Confluence pages, when generated, pull from plans. One plan can feed multiple Confluence pages; one Confluence page may pull from multiple plans.

## The comms protocol

Cowork ↔ CC handoff happens via files in `{PROJECT}.cc/comms/`.

```
{PROJECT}.cc/comms/
├── open/                           active comms
│   ├── <iso>-<id>-task.md          Cowork → CC: do this
│   ├── <iso>-<id>-result.md        CC → Cowork: done, here's what happened
│   ├── <iso>-<id>-blocker.md       CC → Cowork: blocked, here's why
│   └── <iso>-<id>-ambiguity.md     CC → Cowork: need user input
└── archive/
    └── <YYYY-MM>/                  resolved pairs
```

**Rules:**
- CC never contacts the user directly. User reaches CC only through Cowork.
- Cowork checks `comms/open/` on entry to every planning skill (the check-on-entry pattern). Open `to: user` items surface first.
- `/runesmith-sprint:check-comms` triages: draft replies for Cowork's response, archive resolved pairs.
- Comms are a local accelerator. Persistent records live in plans (`plans/active/<slug>/`) and on Jira tickets (with canonical tags — see `plugins/runesmith-sprint/lib/jira-tags.md`).

## The Atlassian config split

The marketplace ships in one of two configurations on a per-project basis:

- **Base config** — plans drive work end to end. Cowork writes tasks to `comms/`, CC executes. No Atlassian dependency. Most personal projects sit here.
- **Atlassian-enabled** — plans become Jira tickets in sprints. Decisions and design docs flow into Confluence pages. CC reads sprints (via read-only token); mutations route through Cowork via MCP.

Toggle with `/runesmith-sprint:enable` (wire it in) and `/runesmith-sprint:disable` (unwire). Each adds or removes the `<!-- runesmith:atlassian-start/end -->` markers in both CLAUDE.md files plus the Cowork Project Instructions supplement.

The `.atlassian-enabled` marker file at workspace root is the canonical signal. Skills check for it to decide whether atlassian rules apply.

## The CC project-boundary guardrail

Every CC session is constrained to its launch project's root via two layers:

**Layer 1 — behavioral.** Two refusal rules in `CLAUDE.md` (cross-project paths, credentials-class files) inside the `agent-ops` marker block. Advisory; the agent is supposed to honor them.

**Layer 2 — harness enforcement.** User-level `~/.claude/settings.json` block (`defaultMode: "dontAsk"` + curated allow/deny rules) plus a `PreToolUse` hook for Bash subprocess containment. Permission system enforces; the agent cannot bypass.

Install once per machine via `/runesmith-cc:guardrail install`. `/runesmith-cc:bootstrap-cc` writes the project-level `<project>/.claude/settings.json` with an empty `additionalDirectories: []` escape hatch — populate it when you need legitimate cross-project access (monorepo siblings, shared configs).

**Known residual risks (documented, not solved):**

- Subagents launched via Task tool do NOT inherit `PreToolUse` hooks or permission rules (platform bugs #27661, #23983). Layer 1 advisory rules are the only protection inside a subagent.
- Bash on Windows is unsandboxed. PowerShell pipes, indirect invocation, and shell escaping can evade substring matchers. Hook catches accidents, not attacks.
- MCP tool calls are not boundary-aware. A session can call any installed MCP tool regardless of which project enabled the workflow.

## The agent operating principles

A small set of behaviors all RuneSmith-bootstrapped agents follow. Source: `plugins/runesmith-workspace/lib/agent-operating-principles.md`. Summary version lives in the `<!-- agent-ops -->` marker block of every workspace + CC-head CLAUDE.md.

**File operations.** Direct file tools first (Read/Write/Edit/Glob); bash is for scripts and pipelines. When bash fails with "No such file" on an existing path, the sandbox is stale — switch vectors, don't retry. File ops in the workspace are agent territory; don't defer file chores to the user.

**Sandbox vs permissions.** "Permission denied" = request permission. "No such file or directory" on an existing path = sandbox bug; switch vectors. Don't conflate.

**Destructive operations.** Snapshot before any move or delete to `archive/_pre-{operation}/{ISO}/`. Confirm scope before mutating external systems (Jira, Confluence, git push). Wait for explicit trigger phrases. Never commit or push unless told.

**User interaction.** Structured prompts (single-pick / multi-pick / text-input forms) via the host client's structured-input tool. Never freeform yes/no in chat — including for consent before destructive ops. "Should I proceed?" in plain text is a protocol violation.

**Placeholder syntax.** Curly braces `{PLACEHOLDER}` only. Never angle brackets `<placeholder>` in any plugin metadata — Cowork's upload validator rejects them.

**Workspace boundaries.** Root stays clean. Repo internals (`{PROJECT}.cc/<repo>/`) are CC's territory; workspace skills move repos as units, never enter them.

**Cross-project boundary** (post-Mix Tape incident). Stay inside the launch workspace. Refuse cross-project path references. Cross-project reads are how credential leaks happen.

**Credentials-class files.** Never read, output, or echo files matching `*credentials*`, `*.env`, `id_rsa*`, `*.key`, `*.pem` regardless of location. The Layer 2 guardrail enforces; Layer 1 makes the rule explicit.

## How a request flows through the system

Concrete walkthrough — "user asks Cowork to add a new feature":

1. **Cowork loads context** at session start: project root `CLAUDE.md`, Project Instructions UI text, optionally MCP servers (Atlassian, GitHub, Slack).
2. **User asks** — "Let's plan a feature for X."
3. **Cowork invokes `runesmith-core:plan`** — chat-first discussion, eventually writes `plans/active/feature-x/plan.md`.
4. **User confirms** — "Looks good." Plan moves `open → building`.
5. **If atlassian-enabled** — `/runesmith-sprint:plan-to-tickets` walks the plan, writes ticket JSON drafts to `plans/active/feature-x/tickets/`.
6. **User says "push the tickets"** — drafts POST to Jira (via MCP), pushed JSONs archive to `archive/tickets-pushed/<YYYY-MM>/`.
7. **Cowork writes a brief** to `{PROJECT}.cc/comms/open/<iso>-feature-x-task.md` for CC to pick up.
8. **CC session starts** in `{PROJECT}.cc/<repo>/`. Reads its CLAUDE.md (agent-ops + guardrail rules apply). Reads the task comm. Executes code changes. Writes a result comm back.
9. **Cowork's next session** — checks `comms/open/` on entry. Surfaces the result. User reviews.
10. **Plan done** — status flips, reallocate moves it to archive.

At every write step the agent waits for an explicit trigger phrase per `lib/consent.md`. Reads are free; writes need consent.

## What the libs pin down

Each plugin has its own `lib/` folder with reference docs. They are NOT shared across plugins — every plugin is self-contained, copies of shared libs travel with each plugin.

| Lib | Pinned |
|---|---|
| `credentials.md` | `.credentials` location, required keys, Basic auth header |
| `tokens.md` | Canonical substitution tokens (no synonyms; never `<placeholder>` syntax) |
| `confluence-format.md` | Markdown → storage XHTML rules, version-bump on PUT, error table |
| `atlassian-rest.md` | Canonical Jira/Confluence Cloud endpoints (no deprecated paths) |
| `consent.md` | Trigger phrases that gate every write |
| `install-paths.md` | Cowork vs. Claude Code vs. Teams plugin directories |
| `plan-format.md` | `plan.md` schema |
| `cc-workspace.md` | Claude Code monorepo head spec |
| `comms-protocol.md` | Comms file format and lifecycle |
| `comms-check.md` | Check-on-entry pattern for planning skills |
| `atlassian-enabled.md` | Atlassian-config marker detection |
| `jira-apply.md` | Exact CLAUDE.md sections injected by sprint:enable |
| `sprint-handshake.md` | Session-init / handshake comm format |
| `jira-tags.md` | Canonical tag taxonomy |
| `agent-operating-principles.md` | Source of truth for the agent-ops marker section |
| `folder-conventions.md` | Source of truth for the workspace layout |

Change a convention in a lib doc, then run `/runesmith-devtools:skill-updater` to propagate the change across all skills consistently.

## Where to go next

- New workspace? → `docs/howto/new-workspace.md`
- Existing workspace to migrate? → `docs/howto/migrate-workspace.md`
- Wire Atlassian? → `docs/howto/enable-atlassian.md`
- Lock CC boundaries? → `docs/howto/install-guardrail.md`
- Daily work? → `docs/howto/daily-workflow.md`
- Add a repo to CC? → `docs/howto/add-repo.md`
- Publish docs to Confluence? → `docs/howto/publish-to-confluence.md`
