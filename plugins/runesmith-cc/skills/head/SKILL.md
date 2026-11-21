---
name: head
description: "Build or refresh the Claude Code head {PROJECT}.cc/: its CLAUDE.md with the builder standing rules, settings, comms folders, RuneSmith's builder skills and the repos. Called by runesmith-workspace:init; run it alone to add a repo, refresh the head, or turn a workspace-only project into a code project. Use when the user says \"add a repo\", \"clone a repo into the head\", \"refresh the head\", \"bootstrap CC\", or \"set up Claude Code\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Head

Builds the `{PROJECT}.cc/` folder that Claude Code works in, and keeps it current. It replaces `bootstrap-cc`. Idempotent.

## References

- `agents/repo-bootstrapper.md` - creates or clones one repo
- `lib/cc-workspace.md` - the head's structure and marker file
- `lib/comms-protocol.md` - comms folder layout
- `lib/credentials.md` - where Claude Code's keys live; `RUNESMITH_GITHUB_PAT`
- `lib/agent-operating-principles.md` - file access, deleting, snapshots
- `lib/naming.md` - name normalization
- `lib/code-analyzers.md` - for the `runesmith-code-tech-debt` skill
- `templates/` - `CLAUDE.parent.md`, `CLAUDE.repo.md`, `comms-README.md`, `settings.json`, `claude-README.md`, `commit-msg`, `gitignore`, `gitattributes`, `README.md`, `marker.json`
- `lib/user-prompts.md` - structured prompts

## Interview rule

Show first, then ask. Ask only when the answer changes what gets built; do obvious defaults and say so. Structured prompts, recommended option first. When `runesmith-workspace:init` calls this skill, init has already asked the questions; take its answers.

## Pre-Flight Checks

### 0. Comms check

See `lib/comms-check.md`.

### 1. Workspace root

From the session's connected folders. If the project folder isn't connected, request access. Work through the shell on the user's computer, never the chat's own file tools.

### 2. Head name

Per `lib/naming.md`: from the primary git repo's folder name, else the workspace folder name. Ask only when there are several repos (which is primary) or the name normalizes to nothing.

### 3. Delete permission

Moves, git and hook installs need it. Ask once for the workspace folder before the first change.

## Workflow

### 1. Show the plan, get consent

```
Head: {name}.cc/  ({fresh | refresh | legacy claude-code/ rename})
Repos moving in: {list}
Files written or refreshed: CLAUDE.md sections, settings, comms folders, skills
Legacy comm folders to rename: {n}
```

Structured prompt: **Apply** (default) / **Preview only** / **Cancel**. Skipped when init already got consent.

### 2. Snapshot

Copy what will move or change to `archive/_pre-head-{UTC}/`.

### 3. Move

- `claude-code/` becomes `{name}.cc/`.
- Each git repo at the workspace root moves into `{name}.cc/{normalized-repo}/` as a whole. Never entered.

### 4. Files from templates

Create what's missing; never overwrite a file the project changed, except the marker sections and keys listed below.

| Path | Source |
|---|---|
| `CLAUDE.md` | `templates/CLAUDE.parent.md`, with `{PROJECT}`, `{CHANGELOG_AUDIENCES}` and `{DEV_RESET_RULE}` from init's answers |
| `README.md` | `templates/README.md` |
| `.claude-code-workspace` | `templates/marker.json` |
| `.claude/settings.json` | `templates/settings.json` |
| `.claude/README.md` | `templates/claude-README.md` (the boundary, the escape hatch and its approval table) |
| `.claude/settings.local.json` | `{}` (git-ignored) |
| `comms/README.md` | `templates/comms-README.md` |
| `comms/open/.gitkeep`, `comms/archive/.gitkeep` | empty |
| `.gitignore`, `.gitattributes` | `templates/gitignore`, `templates/gitattributes` |
| `.credentials` | RuneSmith's block with empty values, when Claude Code needs keys (see step 8; format and runestack's zones in `lib/credentials.md`) |

**Existing `CLAUDE.md`:** replace only the content between `<!-- agent-ops:start -->` and `<!-- agent-ops:end -->` with the template's. Seed empty `atlassian-section` markers if missing. Leave everything else as it is, including other tools' marker sections (`runestack-credentials`, `runestack-stack`). A start marker without its end marker: stop and report.

**Existing `.claude/settings.json`:** parse it and merge only these keys, keeping every other key and value:

