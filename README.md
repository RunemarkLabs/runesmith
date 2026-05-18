# RuneSmith

Claude plugin marketplace for planning, Atlassian (Jira + Confluence) integration, Claude Code workspace bootstrap, AI Operations documentation, and development tooling. Generic and single-tenant configurable per project — every tenant detail comes from user input or `.credentials` at runtime.

Built and maintained by [Runemark Labs](https://github.com/runemarklabs). Apache-2.0 licensed.

## What's in the marketplace

Eight plugins, ~30 skills total, ~30 commands. Install only what you need.

| Plugin | Skills | Purpose |
|---|---|---|
| **`runesmith-core`** | plan, install, sync, setup | Foundation. Credentials, plugin management, chat-first planning. **Required base.** |
| **`runesmith-workspace`** | reallocate, inbox | Workspace folder structure: `_INBOX/` drop zone, `plans/active/`, `plans/archive/`, snapshots. |
| **`runesmith-cc`** | bootstrap-cc, guardrail | Build the `{PROJECT}.cc/` Claude Code monorepo head with comms folder; create or clone repos via PAT. Install the user-level project-boundary guardrail that constrains CC sessions to their launch project. |
| **`runesmith-jira`** | ticket, bug-report, project-status, new-project | Jira tickets and project basics with current Cloud REST endpoints. |
| **`runesmith-confluence`** | feature-doc, architecture-doc, project-overview, decisions-log, known-issues, roadmap, session-log | Confluence pages with storage XHTML conversion. |
| **`runesmith-sprint`** | enable, disable, start-sprint, sprint-status, check-comms, plan-to-tickets | Sprint workflow + Cowork↔Claude Code interconnect via comms protocol. |
| **`runesmith-aiops`** | bootstrap-aiops | Populate an AI Operations Confluence space from six template pages. |
| **`runesmith-devtools`** | help, plugin-builder, tech-debt, skill-updater | Developer helpers for the marketplace itself. |

## Two configurations

- **Base config** — plans drive work. Cowork plans, writes tasks to `comms/`, Claude Code executes. No Atlassian dependency.
- **Atlassian-enabled** — plans become Jira tickets in sprints. Claude Code reads sprints (read-only token); mutations route through Cowork via MCP. Toggle with `/runesmith-sprint:enable` and `/runesmith-sprint:disable`.

## Install

### Marketplace (Claude Code / Teams) — recommended

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-core@runesmith
/plugin install runesmith-workspace@runesmith
/plugin install runesmith-cc@runesmith
/plugin install runesmith-jira@runesmith
/plugin install runesmith-confluence@runesmith
/plugin install runesmith-sprint@runesmith
/plugin install runesmith-aiops@runesmith
/plugin install runesmith-devtools@runesmith
```

After install, run `/runesmith-core:setup` to configure credentials. See [INSTALL.md](INSTALL.md) for full options.

## Documentation

- [Agent Primer](docs/AGENT_PRIMER.md) — how the system works end to end. Read this first.
- [How-to guides](docs/howto/) — workflow-keyed recipes:
  - [Set up a new project workspace](docs/howto/new-workspace.md)
  - [Migrate an existing workspace](docs/howto/migrate-workspace.md)
  - [Add a repo to a CC head](docs/howto/add-repo.md)
  - [Install the project-boundary guardrail](docs/howto/install-guardrail.md)
  - [Enable Atlassian on a workspace](docs/howto/enable-atlassian.md)
  - [Daily workflow](docs/howto/daily-workflow.md)
  - [Publish docs to Confluence](docs/howto/publish-to-confluence.md)

### Manual `.plugin` files (Cowork desktop)

`.plugin` zips are not committed to this repo — they're generated on demand. Build them first:

```
python scripts/build.py        # cross-platform; recommended on Windows
# or:
bash scripts/build.sh          # Unix/Mac
```

This produces `runesmith-*.plugin` files in `./dist/` (gitignored). Drag those into the Cowork plugin sidebar to install.

Custom output directory:

```
python scripts/build.py path/to/output/
```

## Workflow contract

Every write skill follows the same gate:

1. **Comms-check on entry** — surface any open `to: user` items first.
2. **Resolve `.credentials`** and project values.
3. **Gather details**, draft locally to `/drafts/`, `/plans/active/`, or chat.
4. **Wait for explicit consent trigger** ("make the ticket", "publish the page", "do it").
5. **Convert markdown → Confluence storage XHTML** or **→ Jira ADF**.
6. **POST/PUT against canonical Cloud endpoints** (no deprecated paths, version bumps on PUT).
7. **Report URLs**.

No write happens without the trigger. No skill talks to deprecated endpoints. No body is markdown.

## Comms protocol

Cowork ↔ Claude Code communicate via files in `{PROJECT}.cc/comms/`. CC writes ambiguity, blockers, or user-action requests to `comms/open/`; Cowork triages on `/runesmith-sprint:check-comms` or any planning interaction (check-on-entry pattern). User is reached only through Cowork — CC never asks the user directly.

Comms is a local accelerator only. Persistent records live in plans (`plans/active/<slug>/`) and on Jira tickets (with canonical tags — see `plugins/runesmith-sprint/lib/jira-tags.md`).

## Repo layout

```
.claude-plugin/marketplace.json    Marketplace manifest for /plugin marketplace add
plugins/
  runesmith-core/
    .claude-plugin/plugin.json
    skills/                        plan, install, sync, setup
    commands/                      slash command wrappers
    lib/                           shared reference docs (credentials, tokens, plan-format, ...)
    LICENSE, README.md
  runesmith-workspace/          ...
  runesmith-cc/                 ...
  runesmith-jira/               ...
  runesmith-confluence/         ...
  runesmith-sprint/
    skills/                        atlassian-side
    cc-skill-templates/            deployed by /enable into <project>.cc/.claude/skills/atlassian/
    lib/
  runesmith-aiops/
    skills/bootstrap-aiops/
    templates/                     six storage-XHTML page templates
  runesmith-devtools/           ...
scripts/
  audit.py                         pre-release validation (frontmatter, refs, forbidden patterns)
  build.py                         cross-platform build (recommended on Windows)
  build.sh                         Unix/Mac build
  md-to-storage.py                 markdown → Confluence storage XHTML
INSTALL.md                         install paths + credentials reference
CHANGELOG.md
CONTRIBUTING.md
LICENSE                            Apache-2.0
NOTICE                             Attribution + trademarks
README.md                          this file
.credentials.example
```

Each plugin is **self-contained**. Lib references in skill files are plugin-relative (`lib/<name>.md`).

## What the libs pin down

Within each plugin's `lib/`:

| Lib | Pinned |
|---|---|
| `credentials.md` | `.credentials` location, required keys, Basic auth header |
| `tokens.md` | Canonical substitution tokens (no synonyms; never `<placeholder>` syntax) |
| `confluence-format.md` | Markdown → storage XHTML rules, version-bump on PUT, error table |
| `atlassian-rest.md` | Canonical Jira/Confluence Cloud endpoints (no deprecated paths) |
| `consent.md` | Trigger phrases that gate every write |
| `install-paths.md` | Cowork vs. Claude Code vs. Teams plugin directories |
| `plan-format.md` | `plan.md` schema |
| `cc-workspace.md` | Claude Code monorepo head spec (in `runesmith-cc` and `runesmith-workspace`) |
| `comms-protocol.md` | Comms file format and lifecycle |
| `comms-check.md` | Check-on-entry pattern for planning skills |
| `atlassian-enabled.md` | Atlassian-config marker detection (in `runesmith-sprint`) |
| `jira-apply.md` | Exact CLAUDE.md sections injected by `/enable` |
| `sprint-handshake.md` | Session-init / handshake comm format |
| `jira-tags.md` | Canonical tag taxonomy |

Change a convention in the lib doc, then run `/runesmith-devtools:skill-updater` to propagate it consistently across all skills.

## Building from source

```bash
# Cross-platform (recommended on Windows)
python scripts/build.py

# Unix/Mac
bash scripts/build.sh
```

Produces `.plugin` zip files in `./dist/` (gitignored). For a custom output location:

```bash
python scripts/build.py path/to/output
```

The build performs three transformations:

1. Strips retired/orphan content from `cc-skill-templates/` and removed skills before zipping.
2. Renames `cc-skill-templ