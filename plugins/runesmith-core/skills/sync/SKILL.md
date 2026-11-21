---
name: sync
description: "Sync installed plugins with latest versions and update AIOPS documentation. Use when \"sync plugins\", \"update plugins\", \"pull latest bootstrap\", \"refresh plugins\", or to get the newest skill definitions."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Sync Plugins

Pull latest plugin versions from the marketplace repo and (optionally) refresh AIOPS pages from updated templates.

## References

- `lib/credentials.md`
- `lib/install-paths.md`
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

1. Credentials resolved.
2. `RUNESMITH_GITHUB_PAT` set in the planner's `.credentials` (workspace root; see `lib/credentials.md`).
3. Detect runtime per `install-paths.md` (Cowork vs. Claude Code).
4. For AIOPS refresh: confirm `{SPACE_ID}` is set and accessible.

## When to Use

Use for:
- Pulling marketplace updates (skills, libs, templates)
- Refreshing AIOPS pages after template changes

Do not use for:
- First install (use `/runesmith-core:install`)
- Authoring plugins (use `/runesmith-devtools:plugin-builder`)

## Workflow

### 1. Fetch marketplace

For each marketplace URL (default = this repo, plus any `PLUGIN_SOURCES`):
- Use `RUNESMITH_GITHUB_PAT` if the repo is private.
- Read `.claude-plugin/marketplace.json`.
- For each plugin: read `.claude-plugin/plugin.json` for current version.

### 2. Compare with installed

For each installed plugin (path resolved per `install-paths.md`):
- Read installed version.
- Compare with marketplace version.
- Mark as: up-to-date | update available | not-installed.

### 3. Apply updates

For each "update available":
- Show diff summary (skills added/removed, version bump).
- Ask user: "Update {plugin} from vX → vY?"
- On consent, replace plugin files (preserve user-local overrides if any).

### 4. Refresh AIOPS templates (optional)

If user opts in:
- Read each file in `aiops/templates/`.
- For each existing AIOPS page (lookup by title in `{SPACE_ID}`):
  - GET version, substitute tokens, PUT with `version+1`.
- Per `confluence-format.md`.

### 5. Report

```
✓ Sync complete
core      v0.2.0 → v0.3.0   (skills changed: …)
atlassian v0.2.0 → v0.2.1   (no skill changes)
aiops     up to date
devtools  up to date

AIOPS pages refreshed: 6 of 6
```

### 6. Restart notice

```
⚠ Restart your Claude client (or reload plugins) for changes to take effect.
```

## Guard Rails

- [ ] Credentials and `RUNESMITH_GITHUB_PAT` resolved
- [ ] Versions compared before any write
- [ ] User consents per plugin update
- [ ] AIOPS update path: GET → version+1 → PUT
- [ ] On 409: re-GET, retry once
- [ ] Unresolved tokens block AIOPS refresh
- [ ] Restart notice shown

## Error Cases

**GitHub 401:** PAT invalid or expired. "Run `/runesmith-core:setup` to refresh."
**GitHub 403:** PAT missing `repo` scope.
**Marketplace 404:** URL wrong; check `PLUGIN_SOURCES`.
**Plugin file write fails:** Permission issue; show install path and ask user to fix.
**AIOPS PUT 409:** Re-GET version, retry once.
