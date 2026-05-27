---
name: plugin-builder
description: "Create Cowork plugins from scratch with full skill scaffolding, production-ready frontmatter, and audit-passing structure. Use when the user says \"create a plugin\", \"new plugin\", \"add a skill\", \"make a plugin\", \"build a plugin\", \"I need a new skill\", \"scaffold a plugin\", \"start a plugin from scratch\". Also triggers on \"package this plugin\" or \"install this plugin\". Not for editing existing skills (edit directly) or installing from catalog (use /core:install)."
compatibility: Requires Cowork desktop app environment.
---

# Plugin Builder

Create new Cowork plugins from scratch. Workflow: describe capability -> scaffold structure -> author with hard rules applied -> audit -> package -> install.

The skill enforces the production-tested conventions documented in this plugin's `lib/` files. Skills built here pass audit out of the box and dispatch reliably under Cowork.

## References

- `lib/plugin-json-schema.md` - minimum manifest schema, forbidden fields, naming
- `lib/skill-md-frontmatter.md` - required frontmatter, description format, trigger surface
- `lib/cowork-hard-rules.md` - no em-dash, curly placeholders, structured prompts, marker sections, idempotence, sandbox shadow, two-tier context model, condensed pitfalls table
- `lib/build-and-audit.md` - audit.py rules, build script, dist convention, CHANGELOG, versioning
- `lib/release-maintenance.md` - HARD RULES for post-publish maintenance: per-plugin versioning (no blanket bumps), `[MarketplaceName vX.Y.Z]` description prefix, CHANGELOG-only-what-moved, per-bump checklist
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

## Workflow

### 1. Pre-flight read

Before any user prompts, read these lib files into context:

- `lib/plugin-json-schema.md`
- `lib/skill-md-frontmatter.md`
- `lib/cowork-hard-rules.md`
- `lib/build-and-audit.md`

If any are missing, this skill is broken; surface the missing reference and stop.

### 2. Describe the plugin (structured prompts)

Collect via separate structured prompts:

- **Plugin name** (text input): kebab-case-lowercase. Show normalized form alongside raw input. Reject names that collide with installed marketplaces.
- **One-line description** (text input): single sentence, what the plugin does. Used as the seed for the longer `plugin.json` description in step 4.
- **Author / org** (text input): defaults to the workspace owner if known.
- **Number of skills** (single-pick): 1-3 / 4-6 / 7+. Influences the per-skill prompting depth in step 3.

### 3. For each skill (structured prompts, per skill)

Collect via separate structured prompts:

- **Skill name** (text input): kebab-case-lowercase.
- **Skill description seed** (text input): one sentence stating what the skill does. The full description in step 5 will pack this with trigger phrases.
- **Trigger phrases** (text input, multi-line): list of natural-language phrases users might say to invoke this skill. 