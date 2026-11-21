# Plugin Install Paths

Where RuneSmith's plugins live once installed, for skills that need to read installed plugin files (the installed copy is authoritative; see `lib/agent-operating-principles.md`, "The installed plugin is authoritative").

## The Claude desktop app and claude.ai (the planner chat)

Plugins are installed from a marketplace or by uploading a `.plugin` file in the app's plugin settings. Their files are managed by the app and are not in the project's connected folders. A skill reads its own installed files through its loaded skill context, never through the user's disk or a sibling project that holds the plugin's source.

## Claude Code

```
~/.claude/plugins/
```

Marketplace-managed plugins sit under `~/.claude/plugins/marketplaces/{owner}/{repo}/plugins/{plugin-name}/`. Project-scoped plugins are declared in the project's `.claude/settings.json` under `enabledPlugins` (`runesmith-cc:head` turns on `code-simplifier@claude-plugins-official` this way).

RuneSmith's builder skills are not installed as plugins in Claude Code: `runesmith-cc:head` copies them into the head's `.claude/skills/runesmith-{name}/`, and re-running init refreshes them.

## Detection order for skills

1. `CLAUDE_PLUGINS_DIR` environment variable, when set.
2. `~/.claude/plugins/` (Claude Code).
3. The skill's own loaded context (the desktop app and claude.ai).
4. Nothing found: suggest `/runesmith-core:install`.

## Marketplace install (recommended)

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-core@runesmith
/plugin install runesmith-workspace@runesmith
/plugin install runesmith-cc@runesmith
/plugin install runesmith-sprint@runesmith
```

Add `runesmith-jira`, `runesmith-confluence`, `runesmith-aiops` and `runesmith-devtools` as needed.

## Manual install (`.plugin` files)

A `.plugin` file is a zip of one plugin folder (the folder holding `.claude-plugin/plugin.json`) as its top-level entry:

```
runesmith-core.plugin
└── runesmith-core/
    ├── .claude-plugin/plugin.json
    ├── skills/...
    └── lib/...
```

Build all of them with `python scripts/build.py` from the marketplace repo; they land in `dist/`.
