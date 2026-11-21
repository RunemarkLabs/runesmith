---
name: setup
description: "Check and set up RuneSmith's credentials: list which keys are set or missing in the right file, tell you where to paste missing ones, and run the health checks. Never asks for a secret in chat. Use when the user says \"set up\", \"configure\", \"add credentials\", \"check my credentials\", \"rotate a token\", or a skill reports a missing key."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Setup

Checks the credentials RuneSmith needs, in the files `lib/credentials.md` names, and runs health checks. `runesmith-workspace:init` runs the same check; use this skill on its own to add, rotate or verify keys later.

## References

- `lib/credentials.md` - the rule, file locations, keys, failure handling
- `lib/install-paths.md` - where plugins are installed
- `lib/user-prompts.md` - structured prompts

## Interview rule

Show first, then ask. Ask only when the answer changes what happens. Never ask for a credential's value.

## Workflow

### 1. Find the files

From the session's connected folders (request access if the project folder isn't connected):
- the planner's file: `{WORKSPACE_ROOT}/.credentials`;
- Claude Code's file: `{PROJECT}.cc/.credentials`, when the project has a head.

### 2. Report what's set

Read only key names and whether each has a value. Print nothing else from the files.

```
Planner credentials ({WORKSPACE_ROOT}/.credentials)
  ATLASSIAN_API_URL        set
  ATLASSIAN_API_EMAIL      set
  ATLASSIAN_API_TOKEN      missing
  RUNESMITH_GITHUB_PAT     set
  PLUGIN_SOURCES           not used

Claude Code credentials ({PROJECT}.cc/.credentials)
  CC_ATLASSIAN_API_EMAIL   set
  CC_ATLASSIAN_API_TOKEN   set
  ATLASSIAN_BOARD_ID       set
```

Keys are only listed as needed when the project uses what they're for: Atlassian keys when Jira and Confluence are on, the Claude Code keys when there's a head and Jira.

### 3. Missing keys

If a file doesn't exist, create it with the needed key names and empty values, and make sure it's git-ignored. Then tell the owner:

```
Open {path} and paste:
  ATLASSIAN_API_TOKEN   (create one at https://id.atlassian.com/manage-profile/security/api-tokens)
  RUNESMITH_GITHUB_PAT  (create one at https://github.com/settings/tokens; needs repo creation and issue read)
Tell me when it's done.
```

When he says it's done, go to step 4. Never ask him to paste a value into chat. If he pastes one anyway, don't repeat it; tell him to rotate it, since it's now in the conversation.

### 4. Health checks

Run each with the key read inside the command, per `lib/credentials.md`:
- Confluence: `GET {ATLASSIAN_API_URL}/wiki/api/v2/spaces?limit=1`, expect 200.
- Jira: `GET {ATLASSIAN_API_URL}/rest/api/3/myself`, expect 200; report the account's display name.
- GitHub: `GET https://api.github.com/user` with `RUNESMITH_GITHUB_PAT`, expect 200; report the login.
- Claude Code's Jira token: the same Jira call with `CC_ATLASSIAN_API_EMAIL` and `CC_ATLASSIAN_API_TOKEN`.
- Plugin sources (optional): fetch each address; expect 200 and valid JSON.

Tell a refusal by the session's network allowlist apart from a 401 or 403 (`lib/credentials.md`).

### 5. Report

```
Credentials: {all set | missing: KEY in file, ...}
Confluence: ok | 401 | not reachable from this session
Jira: ok (you = {display name}) | ...
GitHub: ok (you = {login}) | ...
Claude Code's Jira token: ok | ...
Plugin sources: ok | not configured
```

## Guard Rails

- [ ] Files found from the connected folders, never the current directory
- [ ] No value printed, masked or partial
- [ ] No value asked for in chat
- [ ] Missing files created with key names only, and git-ignored
- [ ] Planner keys at the workspace root; Claude Code's keys in the head; nothing inside a repo folder
- [ ] Allowlist refusals told apart from credential failures

## Error Cases

**401 from Atlassian:** the email and token don't match; the email must be the account that created the token.
**403 from GitHub on repo creation:** `RUNESMITH_GITHUB_PAT` lacks repo-creation rights.
**Legacy `RUNESMITH_GITHUB_PAT` only:** accepted in the planner's file; suggest renaming it to `RUNESMITH_GITHUB_PAT`.
**Planner keys found in the head's file:** report it; Claude Code can read that file. Tell the owner to move them to the workspace root file.
