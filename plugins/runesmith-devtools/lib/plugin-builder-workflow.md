# Plugin Builder Workflow Detail

Detailed workflow for `runesmith-devtools:plugin-builder`. The SKILL.md is the compact entry point; this file holds the load-bearing steps + invariants.

## Workflow steps

### 3. For each skill (structured prompts, per skill)

Collect via separate structured prompts:

- **Skill name** (text input): kebab-case-lowercase.
- **Skill description seed** (text input): one sentence stating what the skill does. The full description in step 5 will pack this with trigger phrases.
- **Trigger phrases** (text input, multi-line): list of natural-language phrases users might say to invoke this skill. Examples: "set up the workspace", "fix the structure", "tidy the workspace". 5-10 phrases recommended.
- **Workflow summary** (text input, multi-line): bulleted list of the steps the skill takes when invoked.
- **Mutations** (single-pick): does this skill mutate user files / external systems? Yes / No / Read-only. If yes, the skill template will include consent-gate boilerplate per `lib/consent.md`.

### 4. Generate plugin scaffold

Create the plugin folder at `plugins/{plugin-name}/`:

```
plugins/{plugin-name}/
  .claude-plugin/
    plugin.json
  skills/
    {skill-1}/
      SKILL.md
    {skill-2}/
      SKILL.md
  lib/                       # created empty; populated if the skill uses shared content
  README.md                  # one-line description of what the plugin does
```

**`plugin.json` must use the minimum schema from `lib/plugin-json-schema.md`:**

```json
{
  "name": "{plugin-name}",
  "version": "0.1.0",
  "description": "{200-400 char paragraph derived from step 2 description and the per-skill descriptions in step 3. No em-dashes. No angle brackets. Ends with a period.}",
  "author": {
    "name": "{author}"
  }
}
```

Do NOT include `dependencies`, `license`, `repository`, `homepage`, or `keywords`. The plugin loader silently drops plugins with these fields.

### 5. Generate each `SKILL.md`

Per `lib/skill-md-frontmatter.md`, every SKILL.md must:

1. Use YAML frontmatter with single-line quoted `description:`, never folded scalar (`description: >`).
2. Include `compatibility: Runs in the planner chat with the project's workspace folder connected.`
3. Have `name:` matching the folder name.
4. Pack the description with the trigger phrases collected in step 3, in the pattern: "what the skill does. Use when the user says X, Y, Z."

Skill body must include:

- **References block** listing any lib/ or agents/ files the skill uses (backtick-quoted paths; the audit verifies they resolve).
- **User input rules** block stating that all prompts use structured input.
- **Pre-flight checks** block (comms check if applicable; workspace root resolution).
- **When to use / not to use** block.
- **Workflow** numbered steps. Each step describes what happens, what gets surfaced to the user, what consent is required.
- **Idempotent re-run** block: what happens when the skill runs against an already-converged state.
- **Guard Rails** checklist of invariants.
- **Error cases** block.

If the skill mutates state, the workflow must include a structured consent gate before any mutation, per `lib/cowork-hard-rules.md` rule 3.

If the skill writes into user files (`CLAUDE.md`, `README.md`), the content must be marker-bounded per rule 4.

### 6. Review and iterate

Surface the generated `plugin.json` and every `SKILL.md` in chat. Show them as code blocks. Ask via structured prompt:

- **Looks good** -> proceed to step 7
- **Edit a file** -> single-pick which file, then text-input form pre-filled with current content
- **Cancel** -> abort, leave the scaffold for manual editing

### 7. Run audit

If the marketplace has a `scripts/audit.py`, run it from the marketplace root. Report findings inline.

If audit fails, surface the failures via structured prompt:

- **Fix automatically** -> apply known fixes (em-dash to ASCII, angle to curly placeholder, strip forbidden plugin.json fields)
- **Edit manually** -> open the file at the line with the issue
- **Skip and proceed** -> not recommended; warns the user

Do not proceed to step 8 with audit failures unless the user explicitly accepts the risk.

### 8. Package

Zip the plugin folder to `dist/{plugin-name}.plugin`. Use forward-slash separators (matters for cross-platform install). Exclude development artifacts (`__pycache__`, `.pytest_cache`, `.git`).

### 9. Install instructions

Report:

```
- Plugin created and packaged

Plugin: {plugin-name}
Skills: {skill-1}, {skill-2}, ...
Audit: pass

Package: dist/{plugin-name}.plugin

To install:
1. Drag {plugin-name}.plugin into Cowork sidebar (or use marketplace.json source path if publishing)
2. Restart Cowork if needed
3. Try: /{plugin-name}:{skill-1}

To publish in this marketplace:
1. Add an entry to .claude-plugin/marketplace.json under plugins[]
2. Bump marketplace.json metadata.version
3. Add a CHANGELOG entry
4. Commit and push
```

## Idempotent re-run

If a plugin folder by the same name already exists, surface a structured prompt:

- **Update existing** -> diff what would change, apply selectively
- **Cancel** -> stop without modifying

Do NOT overwrite an existing plugin without the user's explicit single-pick consent. Plugins under development carry user-edited content this skill cannot reproduce.

## Guard rails

- [ ] All four hard-rule lib files read before generating content
- [ ] Plugin name normalized to kebab-case-lowercase
- [ ] `plugin.json` uses minimum schema (name, version, description, author) - no other fields
- [ ] Every `SKILL.md` has `compatibility:` field
- [ ] Every `SKILL.md` has single-line quoted `description:`, not folded scalar
- [ ] Every `SKILL.md` `name` matches folder
- [ ] No em-dashes or en-dashes in any generated file
- [ ] No angle-bracket placeholders in SKILL.md frontmatter or plugin.json description
- [ ] Mutation skills include structured consent gate
- [ ] File-writing skills use marker-bounded sections
- [ ] All `lib/{your-helper}.md` and `agents/{your-agent}.md` references in generated SKILL.md resolve to real files
- [ ] All user prompts use structured input
- [ ] Generated plugin passes the marketplace's `scripts/audit.py`
- [ ] `.plugin` file written to `dist/`

## Error cases

**Invalid plugin name:** "Use kebab-case-lowercase (a-z, 0-9, hyphens). No spaces or other special characters."

**Plugin already exists:** Surface structured prompt - update existing / cancel.

**Audit fails after generation:** Do not skip. Surface the failures and offer auto-fix / manual edit / accept risk.

**Marketplace has no `scripts/audit.py`:** Warn the user and offer to bootstrap one from this plugin's `lib/build-and-audit.md` reference implementation.

**Sandbox shadow desync during write:** Per `lib/cowork-hard-rules.md` rule 7, switch to direct file tools. Do not retry the same bash command.

## Release maintenance

After publishing a plugin, follow the hard rules in `lib/release-maintenance.md`:

- Bump only the plugin that changed. Other plugins stay at their current version.
- The `[MarketplaceName vX.Y.Z]` prefix in the plugin's description must track the new version (use `scripts/bump-version.py`).
- CHANGELOG entry names only the plugins that actually moved.
- Marketplace `metadata.version` is the max across all plugin versions, recomputed automatically by `bump-version.py`.
