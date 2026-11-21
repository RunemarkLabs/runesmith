---
name: help
description: "Show all available workspace skills, installed plugins, and what they do. Use when the user says \"help\", \"what can you do\", \"list skills\", \"show commands\", \"what skills are there\", or seems unsure what's available. Also use when the user asks \"how do I...\", \"is there a way to...\", or \"can you...\" about a workflow that might already be covered by a plugin or skill."
model: haiku
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Workspace Help

Show installed plugins and their skills, and route the user to the right one for a given workflow.

Read-only. No consent gate.

## References

- `lib/install-paths.md` - runtime detection and plugin scan paths

## Pre-Flight Checks

None.

## When to Use

Use for:
- "what can you do?"
- "how do I…?" workflow questions
- Onboarding a new user

Do not use for:
- Installing plugins → `/runesmith-core:install`
- Configuring credentials → `/runesmith-core:setup`

## Workflow

### 1. Detect runtime

Per `install-paths.md`:
1. `CLAUDE_PLUGINS_DIR` env var if set.
2. `~/.claude/plugins/` if exists (Claude Code / Teams). Subdirs are installed plugins.
3. Walk up from cwd for `rpm/plugin_*` (Cowork). Each `plugin_*` directory is one installed plugin.
4. If neither found, only show built-ins.

### 2. Scan installed plugins

For each plugin directory:
- Read `.claude-plugin/plugin.json` for name + description.
- List `skills/*/SKILL.md` files; read frontmatter `name` + `description`.

### 3. Always include built-ins

If this marketplace is installed, ensure these are listed:
- core (plan, install, sync, setup)
- atlassian (ticket, bug-report, feature-doc, architecture-doc, project-overview, project-status, new-project, decisions-log, known-issues, roadmap, session-log)
- aiops (bootstrap-aiops)
- devtools (help, plugin-builder, tech-debt, skill-updater)

### 4. Format output

Group by plugin, alphabetical within group. One line per skill: `/{plugin}:{skill} - {one-line description}`.

```
Installed plugins (n)

core
  /runesmith-core:plan          - Discuss before writing
  /runesmith-core:install       - Browse and install plugins
  /runesmith-core:sync          - Pull latest plugin versions
  /runesmith-core:setup         - Configure credentials

atlassian
  /runesmith-jira:ticket   - Create a Jira ticket
  …

aiops
  /aiops:bootstrap-aiops - Populate AIOPS space

devtools
  /runesmith-devtools:help      - This help
  …

Try /runesmith-core:install to add more, or /runesmith-core:setup to configure credentials.
```

### 5. Topic search (if user asked "how do I X?")

Match X against skill descriptions. Suggest top 1-3 matches with their trigger phrases.

## Guard Rails

- [ ] Runtime detected (or marked unknown)
- [ ] All installed plugins scanned
- [ ] Built-ins included if installed
- [ ] Output is scannable, grouped, alphabetical
- [ ] No file writes, no API calls
- [ ] Skill descriptions match actual SKILL.md frontmatter

## Error Cases

**No plugins found:** "No plugins installed. Try /runesmith-core:install."
**Plugin scan permission denied:** "Cannot read plugin directory. Check permissions on {path}."
**Unknown topic in search:** Suggest /runesmith-core:install and the marketplace URL.
