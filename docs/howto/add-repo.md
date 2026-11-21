# How-to: Add a Repo to a Claude Code Head

You have a head at `{PROJECT}.cc/` and want another repo in it, cloned from GitHub or created new.

## Prerequisites

- The head exists (`{PROJECT}.cc/CLAUDE.md`). If not, run `/runesmith-workspace:init` and answer yes to code.
- For a private clone or a new repo: `RUNESMITH_GITHUB_PAT` in the workspace `.credentials`. A fine-grained token needs Contents read and write and Issues read on the repo; Administration write is needed to create repos and to set branch protection (for an organization, on that organization).

## Run head

```
/runesmith-cc:head
```

On an existing head it refreshes the head's files and skills, then shows the repos already there and asks:

- **None** (done)
- **Clone an existing repo:** the address, HTTPS or SSH form.
- **Create a new repo:** name (the normalized folder name is shown beside it), description, visibility (private or public), and owner (you or an organization).

Repeat until you pick None.

## What happens for each repo

The `repo-bootstrapper` agent does the git work:

1. Creates the repo on GitHub when asked (`POST /user/repos` or `/orgs/{owner}/repos`).
2. Clones into `{PROJECT}.cc/{normalized-name}/` over HTTPS, even when you give an SSH address. The token is passed for that one command and never stored.
3. Sets the address to `https://{account}@github.com/{owner}/{repo}.git`, naming the project's GitHub account, so the repo always pushes as that account.
4. Adds the repo to `{PROJECT}.cc/.claude-code-workspace` (`repos[]`).
5. Installs the commit hook that strips AI attribution, and probes it.
6. Drops a `CLAUDE.md` stub from `templates/CLAUDE.repo.md` if the repo has none, and adds it to `.git/info/exclude` so it never enters the repository.
7. Creates `dev`, `qa` and `beta` from `main` when they're missing, pushes them, and makes `dev` the branch Claude Code works from. Existing branches are never moved.
8. Protects `dev`, `qa`, `beta` and `main`: pull request required (no approvals, since Claude Code merges its own goal branches into `dev`), no force-push, no deletion, and the build check when the repo already reports one. It only adds what's missing and never loosens existing rules. The check itself comes from the project's CI, which isn't RuneSmith's; once it exists, run head again to require it.

## The marker file

`{PROJECT}.cc/.claude-code-workspace` lists the head's repos:

```json
{
  "project": "{PROJECT}",
  "initialized": "{ISO_TIMESTAMP}",
  "schemaVersion": 1,
  "atlassianEnabled": false,
  "atlassian": null,
  "repos": [
    { "name": "{repo}", "path": "./{repo}" }
  ]
}
```

The head keeps it current. Don't edit it by hand.

## Verify

```
git -C {PROJECT}.cc/{repo} branch -a
git -C {PROJECT}.cc/{repo} remote -v
git -C {PROJECT}.cc/{repo} check-ignore CLAUDE.md
```

Shows the four branches, a remote with no token in it, and that `CLAUDE.md` is excluded.

## Troubleshooting

**`fatal: could not read Username for 'https://github.com'`.** `RUNESMITH_GITHUB_PAT` is missing or can't see the repo. Check the key and the token's repository access.

**422 on create.** The name is taken. Pick another, or clone the existing repo.

**A push asks for a password, or goes out as the wrong account.** Another sign-in helper is answering for github.com, often the GitHub command-line tool signed in as a different account. Route just this account to Git Credential Manager; other accounts are untouched:

```
git config --global --add credential.https://{account}@github.com.helper '""'
git config --global --add credential.https://{account}@github.com.helper manager
```

The next push opens a browser sign-in once.

**Created on GitHub but the clone failed.** The repo exists; run head again and clone it. Creating it again returns 422.

**Clone refused.** The head says whether the session's network allowlist refused it, or GitHub did (401 or 403 names the missing permission).

**The repo already had a `CLAUDE.md`.** It's kept. Add it to `.git/info/exclude` yourself if it shouldn't be committed.

**A tool needs files from a sibling repo.** Each Claude Code session stays inside its launch project. For legitimate shared access, add the path to `permissions.additionalDirectories` in `{PROJECT}.cc/.claude/settings.json` and record why in the table in `{PROJECT}.cc/.claude/README.md`. See `docs/howto/install-guardrail.md`.
