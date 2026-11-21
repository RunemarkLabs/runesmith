# Contributing to RuneSmith

Thanks for your interest. RuneSmith is a Claude plugin marketplace built around four principles:

1. **Generic, single-tenant configurable.** No company-specific values in plugin source. Every tenant detail (Jira project key, Confluence space, GitHub PAT) comes from user input or `.credentials`.
2. **Consent before any write.** Every skill that mutates Jira / Confluence / repos / state requires an explicit user trigger phrase. See `plugins/runesmith-core/lib/consent.md`.
3. **Structured prompts only.** Every user-input question MUST use the host client's structured input UI (single-pick, multi-pick, text-input form), never plain-text "yes/no" or "[y/n]". See `plugins/runesmith-core/lib/user-prompts.md`.
4. **Plugin-relative library references.** Each plugin is self-contained. Skills cite libs as `lib/{name}.md` (relative to the plugin), not cross-plugin paths.

## How to contribute

### Reporting issues

Open an issue describing:
- Which plugin and skill
- What you expected vs. what happened
- Reproduction steps (paste the chat sequence if possible)
- Claude desktop or Claude Code version

### Proposing changes

Small fixes - open a PR directly. Larger changes - open an issue first to discuss scope.

PRs that change cross-plugin conventions (token names, comms protocol, REST endpoint patterns) should:
- Update the relevant lib doc first (in the plugin owning the convention)
- Run `/runesmith-devtools:skill-updater` to propagate the change to all skills that cite the lib
- Note the change in `CHANGELOG.md` under Unreleased

### Building locally

```bash
bash dist/build.sh
```

Produces `.plugin` zip files in `dist/` ready for manual install or marketplace distribution.

### Testing a plugin

1. Drag the `.plugin` file from `dist/` into the Claude desktop plugin sidebar.
2. Quit and reopen the app.
3. Run `/runesmith-devtools:help` to confirm the new skills are loaded.
4. Exercise at least one skill end-to-end.

## Coding conventions

### Plugin manifest

- **Plugin names** are lowercase-kebab-case. Capital letters break upload validation.
- **plugin.json** must include `name`, `version`, `description`, `author`. `license`, `repository`, `homepage` and `keywords` are optional. Never add `dependencies`: the loader rejects plugins that carry it, and the audit fails.
- **Versions:** each plugin has its own SemVer track; bump only what changed (`scripts/bump-version.py`).

### Skill authoring

- **Skill names** match the folder name. Both lowercase-kebab-case.
- **Frontmatter** uses YAML with `name` and `description` (both required). Optional: `model: haiku` for read-only skills.
- **Descriptions** must include natural-language trigger phrases: list common ways a user might invoke the skill (e.g. "Use when user says 'create a ticket', 'make the ticket', 'draft a Jira issue'..."). Without trigger phrases, auto-invoke from chat fails.

### User input (CRITICAL)

Every skill that asks the user a question MUST cite `lib/user-prompts.md` and use structured input. The audit and CI reject plain-text yes or no prompts.

| User-input type | What to use |
|---|---|
| Pick one of N options | **Structured single-pick form** |
| Pick multiple of N options | **Structured multi-pick form** |
| Type a value (name, URL, slug) | **Structured text-input form** with default pre-populated |
| Confirm an action | **Structured single-pick form** with Apply / Preview / Cancel options |

Never write `Ask: "Are you sure? (yes/no)"` or `[y/n]` or `Wait for user to type yes` in a SKILL.md. The CI audit rejects these patterns.

Exception: consent trigger phrases per `lib/consent.md` (e.g. "make the ticket") are user-initiated and don't need a preceding question.

### Naming normalization

Any user-provided or detected name destined for a folder/repo/slug must be normalized per `lib/naming.md`:

1. Lowercase
2. Replace any character not in `[a-z0-9-]` with `-`
3. Collapse consecutive `-`
4. Strip leading/trailing `-`
5. Truncate to 100 chars
6. Reject if empty after step 4

Show the normalized form to the user in structured prompts before committing.

### Token references

- **Substitution tokens** use `{TOKEN}` syntax (uppercase inside curly braces). Example: `{PROJECT}.cc/`, `{COMPANY}`, `{SPACE_KEY}`.
- **No angle-bracket placeholders.** Placeholders written as a word wrapped in `<` and `>` trip the plugin upload scanner (it treats them as unknown HTML tags). The project name written that way is the most common offender - always use `{PROJECT}` instead.

### Lib references

Cite libs with plugin-relative paths: `` `lib/credentials.md` ``. Not `` `core/lib/credentials.md` ``. Each plugin is self-contained and carries its own copies of the libs it uses.

When adding a new lib doc, copy it into every plugin that cites it. Yes, this duplicates content - that's the tradeoff for plugin self-containment.

### Forbidden vocabulary

These patterns trigger the plugin upload scanner and reject the upload:
- `inject` / `injection` / `injected` (use `apply` / `embed`)
- `paste secret` / `paste your secret` (use `provide a configuration value`)
- Specific API-key brand names like `stripe`, `aws`, in example text (use generic `{provider}`)

### Agents

When a skill has substantial iteration or context-heavy work, factor a subagent into `agents/{name}.md`. Each agent declares its `tools` list and stays in its lane. Cite the agent from its consuming skill's References block.

Agents in the marketplace as of this writing:
- `runesmith-cc/agents/repo-bootstrapper.md`
- `runesmith-confluence/agents/page-publisher.md`
- `runesmith-sprint/agents/comms-triager.md`
- `runesmith-aiops/agents/template-applier.md`
- `runesmith-devtools/agents/workspace-scanner.md`

### Commands

Every skill should have a matching `commands/{name}.md` file so explicit `/plugin:skill` invocation works as a first-class entry point alongside auto-invoke by description match.

### CI

The `.github/workflows/build.yml` workflow runs on every push and PR:
- Validates `marketplace.json` and every `plugin.json` schema
- Validates every `SKILL.md` frontmatter
- Builds `.plugin` zips and verifies each contains `plugin.json` at the correct path
- Uploads `.plugin` artifacts (30-day retention)

PRs that fail CI are blocked from merge.

## Code of conduct

Be respectful in issues and PRs. Constructive disagreement is fine; personal attacks are not.

## License

By contributing, you agree your contributions are licensed under Apache-2.0.
