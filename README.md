# RuneSmith

Claude plugin marketplace for how work gets done with Claude: workspace setup, planning, the comms loop between the planner (Claude in chat) and the builder (Claude Code), build numbers, promotion gates and the QA checklist, Jira and Confluence, AI Operations documentation, and plugin-author tooling. Every tenant detail comes from your answers or `.credentials` at runtime.

Built and maintained by [Runemark Labs](https://github.com/runemarklabs). Apache-2.0 licensed.

## What's in the marketplace

Eight plugins. Install only what you need.

| Plugin | Skills | Purpose |
|---|---|---|
| **`runesmith-core`** | plan, setup, install, sync | Foundation. Credentials, plugin management, planning before writes. **Required base.** |
| **`runesmith-workspace`** | init, inbox, reallocate (pointer) | `/init` is the single entry point for a project: interview, folder layout, `CLAUDE.md`, and the hand-off to the Claude Code head when the project holds code. |
| **`runesmith-cc`** | head, guardrail, bootstrap-cc (pointer) | Builds the `{PROJECT}.cc/` Claude Code head: builder rules, comms folder, settings, the runesmith skills Claude Code uses, and the dev, qa and beta branches. The guardrail keeps Claude Code inside its project. |
| **`runesmith-sprint`** | task, check-comms, promote, qa-checklist, enable, disable, start-sprint, sprint-status, plan-to-tickets | The planner and builder loop: task comms and `/goal` lines, reply verification, promotions, and the QA checklist page. Optional Jira wiring. |
| **`runesmith-jira`** | ticket, bug-report, project-status, new-project | Jira tickets and project basics over the Cloud REST API. |
| **`runesmith-confluence`** | feature-doc, architecture-doc, project-overview, decisions-log, known-issues, roadmap, session-log | Confluence pages with storage format conversion. |
| **`runesmith-aiops`** | bootstrap-aiops | Populates an AI Operations Confluence space from template pages. |
| **`runesmith-devtools`** | help, plugin-builder, tech-debt, skill-updater | Tools for plugin authors. |

`reallocate` and `bootstrap-cc` remain for one release as pointers to `init` and `head`.

## Roles

- **Planner:** Claude in chat. Plans, writes task comms and `/goal` lines, verifies replies against the repository, archives finished work. Writes no application code.
- **Builder:** Claude Code, running in `{PROJECT}.cc/`. Works one goal at a time on its own branch, replies through `comms/`, opens pull requests into `dev`.
- **Owner:** you. Approves promotions, marks the QA checklist, makes every decision the planner cannot.

## The loop

1. `/runesmith-sprint:task` writes a task comm in `{PROJECT}.cc/comms/open/{UTC}-{slug}/` and gives you a `/goal` line to paste into Claude Code.
2. Claude Code writes a goal status comm, works the task on a goal branch, merges into `dev` when tests pass, sets the build number, and writes a reply that starts with a STATUS line. It prints one banner, last, and stops.
3. `/runesmith-sprint:check-comms` verifies the reply against the repository and archives what is done.
4. `/runesmith-sprint:promote` moves a build `dev` to `qa` to `beta` to `main`, only on your word. Before `qa`, Claude Code runs the full test suite against `dev`.
5. `/runesmith-sprint:qa-checklist` publishes the project's checklist page. You mark each item pass or fail; a failure becomes a fix task, and Claude Code opens the GitHub issue.

Build numbers are `MAJOR.MINOR.BUILD` with a four-digit build, one per finished goal, tagged `v{number}`. A new project starts at `0.1.0001`. The full protocol is in `plugins/runesmith-cc/lib/comms-protocol.md`.

## Jira is optional

- **Without Jira:** plans drive the work. Everything above works with no Atlassian account.
- **With Jira:** `/runesmith-sprint:enable` adds the Jira rules to both `CLAUDE.md` files and deploys the Claude Code ticket skills. Planner and Claude Code each use their own token. `/runesmith-sprint:disable` removes it all.

## Install

### Marketplace (recommended)

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-core@runesmith
/plugin install runesmith-workspace@runesmith
/plugin install runesmith-cc@runesmith
/plugin install runesmith-sprint@runesmith
/plugin install runesmith-jira@runesmith
/plugin install runesmith-confluence@runesmith
/plugin install runesmith-aiops@runesmith
/plugin install runesmith-devtools@runesmith
```

Then run `/runesmith-workspace:init` in the project. It runs credential setup when keys are missing. See [INSTALL.md](INSTALL.md) for every option.

### Manual `.plugin` files

`.plugin` zips are not committed; build them:

```
python scripts/build.py        # cross-platform; recommended on Windows
bash scripts/build.sh          # Unix and Mac
```

The zips land in `./dist/` (gitignored). Drag them into the Claude desktop plugin sidebar. `python scripts/build.py path/to/output/` writes elsewhere.

## Documentation

- [Agent Primer](docs/AGENT_PRIMER.md): how the system works end to end. Read this first.
- How-to guides:
  - [Set up a new project](docs/howto/new-workspace.md)
  - [Bring an existing workspace up to date](docs/howto/migrate-workspace.md)
  - [Add a repo to a Claude Code head](docs/howto/add-repo.md)
  - [Install the project-boundary guardrail](docs/howto/install-guardrail.md)
  - [Enable Jira on a project](docs/howto/enable-atlassian.md)
  - [Daily workflow](docs/howto/daily-workflow.md)
  - [Publish docs to Confluence](docs/howto/publish-to-confluence.md)

## Credentials

Keys live where the thing that uses them runs, never inside a repo.

- Planner keys: `{WORKSPACE_ROOT}/.credentials` (Atlassian, `RUNESMITH_GITHUB_PAT`, plugin sources).
- Claude Code keys: `{PROJECT}.cc/.credentials` (`CC_ATLASSIAN_API_EMAIL`, `CC_ATLASSIAN_API_TOKEN`, `ATLASSIAN_BOARD_ID`). The repo sits in a subfolder, so Claude Code can read them and they never enter git.

When another tool already manages the file with zone markers, RuneSmith writes only its own block (`# Owner: runesmith`). Details: `lib/credentials.md`.

## Write contract

Every skill that writes outside the workspace follows the same gate:

1. Check comms on entry and surface anything addressed to you.
2. Resolve `.credentials` and project values.
3. Draft locally (`drafts/`, `plans/active/`, or chat).
4. Ask with a structured prompt, recommended option first, and wait for your answer.
5. Convert markdown to Confluence storage format or Jira document format.
6. Call the current Cloud endpoints (version bump on every page update).
7. Report the links.

## Boundaries

RuneSmith decides how work is run. It never decides tech stack, environments, hosting or continuous integration, and never requires another marketplace to work. When a companion tool is installed (for example a stack index), `/init` hands off to it and preserves its marked sections byte for byte.

## Repo layout

```
.claude-plugin/marketplace.json    marketplace manifest
plugins/
  runesmith-core/
    .claude-plugin/plugin.json
    skills/                        plan, setup, install, sync
    commands/                      slash command wrappers
    lib/                           shared reference docs
    LICENSE, README.md
  runesmith-workspace/             init, inbox
  runesmith-cc/
    skills/                        head, guardrail
    cc-skill-templates/            deployed into {PROJECT}.cc/.claude/skills/runesmith-{name}/
  runesmith-sprint/
    skills/                        task, check-comms, promote, qa-checklist, Jira skills
    cc-skill-templates/            Jira skills deployed by /enable
  runesmith-jira/
  runesmith-confluence/
  runesmith-aiops/
    templates/                     storage format page templates
  runesmith-devtools/
scripts/
  audit.py                         release validation (front matter, references, forbidden patterns, complete files, identical shared libraries)
  build.py, build.sh               build .plugin zips
  bump-version.py                  version bumps
  md-to-storage.py                 markdown to Confluence storage format
INSTALL.md, RELEASE.md, CHANGELOG.md, CONTRIBUTING.md, LICENSE, NOTICE
.credentials.example
```

Each plugin is self-contained. Library references in skills are plugin-relative (`lib/{name}.md`). A library shared by several plugins is identical in every copy; the audit fails otherwise.

## What the libraries pin down

| Library | Pinned |
|---|---|
| `credentials.md` | Where keys live, required keys, the zone format, the auth header |
| `tokens.md` | Canonical substitution tokens, curly braces only |
| `comms-protocol.md` | Comms folder layout, types, status values, STATUS line, `/goal` lines, archiving |
| `comms-check.md` | Check on entry for planner skills |
| `planner-task-method.md` | How the planner writes a task and its acceptance |
| `qa-checklist.md` | Checklist source format, item keys, the page and its database |
| `agent-operating-principles.md` | Operating rules for planner and builder |
| `cc-workspace.md` | The Claude Code head layout |
| `consent.md` | Structured prompts that gate every write |
| `install-paths.md` | Where plugins and deployed skills live |
| `plan-format.md` | `plan.md` schema |
| `folder-conventions.md` | Workspace layout |
| `confluence-format.md`, `atlassian-rest.md` | Storage format rules and current Cloud endpoints |
| `atlassian-enabled.md`, `jira-apply.md`, `jira-tags.md` | Jira detection, the injected sections, the tag set |

Change a convention in the library, then run `/runesmith-devtools:skill-updater` to carry it into every skill and copy.

## Building and releasing

Run `python scripts/audit.py` before any release; CI runs it on every push. Release steps are in [RELEASE.md](RELEASE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Three principles:

1. **Generic.** No company-specific values in plugin source.
2. **Consent before any write.** See `lib/consent.md`.
3. **Self-contained plugins** with plugin-relative library references.

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