```json
"attribution": { "commit": "", "pr": "", "sessionUrl": false },
"includeCoAuthoredBy": false,
"env": { "CLAUDE_CODE_STOP_HOOK_BLOCK_CAP": "3" },
"enabledPlugins": { "code-simplifier@claude-plugins-official": true },
"permissions": { "additionalDirectories": [] }
```

Merge into `env`, `enabledPlugins` and `permissions` without removing their other entries; `additionalDirectories` is created empty only when missing, and existing entries are kept. A top-level `additionalDirectories` left by an older release moves into `permissions.additionalDirectories` (Claude Code reads only that one). Never write `"attribution": false` (older Claude Code releases reject it and skip the whole file). Not valid JSON: don't rewrite it; report the parse error. Warn if `settings.local.json` turns attribution back on.

### 5. RuneSmith's builder skills

Each skill gets its own folder directly under `.claude/skills/`, named with the `runesmith-` prefix, so Claude Code finds it and runestack's `runestack-*` skills never collide:

| Folder | Source |
|---|---|
| `.claude/skills/runesmith-clean-code/SKILL.md` | `cc-skill-templates/clean-code/skill-template.md`, with `{LINT_COMMANDS}` left for the stack to fill |
| `.claude/skills/runesmith-code-tech-debt/SKILL.md` and `lib/code-analyzers.md` | `cc-skill-templates/code-tech-debt/` |
| `.claude/skills/runesmith-release/SKILL.md` | `cc-skill-templates/release/skill-template.md` |

Refresh replaces only `runesmith-*` folders, and only when the project hasn't changed the deployed copy since the last refresh (compare against the copy in the snapshot). A changed copy is kept and reported. Legacy folders (`code-tech-debt/` without the prefix, `atlassian/{name}/`) move to `archive/_pre-head-{UTC}/` after the prefixed copy is in place.

`runesmith-sprint:enable` deploys the Jira builder skills the same way (`runesmith-sprint-pull/`, `runesmith-ticket-document/`, `runesmith-blocker-write/`, `runesmith-ticket-done/`).

### 6. Attribution hook in every repo

`templates/commit-msg`, installed in each repo in the head, with LF line endings and the executable bit:
- `core.hooksPath` set: don't write there; report it.
- No hook, or a RuneSmith hook (it carries the `runesmith-no-attribution` line): write the template.
- Someone else's hook: rename it to `commit-msg.local` (stop if that exists), then write the template, which runs the old hook first.
- Probe (with `git hook run commit-msg -- {file}` on git 2.36 or later; on older git, run the hook file directly with `sh`): run the hook on a sample message with a Claude co-author trailer, a session line and a "Generated with Claude Code" line; confirm all three are stripped and a human co-author is kept.

History is never rewritten.

### 7. Legacy comms

