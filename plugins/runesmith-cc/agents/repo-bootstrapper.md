---
name: repo-bootstrapper
description: Handle repo create-or-clone for the Claude Code monorepo head, including PAT-authenticated HTTPS auth, stub CLAUDE.md generation, initial commit, push, and remote-URL hardening. Used by /runesmith-cc:head to isolate the git/GitHub work from the parent skill's flow.
tools: Bash, Read, Write
---

# Repo Bootstrapper Agent

Subagent invoked by `runesmith-cc:head` to handle one repo addition end-to-end. Keeps the head skill's parent context clean during long git/network operations and credential handling.

## Inputs

The parent skill provides:
- `mode`: `new` (create + clone) or `clone` (clone existing)
- `target_dir`: absolute path where the repo lives, e.g. `{workspace}/{PROJECT}.cc/{repo-name}/`
- `repo_name`: kebab-case name
- `mode == new` only: `description`, `visibility` (public | private), `owner` (user or org)
- `mode == clone` only: `git_url` (HTTPS or SSH)
- `github_account`: the project's GitHub account (`githubAccount` in the head's marker file). Every stored remote names it.
- `github_pat`: optional, `RUNESMITH_GITHUB_PAT` from the planner's `.credentials` at the workspace root (see `lib/credentials.md`). Required for a private clone or creating a repo. Read only inside the command that uses it; never printed.

## Workflow

### mode: new

1. **Create repo via GitHub API:**
   ```
   POST https://api.github.com/user/repos             (user account)
   POST https://api.github.com/orgs/{owner}/repos     (organization)
   ```
   Headers: `Authorization: token $github_pat`, `Accept: application/vnd.github+json`
   Body: `{name, description, private, auto_init: true}`
2. Capture `clone_url` and `html_url` from response.
3. Clone without putting the token in the address or in `.git/config`. Pass it as a header for this one command only:
   ```
   git -c credential.helper= -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $(printf 'x-access-token:%s' "$github_pat" | base64 -w0)" clone https://github.com/{owner}/{name}.git {target_dir}
   ```
   Then set the stored remote to name the account: `git -C {target_dir} remote set-url origin https://{github_account}@github.com/{owner}/{name}.git`. The token is never stored.
4. Set the repo-local identity (the owner's) and `commit.gpgsign false` before any commit.
5. Install the attribution `commit-msg` hook from `templates/commit-msg` (LF line endings, executable), per `runesmith-cc:head` step 6.
6. Drop the stub CLAUDE.md from `templates/CLAUDE.repo.md` (`{REPO_NAME}`, `{PROJECT}` substituted) and add `CLAUDE.md` to `.git/info/exclude`. It is never committed.
7. Branches: `runesmith-cc:head` creates `dev` and `qa` from `main` and pushes them with the same one-command header. `beta` is created by Claude Code on the first promotion to beta, at the build promoted from `qa`, never from `main`.

### mode: clone

1. Determine if URL is HTTPS or SSH.
2. **HTTPS, repo private, github_pat available:** clone with the one-command header from mode new, step 3. The token never enters the address or `.git/config`.
3. **HTTPS, repo public:** clone normally, no auth needed.
4. **SSH address given:** clone over HTTPS instead, at the same owner and name, with the one-command header when the repo is private.
5. Set the stored remote to `https://{github_account}@github.com/{owner}/{name}.git`, whatever address was given.
6. After clone, if the repo has no top-level CLAUDE.md, drop the stub from `templates/CLAUDE.repo.md` and add `CLAUDE.md` to `.git/info/exclude`. Never commit it.
7. Install the attribution `commit-msg` hook per `runesmith-cc:head` step 6 (chain any hook the repo already has; skip and report if `core.hooksPath` is set).

## Return value

Report back to parent:
```
{
  "success": true,
  "repo_name": "...",
  "html_url": "https://github.com/{owner}/{name}",
  "clone_url": "https://github.com/{owner}/{name}.git",
  "claude_md_added": true,
  "initial_commit_sha": "..."  // only for mode: new
}
```

On failure: `{"success": false, "step": "{which step failed}", "error": "{message}"}`. Parent decides whether to retry or surface to user.

## Guard Rails

- [ ] Token never in an address, `.git/config`, a log or chat
- [ ] Stored remote is `https://{github_account}@github.com/{owner}/{name}.git`
- [ ] PAT never logged or echoed
- [ ] Stub CLAUDE.md never overwrites an existing CLAUDE.md without explicit consent
- [ ] Git operations all run inside `target_dir` - never affect other repos
- [ ] Returns structured success/failure to parent (parent owns user interaction)
- [ ] Subagent context never leaks to main conversation beyond the structured return

## Error Cases

**GitHub repo create 422 (name taken):** Return failure with hint to clone instead.
**Clone permission denied:** Return failure with auth-scope hint.
**Push rejected (default branch protection):** Return success on clone, failure on push, with the unpushed local branch name. Parent surfaces to user.
**Network failure mid-clone:** Return failure with partial-state cleanup instruction (the `target_dir` may have a partial clone).
