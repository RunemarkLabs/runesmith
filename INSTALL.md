# Install

The RuneSmith marketplace ships **eight plugins**:

| Plugin | Required | Purpose |
|---|---|---|
| `runesmith-core` | yes | Credentials, plugin management, chat-first planning. Foundation. |
| `runesmith-workspace` | yes | Canonical workspace structure (`_INBOX/`, `plans/`, snapshots). |
| `runesmith-cc` | yes | `{PROJECT}.cc/` Claude Code monorepo head + project-boundary guardrail. |
| `runesmith-jira` | optional | Jira ticket and project workflows. |
| `runesmith-confluence` | optional | Confluence page authoring with markdown → storage XHTML conversion. |
| `runesmith-sprint` | optional | Atlassian sprint workflow + Cowork ↔ CC interconnect. |
| `runesmith-aiops` | optional | Bootstrap an AI Operations Confluence space from templates. |
| `runesmith-devtools` | optional | Developer helpers (skill scaffold, tech-debt, skill-updater). |

Three install paths. Pick one based on your client.

## Path A — Marketplace add (Claude Code CLI users)

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

This works for Claude Code CLI sessions. After install, restart the CLI and run `/runesmith-core:setup` to populate `.credentials`.

## Path B — Manual .plugin files (Cowork desktop)

`.plugin` zips aren't committed; build them on demand:

```
python scripts/build.py        # cross-platform; recommended on Windows
# or:
bash scripts/build.sh          # macOS / Linux
```

Produces `runesmith-*.plugin` files in `./dist/` (gitignored). Custom output dir:

```
python scripts/build.py /path/to/output
```

Then in Cowork desktop:

1. **Customize** in the left sidebar.
2. Drag the eight `.plugin` files from `./dist/` into the upload area.
3. Restart Cowork.
4. Run `/runesmith-core:setup`.

Install `runesmith-core` first — others depend on its lib refs.

## Path C — Cowork Team / Enterprise org-synced marketplace

Cowork's GitHub-synced marketplaces require **private or internal** repos — public repos are not allowed for org marketplaces. Two options:

### C.1 — Mirror to a private repo in your org

```bash
git clone --bare https://github.com/runemarklabs/runesmith.git
cd runesmith.git
git push --mirror https://github.com/<your-org>/<your-private-repo>.git
```

Then in your org admin:

1. **Organization settings → Plugins → Add plugin → GitHub source.**
2. Enter `<your-org>/<your-private-repo>`.
3. Click "Update" to trigger the initial sync.

Make sure the Cowork GitHub App is installed on the private repo. Without that, the sync 404s.

### C.2 — Managed-settings deployment (Enterprise)

Admins on Enterprise plans can ship the marketplace contents as **managed settings**. See Cowork's admin docs for managed-settings file delivery. The marketplace doesn't directly produce managed-settings JSON; use the user-level settings layout (from `runesmith-cc:guardrail`) as a template.

## Configure credentials

Run `/runesmith-core:setup` after install. The skill walks structured prompts for:

| Key | Required for | Where to get it |
|---|---|---|
| `ATLASSIAN_API_URL` | Atlassian skills | Your Atlassian site URL (e.g. `https://acme.atlassian.net`) |
| `ATLASSIAN_API_EMAIL` | Atlassian skills | Email of the account that minted the token |
| `ATLASSIAN_API_TOKEN` | Atlassian skills | https://id.atlassian.com/manage-profile/security/api-tokens |
| `GITHUB_PAT` | runesmith-cc clone/create | https://github.com/settings/personal-access-tokens (fine-grained PAT with `Contents: Read/Write` on target repos) |
| `ATLASSIAN_CONFLUENCE_SPACE_ID` | Confluence skills | Settings → Space Settings → Space details |
| `ATLASSIAN_JIRA_PROJECT_KEY` | Jira / sprint skills | The short uppercase identifier (e.g. `ENG`) |
| `ATLASSIAN_JIRA_BOARD_ID` | sprint skills | Numeric board id from the board URL |
| `ATLASSIAN_DEFAULT_ASSIGNEE_ACCOUNT_ID` | sprint:enable | Your accountId — use `atlassianUserInfo` MCP call |
| `ATLASSIAN_BUG_SEVERITY_FIELD` | bug-report (custom) | Custom field id (e.g. `customfield_10001`) if your tenant uses one |
| `PLUGIN_SOURCES` | optional | Comma-separated additional marketplace URLs |

`.credentials` lives at workspace root (gitignored). Override location with `BOOTSTRAP_WORKSPACE` env var.

`.credentials.example` in this repo lists every key with placeholder values. Copy it and fill in.

## Install the project-boundary guardrail (one-time per machine)

After install