Rename each `comms/open/{PREFIX}-{NNN}-{slug}/` folder to `{created UTC}-{slug}/` (from the task's `created:`), and rename the files inside to match. Rename `attachments/` to `references/`. Loose files in `comms/open/` move into a folder of their own the same way. `archive/` is left as it is.

### 8. Repos

Add each repo init or the owner asked for through the `repo-bootstrapper` agent: create (name, description, visibility, owner; needs `RUNESMITH_GITHUB_PAT` from the planner's credentials file) or clone (address). After each: add it to the marker's `repos[]`, install the hook (step 6), and drop a stub `CLAUDE.md` from `templates/CLAUDE.repo.md` if the repo has none. Add `CLAUDE.md` to the repo's `.git/info/exclude` so the builder's instruction file never enters the repository (no AI tool names in the repo).

**The GitHub account (Ben, 2026-11-21).** Every repo pushes as the project's own account, so a machine with several GitHub accounts (personal, a company's, an organization's) never pushes as the wrong one and never asks again after the first sign-in.

- The account is `githubAccount` in the head's marker file, set by init (step 9). Run alone with none recorded, ask the same question.
- Every repo's `origin` (fetch and push) is `https://{account}@github.com/{owner}/{repo}.git`. Set it after each clone or create. On a refresh, rewrite any `origin` that differs: an SSH address (`git@github.com:{owner}/{repo}.git`), an address with no account or another account, a stale organization spelling, or a separate `pushurl`. Report each rewrite with its old address. Never put a token in the address.
- Login check: this session can't read the owner's own git settings, so give him one line that tests the account with no prompt, and the fix if it fails:

  ```
  git -C "{repo path on his computer}" push --dry-run origin HEAD
  ```

  If it asks for a password or signs in as another account, another credential helper is answering for github.com (for example the GitHub command-line tool signed in as a different account). Give him these two lines, which route only this account to Git Credential Manager and leave every other account alone; the first push after opens a browser sign-in once:

  ```
  git config --global --add credential.https://{account}@github.com.helper '""'
  git config --global --add credential.https://{account}@github.com.helper manager
  ```

**Branches (Ben, 2026-11-21). After adding a repo, make sure `dev`, `qa` and `beta` exist beside `main`. Any that are missing are created from `main` and pushed (when the repo has a remote), and `dev` becomes the default branch Claude Code works from. Existing branches are never moved or rewritten.

**Branch protection (Ben, 2026-11-21).** Protection is a guardrail on Claude Code, so RuneSmith owns it, not the stack tooling. For each repo with a GitHub remote, on `dev`, `qa`, `beta` and `main`, through the GitHub REST API with `RUNESMITH_GITHUB_PAT` (Administration write), read the branch's protection, then `PUT /repos/{owner}/{repo}/branches/{branch}/protection` with:

- pull request required, `required_approving_review_count` 0 (the builder merges its own goal branches into `dev`);
- `allow_force_pushes` false and `allow_deletions` false;
- `enforce_admins` false, so the owner's own git access can still make the fast-forward a promotion calls for;
- a required build check only when the repo already reports one: take the check names from the newest commit on `dev` (or `main`). The check itself comes from the project's CI, which is the stack tooling's; with none yet, leave checks out and say "re-run head once the build check exists".

Only add what's missing. Never remove a rule, a required check or a review requirement the repo already has. A local repo with no remote is skipped and reported.

Claude Code's own keys go in `{name}.cc/.credentials`, never inside a repo folder. Without Jira there may be none; then no file is created.

### 9. Security scan

- Remote addresses with a token in them (`https://ghp_...@`, `x-access-token:`): report, with the command to reset the remote after rotating the token.
- Credentials files, `.env` files or keys inside a repo folder: report.

### 10. Report

```
Head: {workspace}/{name}.cc/
Repos: {list}
GitHub account: {account}; remotes: {repo}: https://{account}@github.com/{owner}/{repo}.git{ (rewritten from: old address)}
Branches: {repo}: dev, qa, beta present{ (created: list)}; protection on dev, qa, beta, main: {set | added: list | skipped: no remote | refused: reason}{; build check: name | none yet}
Skills: runesmith-clean-code, runesmith-code-tech-debt, runesmith-release{, Jira skills}  (kept, changed by project: {list})
Settings: attribution off, stop-hook cap 3, code-simplifier enabled
Hooks: {repo}: installed | updated | chained | skipped (core.hooksPath), probe pass/fail
Legacy comms renamed: {n}
Security: {findings, or none}
Open the head in Claude Code: {absolute path}
If Claude Code says code-simplifier is enabled but not installed: claude plugin install code-simplifier@claude-plugins-official --scope project
```

## Guard Rails

- [ ] Right folder connected; work on the user's disk only
- [ ] Delete permission asked once before the first change
- [ ] Snapshot before any change; consent unless init already had it
- [ ] Only RuneSmith's marker sections and listed settings keys rewritten
- [ ] A damaged marker stops the run
- [ ] Skills deployed one level under `.claude/skills/` with the `runesmith-` prefix
- [ ] Project-changed skill copies kept
- [ ] Hook installed or chained and probed in every repo; no hook deleted; no history rewritten
- [ ] Branch protection added on all four branches; nothing the repo already had removed or loosened
- [ ] Every `origin` names the project's GitHub account; no SSH or account-less address left
- [ ] No credentials inside a repo folder
- [ ] No token left in a stored remote address

## Error Cases

**No `RUNESMITH_GITHUB_PAT` and the owner wants a new repo:** say which file and key, offer clone instead, or wait for him to paste it.
**Repo name taken (422):** structured choice: another name, or clone it.
**Clone refused:** say whether the session's network allowlist refused it or GitHub did (401 or 403 names the missing permission).
**Settings file not valid JSON:** report; don't rewrite.
**Protection refused (403):** say why: the token lacks Administration write (name the permission), or the repo is private on a GitHub plan without branch protection (it needs a public repo or a paid plan). The builder's rules in CLAUDE.md still apply either way.
**Head exists with non-standard content:** show the difference; structured choice: replace with template / keep / cancel.
