# Install

The RuneSmith marketplace ships **eight plugins**:

| Plugin | Required | Purpose |
|---|---|---|
| `runesmith-core` | yes | Credentials, plugin management, planning. Foundation. |
| `runesmith-workspace` | yes | `/init`: the project interview, workspace layout and `CLAUDE.md`. |
| `runesmith-cc` | for code projects | The `{PROJECT}.cc/` Claude Code head and the project-boundary guardrail. |
| `runesmith-sprint` | for code projects | Task comms, reply verification, promotions, QA checklist, optional Jira wiring. |
| `runesmith-jira` | optional | Jira ticket and project workflows. |
| `runesmith-confluence` | optional | Confluence page authoring. |
| `runesmith-aiops` | optional | Populates an AI Operations Confluence space from templates. |
| `runesmith-devtools` | optional | Tools for plugin authors. |

Three install paths. Pick the one that fits your client.

## Path A: marketplace add

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

Restart the client so the plugins register, then run `/runesmith-workspace:init` in your project.

## Path B: add the marketplace in Claude (web and desktop)

Paid plans can add a marketplace from GitHub, and it stays synced:

1. Open **Customize**, then **Plugins**.
2. In **Personal plugins**, click **+**, then **Add marketplace**.
3. Choose **Add from a repository** and enter `RunemarkLabs/runesmith`.
4. Install the plugins you need from the RuneSmith marketplace.

Plugins added this way are saved to your account, so they follow you to chat and Claude Code.

## Path B2: manual .plugin files (offline)

`.plugin` zips aren't committed; build them:

```
python scripts/build.py        # cross-platform; recommended on Windows
bash scripts/build.sh          # macOS and Linux
```

The zips land in `./dist/` (gitignored). `python scripts/build.py /path/to/output` writes elsewhere. Then:

1. Open **Customize** in the left sidebar.
2. Drag the `.plugin` files from `./dist/` into the upload area. Install `runesmith-core` first.
3. Restart the app fully.
4. Run `/runesmith-workspace:init` in your project.

## Path C: organization marketplace (Team and Enterprise)

Organization marketplaces synced from GitHub require a **private or internal** repo. Two options.

### C.1: mirror to a private repo in your organization

```bash
git clone --bare https://github.com/runemarklabs/runesmith.git
cd runesmith.git
git push --mirror https://github.com/{your-org}/{your-private-repo}.git
```

Then in organization settings: **Plugins, Add plugin, GitHub source**, enter `{your-org}/{your-private-repo}`, and click **Update** for the first sync. The Claude GitHub App must be installed on the private repo or the sync returns 404.

### C.2: managed settings (Enterprise)

Enterprise admins can deliver the marketplace as managed settings. See the Claude admin documentation. RuneSmith doesn't produce a managed settings file itself.

## Configure credentials

`/runesmith-workspace:init` runs `/runesmith-core:setup` when keys are missing; you can also run setup on its own. Setup never asks for a secret in chat. It writes empty, labeled lines and tells you which key to paste into which file.

Keys live where the thing that uses them runs, and never inside a repo folder.

**Planner keys** in `{WORKSPACE_ROOT}/.credentials`:

| Key | Needed for | Where to get it |
|---|---|---|
| `RUNESMITH_GITHUB_PAT` | creating repos, branch protection, reading issues | https://github.com/settings/personal-access-tokens (fine-grained, Contents read and write, Issues read, Administration write for repo creation and branch protection) |
| `ATLASSIAN_API_URL` | Jira and Confluence skills | Your site, for example `https://acme.atlassian.net` |
| `ATLASSIAN_API_EMAIL` | Jira and Confluence skills | Email of the account that made the token |
| `ATLASSIAN_API_TOKEN` | Jira and Confluence skills | https://id.atlassian.com/manage-profile/security/api-tokens |
| `ATLASSIAN_CONFLUENCE_SPACE_ID` | optional default space | Space settings, Space details |
| `ATLASSIAN_JIRA_PROJECT_KEY` | optional default project | The short uppercase key, for example `ENG` |
| `ATLASSIAN_DEFAULT_ASSIGNEE_ACCOUNT_ID` | optional | Your Atlassian account id |
| `ATLASSIAN_BUG_SEVERITY_FIELD` | optional, bug reports | Custom field id, for example `customfield_10001` |
| `PLUGIN_SOURCES` | optional | Comma-separated extra marketplace addresses |

**Claude Code keys** in `{PROJECT}.cc/.credentials` (only when Jira is enabled for a code project; `/runesmith-sprint:enable` asks for them):

