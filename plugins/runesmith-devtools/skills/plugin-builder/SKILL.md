---
name: plugin-builder
description: "Create Cowork plugins from scratch with full skill scaffolding, production-ready frontmatter, and audit-passing structure. Use when the user says \"create a plugin\", \"new plugin\", \"add a skill\", \"make a plugin\", \"build a plugin\", \"I need a new skill\", \"scaffold a plugin\", \"start a plugin from scratch\". Also triggers on \"package this plugin\" or \"install this plugin\". Not for editing existing skills (edit directly) or installing from catalog (use /core:install)."
compatibility: Requires Cowork desktop app environment.
---

# Plugin Builder

Create new Cowork plugins from scratch. Workflow: describe capability -> scaffold structure -> author with hard rules applied -> audit -> package -> install.

The skill enforces the production-tested conventions documented in this plugin's `lib/` files. Skills built here pass audit out of the box and dispatch reliably under Cowork.

## References

- `lib/plugin-builder-workflow.md` - detailed steps 3-9, idempotent re-run, guard rails, error cases, release maintenance
- `lib/plugin-json-schema.md` - minimum manifest schema, forbidden fields, naming
- `lib/skill-md-frontmatter.md` - required frontmatter, description format, trigger surface
- `lib/cowork-hard-rules.md` - no em-dash, curly placeholders, structured prompts, marker sections, idempotence, sandbox shadow, two-tier context model, condensed pitfalls table
- `lib/build-and-audit.md` - audit.py rules, build script, dist convention, CHANGELOG, versioning
- `lib/release-maintenance.md` - HARD RULES for post-publish maintenance: per-plugin versioning, description prefix, CHANGELOG-only-what-moved, per-bump checklist
- `lib/user-prompts.md` - structured prompt patterns
- `lib/consent.md` - consent-gate trigger phrases

Read all five hard-rule lib files (`plugin-json-schema`, `skill-md-frontmatter`, `cowork-hard-rules`, `build-and-audit`, `release-maintenance`) before generating any plugin content. They are load-bearing.

## User input rules

Every user prompt in this skill MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. Per `lib/user-prompts.md`.

## When to use

- Creating brand-new plugins with custom skills
- Packaging custom workflows
- Building org-specific capabilities
- Scaffolding skills beyond the bootstrap plugins in this marketplace

**Do NOT use for:**

- Modifying existing plugins (edit directly)
- Installing plugins from catalog (use `/runesmith-core:install`)
- Creating simple one-off scripts (use chat or a temp file)

## Workflow overview

See `lib/plugin-builder-workflow.md` for detail on every step below.

1. **Pre-flight read** - load the four hard-rule lib files into context. If any are missing, the skill is broken; surface and stop.
2. **Describe the plugin** (structured prompts) - plugin name, one-line description, author, number of skills.
3. **For each skill** (structured prompts, per skill) - name, description seed, trigger phrases, workflow summary, mutations flag. See lib for full prompt list.
4. **Generate plugin scaffold** - create `plugins/{plugin-name}/` with `.claude-plugin/plugin.json`, per-skill `SKILL.md`, empty `lib/`, and `README.md`. Plugin.json uses minimum schema only (name, version, description, author).
5. **Generate each SKILL.md** - YAML frontmatter (single-line quoted description, compatibility field, name matches folder), body with References / User input rules / Pre-flight / When-to-use / Workflow / Idempotent re-run / Guard Rails / Error cases. Mutation skills include consent gate; file-writing skills use marker-bounded sections.
6. **Review and iterate** - surface generated files, prompt looks-good / edit / cancel.
7. **Run audit** - `scripts/audit.py` if present. Do not proceed on