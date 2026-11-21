# `plugin.json` schema rules

Every plugin lives at `plugins/{plugin-name}/` and must contain `.claude-plugin/plugin.json` with exactly these four fields and nothing else:

```json
{
  "name": "your-plugin-name",
  "version": "0.1.0",
  "description": "One-paragraph description. Use {PLACEHOLDER} syntax only, never angle brackets. End with a period. No em-dashes.",
  "author": {
    "name": "Your Org Name"
  }
}
```

## Forbidden fields

Cowork's plugin loader silently drops plugins whose `plugin.json` carries extra fields beyond the minimum. Known offenders observed in production:

- `dependencies`
- `license`
- `repository`
- `homepage`
- `keywords`

All common in npm-style manifests. All rejected here. The plugin still appears in the session-start manifest but `/{plugin}:{skill}` returns "Unknown command." There is no error log.

License goes in a top-level `LICENSE` file at the marketplace root, or omit entirely if your repo's license suffices. Author can be a string or `{"name": "..."}`; both work.

## Name must match folder

`plugins/foo-bar/.claude-plugin/plugin.json` must have `"name": "foo-bar"`. The audit script enforces this. Folder rename = manifest rename.

## Naming convention

Kebab-case-lowercase. Pick a prefix that won't collide with public marketplaces a user might install alongside yours. Internal marketplaces should use an org-specific prefix.

## Description rules

- Single paragraph, ends with a period.
- No em-dashes (U+2014) or en-dashes (U+2013). ASCII hyphens only.
- No angle-bracket placeholders (a word wrapped in `<` and `>`). Use curly braces (`{WORD}`).
- No unicode escapes for em-dashes (U+2014, written as the six-character sequence backslash-u-2-0-1-4) inside JSON strings - they render as em-dash on parse and the byte-level audit misses them.
- 200-400 characters is the sweet spot. Long enough to be informative, short enough to render cleanly in catalog UIs.

## Audit checks that enforce this

- `check_plugin_manifests()` - required fields, name matches folder.
- `check_forbidden_plugin_fields()` - rejects `dependencies` explicitly. Extend the list as new offenders are identified.
- `check_frontmatter_placeholders()` - scans plugin.json `description` for angle-bracket placeholders.
- `check_no_emdashes()` - byte-level em-dash scan.
- `check_no_emdash_json_escapes()` - JSON-decode then scan parsed strings for U+2014/U+2013.
