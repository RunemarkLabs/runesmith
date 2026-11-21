---
name: install
description: "Browse and install plugins from the bootstrap catalog and optional sources. Use when the user says \"install a plugin\", \"what plugins are available\", \"show me plugins\", or wants to add new capabilities."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Install Plugins

Browse and install plugins from this marketplace and optional catalogs.

This skill explains both install paths (marketplace and manual) and routes the user to the right one for their runtime.

## References

- `lib/install-paths.md` - Cowork vs. Claude Code paths, marketplace flow
- `lib/credentials.md` - `PLUGIN_SOURCES` key

## Pre-Flight Checks

1. Detect runtime:
   - If `~/.claude/plugins/` exists → Claude Code / Teams.
   - Else if `rpm/plugin_*` walking up from cwd → Cowork session.
   - Else → unknown; default to manual instructions.
2. Read `.credentials` for optional `PLUGIN_SOURCES` (comma-separated URLs).

## When to Use

Use for:
- Adding optional plugins from this or third-party marketplaces
- Listing what's available before installing
- Switching install method (manual vs. marketplace)

Do not use for:
- Authoring new plugins → `/runesmith-devtools:plugin-builder`
- Updating installed plugins → `/runesmith-core:sync`

## Workflow

### 1. Show built-in plugins (this marketplace)

Always available in this repo:

```
core      - Planning, configuration, plugin management
atlassian - Jira + Confluence skills
aiops     - AIOPS space templates and bootstrap
devtools  - Workspace tooling (help, plugin-builder, tech-debt, ...)
```

### 2. Show optional catalogs (if `PLUGIN_SOURCES` set)

For each URL in `PLUGIN_SOURCES`, fetch and parse marketplace.json. List plugins with: name, description, skills count.

If unreachable: warn, skip.

### 3. Recommend install method

Based on runtime detected:

**Claude Code / Teams (preferred for this repo):**
```
/plugin marketplace add <git-url-or-owner/repo>
/plugin install core@bootstrap
/plugin install atlassian@bootstrap
/plugin install aiops@bootstrap
/plugin install devtools@bootstrap
```

**Cowork (manual):**
1. Download `.plugin` file from repo `dist/` directory or releases.
2. Drag into the Cowork sidebar plugin area.
3. Restart Cowork session.

### 4. After install

Confirm: "Run /runesmith-core:setup to configure credentials, then /runesmith-devtools:help to see all skills."

## Guard Rails

- [ ] Runtime detected (or marked unknown)
- [ ] Built-in plugins listed
- [ ] Optional catalogs only shown if reachable
- [ ] Install path matches runtime
- [ ] No write to plugin directories from this skill (install is user-initiated)

## Error Cases

**`PLUGIN_SOURCES` unreachable:** Warn, fall back to built-in only.
**Unknown runtime:** Show both manual and marketplace instructions.
**Install fails (user-reported):** Point at `INSTALL.md` in repo root for troubleshooting.
