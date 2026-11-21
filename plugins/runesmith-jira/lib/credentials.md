# Credentials

How every RuneSmith skill finds, reads and reports credentials.

## The rule

- **A credential may be read to use it in a single command. It is never printed** to chat, logs, comms, commits or files. Pass it to the command that needs it, through an environment variable for that one command.
- **Skills report only `set` or `missing`** for each key. No masking and no partial values: even the first four characters are a leak.
- **Secrets never pass through chat.** When a value is missing, the skill tells the owner which key to paste into which file, and waits for him to say it's done. It never asks for a token as a prompt answer.
- **When CLAUDE.md has a `runestack-credentials` section,** that section governs how the file is laid out and read. RuneSmith only adds its own lines where that section says.

## Where the files are (Ben, 2026-11-21)

**Each key lives where the thing that uses it runs, and never inside a git repo folder.**

1. Find the workspace root from the session's connected folders, never from the current directory. If the project's folder isn't connected, request access first.
2. **The planner's keys** (full-access Atlassian, `RUNESMITH_GITHUB_PAT`, plugin sources): `{WORKSPACE_ROOT}/.credentials`. Claude Code never reads this file.
3. **Claude Code's keys** (its read-only Jira token, and anything else the builder needs): `{PROJECT}.cc/.credentials`, at the head's top level. The repos are subfolders of the head, so Claude Code can use these while they never enter a repo.
   - When runestack is in use, runestack owns this file. RuneSmith's builder keys go in one block in zone 1 (see "runestack's file format" below).
4. **Never** put a credentials file inside `{PROJECT}.cc/{repo}/`.

Both files are git-ignored. Init adds the patterns if they're missing.

## RuneSmith's keys

```
ATLASSIAN_API_URL=https://{site}.atlassian.net
ATLASSIAN_API_EMAIL={account email}
ATLASSIAN_API_TOKEN={API token from id.atlassian.com}
RUNESMITH_GITHUB_PAT={GitHub token that can create repos and read issues}
```

Optional:

```
PLUGIN_SOURCES={comma-separated marketplace addresses}
ATLASSIAN_CONFLUENCE_SPACE_ID={numeric id, default project space}
ATLASSIAN_JIRA_PROJECT_KEY={default project key}
ATLASSIAN_DEFAULT_ASSIGNEE_ACCOUNT_ID={account id}
ATLASSIAN_BUG_SEVERITY_FIELD={custom field id}
```

Claude Code's read-only Jira token (Atlassian-enabled code projects), in `{PROJECT}.cc/.credentials`, pasted by the owner when `runesmith-sprint:enable` asks:

```
CC_ATLASSIAN_API_EMAIL={account email for the read-only token}
CC_ATLASSIAN_API_TOKEN={read-only token}
ATLASSIAN_BOARD_ID={board id}
```

- **Atlassian keys** are only needed when the project uses Jira and Confluence.
- **The planner's keys above live in the workspace root file. Claude Code's keys below live in the head file.**
- **`RUNESMITH_GITHUB_PAT`** is separate from runestack's `GITHUB_PAT` (Ben, 2026-11-21). runestack's token is limited to one product's repo; RuneSmith's needs to create repos and read issues. In RuneSmith's own file, a legacy `GITHUB_PAT` is accepted when `RUNESMITH_GITHUB_PAT` is missing. In runestack's file, `GITHUB_PAT` is runestack's and is never used by RuneSmith.

## File format

Both files use the same line format: `KEY='value'`, every value single-quoted, including empty ones (`KEY=''`). Key names are uppercase letters, digits and underscores. Keys are grouped in blocks, each starting with a dashed comment header whose second line names the owner:

```
# ------------------------------------------------------------
# Atlassian (planner)
# Owner: runesmith
# Console: https://id.atlassian.com/manage-profile/security/api-tokens
# ------------------------------------------------------------
ATLASSIAN_API_URL=''
ATLASSIAN_API_EMAIL=''
ATLASSIAN_API_TOKEN=''
```

A skill creates a missing block with empty values and never fills in a secret. Keys that aren't secret (a site address, a board id) may be filled by the skill that knows them, in its own block only.

## runestack's file format (agreed with runestack, 2026-11-21)

When runestack is in use, `{PROJECT}.cc/.credentials` has two zones, each between marker lines: zone 1 between `# <runestack-credentials:zone-1-start>` and `# <runestack-credentials:zone-1-end>` (values the owner pastes), and zone 2 between the `zone-2-start` and `zone-2-end` markers (values runestack's plugins write).

- RuneSmith owns exactly one block in zone 1, after runestack's blocks:

  ```
  # ------------------------------------------------------------
  # Atlassian (Claude Code, read-only)
  # Owner: runesmith
  # Console: https://id.atlassian.com/manage-profile/security/api-tokens
  # ------------------------------------------------------------
  CC_ATLASSIAN_API_EMAIL=''
  CC_ATLASSIAN_API_TOKEN=''
  ATLASSIAN_BOARD_ID=''
  ```

- If the block is missing, append it just before `# <runestack-credentials:zone-1-end>`.
- If it's present, leave the token lines alone; the owner pastes them. `ATLASSIAN_BOARD_ID` (not a secret) may be set by `runesmith-sprint:enable`, in this block only.
- Edit only blocks whose `# Owner:` line is `runesmith`. Never edit a runestack block. Never write to zone 2.

## Using a key

Read the one line inside the command that needs it. For example, the Atlassian basic-auth header:

```
Authorization: Basic {base64 of "{ATLASSIAN_API_EMAIL}:{ATLASSIAN_API_TOKEN}"}
Accept: application/json
Content-Type: application/json
```

Build it in the shell, use it in the same command, and discard it.

## When a call fails

Tell these apart before blaming the credential:
- **Refused before it left:** the request never reached the service because the session's network allowlist blocks the host. Say that the host isn't reachable from this session. The credential is fine.
- **401:** the email and token don't match, or the token expired. Name the key to replace.
- **403:** the token lacks a permission. Name the permission (for example, Administration write on `RUNESMITH_GITHUB_PAT` for repo creation or branch protection).

On a 401 or 403, read the file once more (the owner may just have pasted a new value), retry once, then report.
