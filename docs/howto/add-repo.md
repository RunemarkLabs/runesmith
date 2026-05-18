# How-to: Add an Existing Repo to a CC Head

You already have a CC head at `{PROJECT}.cc/` and want to add another repo to it — either by cloning an existing GitHub repo or by creating a new one.

## Prerequisites

- Workspace already has a CC head: `{PROJECT}.cc/CLAUDE.md` exists. If not, run `/runesmith-cc:bootstrap-cc` first.
- For private GitHub repos or repo creation: `GITHUB_PAT` in `.credentials` with appropriate scopes (`repo` for cloning private, `repo` + `admin:org` for org repo creation).

## Two paths

### Path A — Clone an existing repo

```
/runesmith-cc:bootstrap-cc
```

Bootstrap-cc is idempotent. Re-running on an existing CC head opens a structured prompt for additional repo operations:

- Add a new repo (creates on GitHub + clones)
- Clone an existing repo (paste URL)
- Skip

Pick "clone an existing repo," paste the URL (HTTPS or SSH form, plugin normalizes). The skill:

1. Resolves the repo name from the URL.
2. Normalizes the destination folder name per `plugins/runesmith-cc/lib/naming.md` (kebab-case-lowercase). Shows you both the raw name and the normalized form via structured prompt — confirm or edit.
3. Authenticates via `GITHUB_PAT` if the repo is private.
4. Clones into `{PROJECT}.cc/<normalized-name>/`.
5. Drops a stub `CLAUDE.md` into the repo if one doesn't exist (from `plugins/runesmith-cc/skills/bootstrap-cc/templates/CLAUDE.repo.md`). You review and edit before committing.
6. Updates `{PROJECT}.cc/.claude-code-workspace` (the marker file) with the new repo entry.

### Path B — Create a new GitHub repo + clone it

Same skill, pick "add a new repo" instead. Additional structured prompts:

- **Name** (raw input). Normalized form shown alongside. Confirm or edit.
- **Description** (single line).
- **Visibility**: structured single-pick — `public` / `private`.
- **Owner**: defaults to your GitHub login from `.credentials` (parsed from the PAT's permissions). Edit if you want it under an org instead.

The skill delegates to the `repo-bootstrapper` subagent:

1. `POST /user/repos` (or `/orgs/<owner>/repos`) to create the repo via the PAT.
2. Clones it locally into `{PROJECT}.cc/<normalized-name>/`.
3. Drops the CLAUDE.md stub.
4. Initial commit + push to set up `main`.

Repository ends up in your GitHub account/org and in your CC head, in sync.

## What lives in the new repo's CLAUDE.md

The stub from `CLAUDE.repo.md` template carries:

- Repo identity (name, derived from folder name)
- Pointer to parent `{PROJECT}.cc/CLAUDE.md` for shared rules
- Pointer to workspace `CLAUDE.md` via the `@../../../CLAUDE.md` path
- Placeholder for the project-specific rules you'll add

Edit it before committing. The marketplace doesn't try to write opinionated rules for your repo — that's project-specific.

## The marker file

`{PROJECT}.cc/.claude-code-workspace` (JSON) tracks every repo in the head:

```json
{
  "project": "<cc-head-name>",
  "initialized": "<ISO>",
  "schemaVersion": 1,
  "atlassianEnabled": false,
  "atlassian": null,
  "repos": [
    {
      "name": "<repo-1>",
      "path": "./<repo-1>",
      "migratedFrom": null
    },
    {
      "name": "<repo-2>",
      "path": "./<repo-2>",
      "migratedFrom": null
    }
  ]
}
```

Bootstrap-cc updates this on every run. Don't edit by hand — re-running the skill keeps it canonical.

If `atlassianEnabled` is true, the `atlassian` object will carry project key, board id, space id (populated by `/runesmith-sprint:enable`).

## Verify

```
ls {PROJECT}.cc/
```

Should show the new repo folder alongside any existing ones.

```
cat {PROJECT}.cc/.claude-code-workspace
```

Should list the new repo in the `repos[]` array.

```
cd {PROJECT}.cc/<new-repo>
git status
git remote -v
```

Confirms the clone worked and the remote is set.

## Troubleshooting

**`fatal: could not read Username for 'https://github.com'`.** PAT not in `.credentials` or wrong scope. Verify `GITHUB_PAT` exists and has at least `repo` scope. For org repos, also `admin:org`.

**Folder name conflict.** Bootstrap-cc detects existing folders in `{PROJECT}.cc/` and normalizes new repo names to avoid collision. If you get a "destination exists" error, pick a different name in the structured prompt.

**Repo created on GitHub but clone failed.** The repo exists upstream; only the local clone bombed. Re-run bootstrap-cc, pick "clone existing," paste the URL. Don't try to recreate — `POST /user/repos` will 422 on the duplicate name.

**Stub CLAUDE.md not appearing.** Bootstrap-cc only drops the stub if the cloned repo lacks a top-level CLAUDE.md. If you cloned a repo that already has one, the existing file is preserved. Edit it manually if you want the parent + workspace pointers.

**Cross-repo paths in the new repo's tools fail.** The CC head boundary stops at `{PROJECT}.cc/<repo>/` — each repo is its own scope to CC. If you need shared code, use git submodule, monorepo tooling (Nx/Lerna/Turbo), or add the sibling to `{PROJECT}.cc/.claude/settings.json` under `additionalDirectories` as a documented escape hatch. See `docs/howto/install-guardrail.md` for the escape hatch rules.
