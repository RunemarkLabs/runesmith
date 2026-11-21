# Release process

How to ship a RuneSmith release. This repo is the public marketplace; private work (plans, drafts, notes) lives in the maintainer's workspace outside this folder and never enters the repo.

## Versions

Each plugin has its own SemVer track in its `.claude-plugin/plugin.json`. Bump only the plugins that changed. The marketplace version (`.claude-plugin/marketplace.json` `metadata.version`) moves with every release.

- **MAJOR:** breaking changes to a skill name, a library convention, the comms protocol or the workspace layout.
- **MINOR:** new skills, new plugins, new agents.
- **PATCH:** fixes, wording, internal refactors.

Each plugin's description starts with `[RuneSmith v{version}]`, and the matching entry in `marketplace.json` repeats it. Keep both in step; `scripts/bump-version.py` does it for you.

## Steps

1. Update the changed plugins' versions and descriptions.
2. Add the `CHANGELOG.md` entry under `## [{version}] - {YYYY-MM-DD}`: Added, Changed, Removed, Fixed, and a Migration section when anything breaks.
3. Update every copy when a convention changes: each plugin's shared library files (copies must stay identical), templates, READMEs, the docs, the AI Operations templates.
4. Run the audit and fix anything it reports:

   ```
   python scripts/audit.py
   ```

5. Build the zips and install them locally to try them:

   ```
   python scripts/build.py
   ```

6. Commit to `main` and push. If `main` is protected, commit on a release branch and merge it through a pull request instead. CI runs the audit on every push.
7. Tag the release (`git tag v{version}`) and push the tag with the branch: `git push origin main v{version}`.

## What the audit checks

- The marketplace manifest, plugin manifests, skill front matter and command descriptions are valid; no `dependencies` field.
- No word wrapped in `<` and `>` in front matter or descriptions.
- No forbidden phrasing (plain-text yes or no prompts, secret-paste wording and the like).
- No em dashes or en dashes.
- Library references resolve inside each plugin.
- Every file is complete: no NUL bytes, a final newline.
- Shared library files are identical across plugins.

## Forks

Anyone can fork and adapt the marketplace. Runemark Labs does not maintain forks. Tenant-specific changes live in the fork, never here: this repo stays generic, and the audit enforces it.
