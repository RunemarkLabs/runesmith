# `SKILL.md` frontmatter rules

Every skill lives at `{plugin}/skills/{skill-name}/SKILL.md` and starts with YAML frontmatter:

```yaml
---
name: skill-name
description: "Single-line quoted string. No line breaks. Use {WORD} placeholders, never angle brackets. State the skill's job in the first sentence; list trigger phrases the user might say after that."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---
```

## Required fields

- `name` - matches the skill folder name exactly. Kebab-case-lowercase.
- `description` - single-line quoted string. See format rules below.
- `compatibility` - one plain sentence saying where the skill runs. Planner skills: `Runs in the planner chat with the project's workspace folder connected.` Builder skill templates (`cc-skill-templates/`): `Runs in Claude Code, inside the project's head.`

## Description format

Must be a YAML single-line quoted string (`description: "..."` on one line). Do NOT use YAML's folded block scalar form (`description: >` with multi-line indented body). Anthropic's first-party skills (docx, pdf, pptx, xlsx, skill-creator) use single-line quoted strings. The folded form alone is not always the breaking issue, but switching to quoted removes a variable when debugging dispatch failures.

If your description is genuinely too long for one line, shorten it. The description is the trigger surface; it should be punchy.

## Why `compatibility` matters

Cowork's Skill-tool dispatcher can silently fail to register skills missing the `compatibility:` field. Combined with the `plugin.json` minimum-schema strip, adding `compatibility:` to every SKILL.md resolves most reliable dispatch failures. Ship with both.

## Description is the trigger surface

Cowork's intent classifier matches the user's natural-language request against the description. Pack it with trigger phrases users might say.

Pattern:

1. First sentence: what the skill does.
2. Next sentence or two: "Use when the user says X, Y, Z" with concrete trigger phrases in quotes.
3. Optional last sentence: explicit "Do NOT use for" guard rails for things that look similar but should route elsewhere.

Look at Anthropic's first-party skills for the canonical pattern.

## Name must match folder

`skills/foo/SKILL.md` must have `name: foo` in frontmatter. The audit script enforces this. Folder rename = frontmatter rename.

## Content rules

- No em-dashes (U+2014) or en-dashes (U+2013) anywhere in the file. ASCII hyphens only.
- No angle-bracket placeholders in frontmatter (a word wrapped in `<` and `>`). Use curly braces (`{WORD}`).
- Body content inside fenced code blocks is exempt from the placeholder rule - documentation examples can show HTML/XML.

## Audit checks that enforce this

- `check_skill_frontmatter()` - required fields present, name matches folder.
- `check_frontmatter_placeholders()` - scans SKILL.md frontmatter for angle-bracket placeholders.
- `check_no_emdashes()` - byte-level em-dash scan.
- `check_references()` - any backtick-quoted `lib/x.md` or `agents/x.md` reference in the SKILL.md body must resolve to a real file.
