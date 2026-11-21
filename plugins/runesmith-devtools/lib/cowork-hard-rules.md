# Cowork hard rules (never break these)

These rules come from production incidents in Cowork plugin authoring. Each has a known failure mode and an audit check. Apply all of them to every plugin you build.

## 1. No em-dashes or en-dashes

- Em-dash (U+2014): banned everywhere.
- En-dash (U+2013): banned everywhere.

**Why:** PowerShell on Windows reads `.ps1` scripts as Windows-1252 by default. UTF-8 multi-byte em-dash sequences get misinterpreted, the parser breaks, the script fails to load. Any plugin that ships PowerShell installer scripts is exposed.

**Fix:** Use ASCII hyphen `-` or restructure the prose.

**Audit:** `check_no_emdashes()` walks all `.md`, `.json`, `.ps1`, `.sh`, `.py`, `.txt`, `.xhtml`, `.yml`, `.yaml` files and fails the build on any em-dash or en-dash hit.

**Gotcha:** JSON unicode escapes (U+2014 inside a JSON string literal, written as the six-character sequence backslash-u-2-0-1-4) bypass the byte-level scan. Cowork JSON-parses the file at load time and the em-dash renders to users anyway. The audit must also decode JSON strings and scan for U+2014/U+2013 directly. See `check_no_emdash_json_escapes()`.

## 2. Curly-brace placeholders only - never angle brackets

**Why:** Cowork's upload validator rejects angle-bracket patterns (a word wrapped in `<` and `>`) in SKILL.md frontmatter and `plugin.json` description fields as unsubstituted templating syntax. The plugin fails to install with no clear error.

**Fix:** Canonical placeholder syntax is `{WORD}` with curly braces. Examples: `{PROJECT}`, `{slug}`, `{KEY}`, `{YYYY-MM}`, `{PLACEHOLDER}`. Body content inside fenced code blocks is exempt - documentation examples can show HTML/XML.

**Audit:** `check_frontmatter_placeholders()` scans SKILL.md frontmatter and plugin.json `description` fields for the pattern `<[a-zA-Z][a-zA-Z0-9_-]*>` and fails the build on any match.

## 3. Structured prompts for every consent gate

**Why:** Plain-text "Should I proceed?" questions in chat are a protocol violation. Users won't always notice them, and "yes" answers can't be programmatically distinguished from regular chat. Every consent moment must use the host client's structured-input tool (in Cowork: `AskUserQuestion`).

**Fix:** Before any destructive operation (file move, delete, external mutation), surface a single-pick or text-input form. Common option set: Apply / Preview only / Cancel.

Every skill's SKILL.md must call this out explicitly in its frontmatter or workflow. State plainly that all user prompts use structured input, never freeform yes/no.

**Audit:** `check_forbidden_patterns()` rejects `[y/n]` and `[y]es/[n]o` patterns in skill files. These usually indicate a plain-text consent prompt snuck in.

## 4. Marker-bounded skill-managed sections in user files

**Why:** Skills that write into `CLAUDE.md`, `README.md`, or other user-edited files must not clobber user additions. The marker pattern lets the skill own a bounded section while preserving everything outside it.

**Pattern:**

```markdown
<!-- {skill-name}:start -->
... skill-managed content ...
<!-- {skill-name}:end -->
```

**Behavior:** On write, find markers; if present, replace content between them; if absent, append the full block (preceded by a blank line). Never touch content outside the markers.

**Marker name rules:**
- Specific enough to avoid collision. `<!-- folder-conventions:start/end -->` is fine; `<!-- generated:start/end -->` is too generic.
- Stable across versions. Renaming a marker breaks every workspace that already has the old name written.
- Opt-in feature sections should use their own dedicated marker pair so a separate skill can add or remove them cleanly.

## 5. Idempotence

Every skill must be safe to re-run. If the workspace is already in the target state, the skill detects and reports "already canonical" without re-doing work.

**Why:** Users re-run skills constantly - to refresh marker sections, to apply new templates, to retry after a partial failure. A skill that mutates state on every run is a footgun.

**Test:** Run the skill against its own output. If anything changes on the second run, the skill isn't idempotent. Fix it.

## 6. Command description anti-truncation