| Key | Purpose |
|---|---|
| `CC_ATLASSIAN_API_EMAIL` | Email for Claude Code's read-only token |
| `CC_ATLASSIAN_API_TOKEN` | Claude Code's read-only Jira token |
| `ATLASSIAN_BOARD_ID` | Numeric board id from the board address |

**Pushing from your computer:** each project names its GitHub account, and every repo address carries it (`https://{account}@github.com/...`). If you use several GitHub accounts on one machine, route each account to Git Credential Manager once; init and head give you the exact two lines when a push would ask for a password or use the wrong account.

Every value is single-quoted (`KEY='value'`). Both files are gitignored. When another tool manages `{PROJECT}.cc/.credentials` with zone markers, RuneSmith writes only its own block. `.credentials.example` in this repo shows the layout. Full rules: `plugins/runesmith-core/lib/credentials.md`.

## Install the project-boundary guardrail (once per machine)

The guardrail is user-level configuration (`~/.claude/settings.json` plus a `PreToolUse` hook) that keeps every Claude Code session inside the project it was launched from. Neither the chat sandbox nor Claude Code itself can write it, so:

```
/runesmith-cc:guardrail
```

The skill copies a self-contained installer (`install-guardrail.ps1` on Windows, `install-guardrail.sh` on macOS and Linux) into the workspace and gives you the one command to run. The same script takes `verify` and `uninstall`. See `docs/howto/install-guardrail.md`.

## Set up a project

In the project's folder:

```
/runesmith-workspace:init
```

Init interviews you (what the project is, whether it holds code, whether it uses Jira), lays out the workspace, writes `CLAUDE.md` and `STRUCTURE.md`, and gives you the Project Instructions to paste. When the project holds code, it runs `/runesmith-cc:head`, which builds `{PROJECT}.cc/` with the builder's rules, the comms folder, settings, the runesmith skills Claude Code uses, and the repo with `dev`, `qa` and `beta` branches. When a stack index tool is installed, the head hands off to it.

See `docs/howto/new-workspace.md`.

## Optional: enable Jira for the project

```
/runesmith-sprint:enable
```

Captures the Jira project key, board id and Confluence space, adds the Jira section to both `CLAUDE.md` files, deploys the Claude Code ticket skills, and asks you to paste Claude Code's read-only token. `/runesmith-sprint:disable` removes it all. See `docs/howto/enable-atlassian.md`.

## Optional: populate an AI Operations Confluence space

Create the space in Confluence first (the Cloud API can't create spaces), then:

```
/runesmith-aiops:bootstrap-aiops
```

Structured prompts collect `{COMPANY}`, `{SITE}`, `{SPACE_KEY}`, `{SPACE_ID}` and `{PROJECT_KEY}`. The skill substitutes them into the template pages and publishes them.

## Verify the install

```
/runesmith-devtools:help
```

Lists every installed plugin and skill with its triggers.

```
/runesmith-jira:project-status
```

Read-only check that the Atlassian keys work, if you set them.

## Troubleshooting

**`401` on every Atlassian call.** The email and token must belong to the same account.

**`400` on a Confluence page create.** The body must be storage format, not markdown. The Confluence skills convert with `scripts/md-to-storage.py`; run your markdown through it if you call the API directly.

**`409` on a Confluence page update.** Version conflict. Read the page, take `version.number`, send `number + 1`. The skills do this for you.

**`404` on `/rest/api/3/search`.** That endpoint was retired; the current one is `POST /rest/api/3/search/jql`. You have an outdated plugin: rebuild and reinstall.

**Plugin not loading after a manual install.** Quit the app fully and reopen it.

**`/plugin marketplace add` says "Validation failed".** Two common causes:
1. `plugin.json` has a `dependencies` field. The loader rejects it.
2. A word wrapped in `<` and `>` in SKILL.md front matter or a plugin.json description. Use `{WORD}` curly braces. `scripts/audit.py` catches this.

**Severity field rejected on `runesmith-jira:bug-report`.** Severity is rarely a default Jira field. Map it to `priority`, or set `ATLASSIAN_BUG_SEVERITY_FIELD` to your custom field id.

**Slash commands say "Unknown command".** Restart the client; plugins register at session start. If they still don't resolve, check that `.claude-plugin/plugin.json` `name` matches the folder name.

**Old skill names (`reallocate`, `bootstrap-cc`).** They point at `/runesmith-workspace:init` and `/runesmith-cc:head` for one release, then go away.