`commands/*.md` frontmatter descriptions must be 30+ characters and must not end mid-sentence at a placeholder boundary (e.g. "Bootstrap the {PROJECT}.cc/" - note the trailing period after the placeholder). If either condition fails, Cowork silently skips registering the command. The slash command then returns "Unknown command."

**Audit:** `check_command_descriptions()` rejects descriptions shorter than 30 chars or ending in `(\{[A-Z_]+\}|CLAUDE)\.\s*$`.

## 7. Sandbox shadow vs real filesystem

Cowork's bash environment is sandboxed and runs against a shadow of the project root. Direct file tools (Read/Write/Edit/Glob) operate on the real root. They can desync - bash sees a file that no longer exists in the real root, or misses a file that was just written.

**Symptom:** Bash fails with "No such file or directory" on a path the file tools confirm exists.

**Fix:** Switch vectors. Use the direct file tools first. If you must use bash for a script or shell pipeline, accept that the first run may need a sync via `cp` roundtrip to refresh the shadow.

Don't conflate "No such file" (sandbox bug) with "Permission denied" (real permission issue). They look similar; the responses are different.

**For skill authors:** Default to direct file tools (Read/Write/Edit/Glob). Reserve bash for shell pipelines and scripts that genuinely need a subprocess.

## 8. Two-tier project context separation

Cowork has two separate project-context surfaces. They look similar; they carry fundamentally different content. Skills must not mix them.

| Surface | Carries | Why it lives there |
|---|---|---|
| `CLAUDE.md` (file at workspace root) | Structural - folder layout, file paths, where things live | Changes as the workspace grows. Auto-loaded as file context at session start. |
| Project Instructions (Cowork UI field) | Behavioral - project mission, agent's role, rules for every conversation | Doesn't change with files. Loaded as system prompt every chat. |

**The line:** behavior vs structure.

- "Use structured prompts" -> behavioral -> Project Instructions
- "Plans live at `plans/active/{slug}/`" -> structural -> CLAUDE.md
- "Never push commits without consent" -> behavioral -> Project Instructions
- "Source lives at `path/to/source/`" -> structural -> CLAUDE.md

**Agent access:**
- Agent can read + write CLAUDE.md directly via file tools.
- Agent CANNOT see or edit Project Instructions. It can only produce TEXT for the user to paste into the UI.

**Every skill that mutates project-level context must:**
1. Edit `CLAUDE.md` for folder/state changes (marker sections, structure references).
2. Emit Project Instructions text for the user to paste when the project's role/mission has shifted (or on first bootstrap).
3. Surface the proposed text in a clearly-labelled copy-friendly code block at the end of the skill's output.

If behavior bleeds into CLAUDE.md, the role drifts whenever folder structure changes. If structure bleeds into Project Instructions, the role becomes stale the moment a folder moves. Different update cadences. Must stay separate.

## Pitfalls reference table

| # | Pitfall | Symptom | Fix |
|---|---|---|---|
| 1 | Extra `plugin.json` fields | "Unknown command" silent skip | Strip to `name`/`version`/`description`/`author` |
| 2 | YAML folded scalar description | Skill-tool dispatch fails | Single-line quoted string |
| 3 | Missing `compatibility` field | Skill-tool dispatch fails | Add `compatibility: Runs in the planner chat with the project's workspace folder connected.` |
| 4 | Angle-bracket placeholders (a word wrapped in `<` and `>`) | Upload validator rejects | Use `{WORD}` curly braces |
| 5 | Em-dashes / en-dashes | PowerShell parsing fails on Windows | ASCII hyphens or restructure |
| 6 | JSON unicode escapes for em-dashes | Byte audit misses, users see em-dash | Use literal hyphen in JSON, scan parsed strings |
| 7 | Command description too short / truncated | Command silently unregistered | 30+ chars, no trailing `{PLACEHOLDER}.` |
| 8 | Plain-text yes/no consent prompts | Protocol violation, user confusion | Use `AskUserQuestion` / structured input |
| 9 | Sandbox shadow desync | Bash "No such file" on real path | Switch to direct file tools |
| 10 | Skill not idempotent | Second run mutates state again | Detect canonical state, no-op |
| 11 | Marker block clobbers user content | User edits lost | Replace only between markers |
| 12 | Behavior/structure leaking between CLAUDE.md and Project Instructions | Stale or drifting role | Strict separation, behavior in UI field |
