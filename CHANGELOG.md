# Changelog

All notable changes to the RuneSmith marketplace are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Rename note**: this marketplace was previously named "Claude Forge". Renamed to **RuneSmith** in v0.6.0 to avoid trademark confusion with Anthropic's "Claude" mark and conflict with Atlassian's "Forge" developer platform. Historical changelog entries below have been mechanically updated to reference plugins by their new names (`runesmith-*`) for consistency; the substance of past releases is unchanged.

## [0.7.2] - 2026-05-17 → superseded by 0.7.3

(See 0.7.3 below - format conversion alone was not the fix.)

## [0.8.3] - 2026-05-27

### Added (runesmith-cc)
- **Comms hygiene rule** in the CC head agent-ops marker block: every reply comm starts with an explicit `STATUS:` line (`complete` / `partial` / `blocked` / `failed`) before any prose. Pairs partial/blocked/failed with a context line (`Why partial:`, `Blocker:`, `Error:`).
- **End-of-task terminal banner** rule: every CC task ends with a high-visibility ANSI-colored terminal banner as the LAST thing printed, only after the reply comm is written AND comms are archived. Color matches the STATUS value (green/yellow/red). Banner visible = task done at both file level and terminal level. No banner = keep working.
- Both rules in lib/agent-operating-principles.md (CC-side rationale) and bootstrap-cc/templates/CLAUDE.parent.md (deployed marker block).

### Why
On 2026-05-26 a Resume Unbound CC session finished all the functional work of a domain swap but never wrote the reply comm or archived the task files. From the terminal view it was indistinguishable from "still working." File-level STATUS line + terminal-level banner together give two-channel certainty about task state.

### Versions
- runesmith-cc 0.8.0 -> 0.8.1 (or claude-forge-cc for Sapient)
- Marketplace metadata.version unchanged at 0.8.2 (devtools is still the highest)
- Other plugins unchanged

## [0.8.2] - 2026-05-19

### Added (devtools)
- **`lib/release-maintenance.md`** - new HARD-RULES lib file covering per-plugin versioning (no blanket bumps), `[MarketplaceName vX.Y.Z]` description prefix, marketplace.metadata.version max tracking, CHANGELOG-only-what-moved, and the per-bump checklist. Referenced from plugin-builder SKILL.md so the rules surface at scaffold time, not just during ongoing maintenance.

### Why
The per-plugin versioning rule was documented in lib/build-and-audit.md (added v0.8.1) but needed a dedicated lib file with a self-contained restatement. Extracting it into release-maintenance.md makes it easier to cite from plugin-builder's References block and from CHANGELOG entries for future bumps.

### Versions
- runesmith-devtools 0.8.1 -> 0.8.2
- Marketplace 0.8.1 -> 0.8.2
- Other plugins unchanged

## [0.8.1] - 2026-05-19

### Added (runesmith-workspace)
- **PROJECT mission inference in reallocate.** Step 12 now scans workspace signal (`README.md` at root → `source-docs/*.md` → prior `CLAUDE.md` content outside markers → package manifest description) and drafts a 1-3 sentence PROJECT mission. Surfaces via structured prompt with Accept / Edit / Skip options. Falls back to the static `{Fill in: ...}` placeholder only when no signal hits OR the user picks Skip. Documented in new `lib/project-mission-inference.md`.

### Why
Reallocate previously emitted the same fill-in placeholder on every re-run, forcing the user to retype their project's mission every time, even when the workspace already had clear signal in README and source-docs. Reported on Resume Unbound 2026-05-19. Now the skill reads the signal it could already see and proposes the draft.

### Notes
- ROLE / RULES / HOW WE WORK sections still emit verbatim from template. Inference is PROJECT-only; ROLE is the canonical Cowork pair-programming role.
- Inference is read-only: no edits land without the user accepting the draft via structured prompt.
- `plans/active/*/plan.md` and `tickets/*` are explicitly excluded as signal sources (too narrow - they describe current work, not project mission).

### Added (devtools)
- **Plugin-builder skill rewrite.** Now reads four new lib files (`plugin-json-schema.md`, `skill-md-frontmatter.md`, `cowork-hard-rules.md`, `build-and-audit.md`) before generating any plugin content. Skills built from this point pass audit out of the box and dispatch reliably under Cowork. Captures the production-tested conventions from RuneSmith v0.7-v0.8 development.

### Fixed (audit)
- **JSON unicode em-dash escape detection.** New `check_no_emdash_json_escapes()` decodes JSON strings before scanning, catching U+2014 / U+2013 escapes the byte-level audit misses. Cowork JSON-parses files at load time so these escapes render as em-dash to users; audit now flags them.
- **Em-dash escape sweep across 16 plugin.json files + 2 marketplace.json files.** Replaced all U+2014 escapes with literal ASCII hyphen.

### Fixed (docs + cleanup)
- **`docs/howto/install-guardrail.md` rewritten** for the v0.8.x one-shot installer flow. Previous version taught the retired v0.7 CC-side install path.
- **Pruned dead reference** to `cc-skill-templates/guardrail/skill-template.md` in `runesmith-cc:guardrail` SKILL.md (path removed in v0.8.0).
- **README.md `cc-skill-templates/` claim** updated in both repos to reflect what the build script actually does today.
- **Sapient mirror installer scripts** rebranded JSON marker tokens from `_runesmith_guardrail_*` to `_claude_forge_guardrail_*` with legacy-key migration to preserve idempotence.
- **Sapient mirror `scripts/audit.py`** docstring rebranded to Claude Forge.
- **Sapient mirror README.md** restored truncated Contributing + License sections.

### Versions
- `runesmith-workspace` 0.8.0 → 0.8.1
- `runesmith-devtools` 0.8.0 → 0.8.1
- Marketplace 0.8.0 → 0.8.1
- Other plugins unchanged at 0.8.0

## [0.8.0] - 2026-05-18

### Changed (breaking - guardrail install path)
- **Guardrail install is now one-shot.** `/runesmith-cc:guardrail` in Cowork copies a self-contained installer (`install-guardrail.ps1` on Windows, `install-guardrail.sh` on macOS/Linux) to the workspace root. The user runs it once. The installer detects environment (Git Bash + jq on Windows, jq on Unix), writes user-level `~/.claude/settings.json` permission block + hook scripts, runs synthetic verification, reports. Single command replaces the previous multi-step manual sequence.
- **CC-side guardrail skill retired.** The previous design deployed an install skill into `{PROJECT}.cc/<repo>/.claude/skills/guardrail/` via bootstrap-cc, with the user running `/guardrail install` from inside CC. This failed because CC's own permission system blocks writes to `~/.claude/` from a CC session (the boundary it doesn't yet have, blocking its own install - chicken-and-egg). The CC-side template at `cc-skill-templates/guardrail/` is removed in this release.
- **`bootstrap-cc` no longer deploys the guardrail.** Updated to remove the four file-table entries that previously deployed the install skill + templates into each CC head.

### Why
v0.7.x shipped the guardrail with a CC-side install path. In real use, that path failed: CC's permission boundary blocked the install of its own boundary. Users hit a "manual install fallback" wall - print PowerShell commands, copy-paste into terminal, manage Git Bash / jq / settings.json merge by hand. Long marathon for what should be one command. v0.8.0 collapses it to one command: copy installer to workspace, run, done.

### Versions
- All 8 plugin.json bumped to 0.8.0.
- Marketplace 0.8.0.

### Upgrade path
- Existing workspaces with a deployed CC-side guardrail skill (in `{PROJECT}.cc/<repo>/.claude/skills/guardrail/`) can leave those files in place; they're now vestigial but harmless. Re-running `/runesmith-cc:bootstrap-cc` will NOT redeploy them.
- To install the guardrail, run `/runesmith-cc:guardrail` in Cowork - it copies the installer to workspace root. Then run `.\install-guardrail.ps1` (or `./install-guardrail.sh`) in PowerShell / Terminal.

## [0.7.3] - 2026-05-17

### Fixed
- **Plugin.json minimum-fields convention.** Cowork's plugin loader / Skill-tool dispatcher appears to silently reject (for dispatch purposes) plugins whose `plugin.json` includes fields beyond the minimum set the official Anthropic plugins use. Working comparators (e.g. `cowork-plugin-management` v0.2.2) carry only `name`, `version`, `description`, `author`. Stripped `license`, `repository`, `homepage`, `keywords` from all 8 plugin.json files. (`dependencies` was already stripped in 0.7.0+.)
- **`compatibility` field added to every SKILL.md.** The working `cowork-plugin-customizer` skill declares a `compatibility:` line in its frontmatter; ours did not. Added `compatibility: Requires Cowork desktop app environment.` to all 36 SKILL.md and `cc-skill-templates/*/skill-template.md` files.

### Open verification
- The 0.7.2 YAML format conversion (folded scalar → single-line quoted) was a red herring - the working `cowork-plugin-customizer` uses the folded scalar form too. Format remains single-line quoted in this release; no plan to revert.
- Whether the plugin.json strip + `compatibility:` addition fixes Skill-tool dispatch is the open verification gate. Test by invoking `/runesmith-workspace:reallocate` from any RuneSmith-bootstrapped workspace after reinstalling 0.7.3.

### Versions
- All 8 plugin.json bumped to 0.7.3.
- Marketplace 0.7.3.

## [0.7.2-original] - 2026-05-17

### Fixed
- **Skill description format.** Cowork's Skill-tool dispatcher silently rejected skills whose `SKILL.md` frontmatter used YAML's `description: >` folded block scalar (multi-line indented). Anthropic's own skills (docx, pdf, pptx, xlsx, executive-assistant, skill-creator, etc.) use `description: "single-line"` quoted strings. Converted all 36 skill files (SKILL.md + cc-skill-templates/*/skill-template.md) to the canonical single-line quoted format. Same content; just the YAML serialization differs. Resolves the long-running "skill not callable via Skill tool" pattern that hit guardrail, reallocate, and likely others - agents were falling back to reading SKILL.md directly off disk for those skills instead of dispatching via the tool API. Should also fix slash-command invocation that previously sometimes silently no-op'd.

### Versions
- All eight plugin.json files bumped 0.7.1 → 0.7.2 (or 0.6.0 → 0.7.2 for the six that hadn't moved with the cc/workspace bumps).
- Marketplace 0.7.1 → 0.7.2.

### Notes
- Conversion script preserved `model: haiku` and other top-level frontmatter keys. Audit verified clean YAML across all SKILL.md after.
- No behavior change beyond Skill-tool dispatch working correctly. Existing fallback "read SKILL.md directly" still works as a safety net.

## [0.7.1] - 2026-05-17

### Fixed
- **Guardrail install path.** v0.7.0 shipped the guardrail install logic as a Cowork-side skill, but Cowork's sandbox can't write to `~/.claude/` (user-home, outside the mounted workspace). Install attempts from Cowork silently failed. Refactored: install logic moved to a CC-side skill template at `cc-skill-templates/guardrail/`, deployed by `bootstrap-cc` into `{PROJECT}.cc/.claude/skills/guardrail/`. Users now run `/guardrail install` from inside Claude Code (which has terminal access and can write user-home files). The Cowork-side `/runesmith-cc:guardrail` skill is preserved as a walkthrough/pointer that explains the design and surfaces the CC-side commands with paths substituted for the host's OS.
- **Plugin authority principle added.** New rule in `agent-operating-principles.md`: the installed plugin is authoritative, source repos are dev-only, agents NEVER reach into a sibling project workspace to read plugin source. Fixes the 2026-05-18 Mix Tape session pattern where an agent asked to "follow the plugin guidelines" tried to read RuneSmith's source folder. The cross-project boundary caught it at the consent gate, but the underlying agent instinct was the bug. New principle makes that instinct explicit. Propagates to every workspace + CC head on next `/runesmith-workspace:reallocate` and `/runesmith-cc:bootstrap-cc` run (marker-bounded section refresh).
- **Docs updated.** `docs/howto/install-guardrail.md` rewritten to reflect the new install path. `docs/AGENT_PRIMER.md` and `INSTALL.md` updated with the CC-side invocation. Cowork-side and CC-side roles called out explicitly so future maintainers don't repeat the design error.

### Versions
- `runesmith-workspace` bumped 0.6.0 → 0.7.1 (carries the new agent-operating-principles content + marker template).
- `runesmith-cc` stays 0.7.1 (refactored in this release).
- Marketplace stays 0.7.1.

### Notes
- Marker key (`_runesmith_guardrail_marker`) is stable across forks for clean uninstall regardless of marketplace branding.
- Pre-existing CC sessions still need a restart for the new permissions to take effect after install.

## [0.7.0] - 2026-05-17

### Added
- **`runesmith-cc:guardrail` skill.** Two-layer project-boundary enforcement for Claude Code sessions. Layer 1 (behavioral) - two new refusal rules in the `agent-operating-principles.md` source, propagated into the `<!-- agent-ops:start/end -->` marker block of every workspace + CC-head CLAUDE.md by `reallocate` and `bootstrap-cc`: a cross-project refusal rule and a credentials-class refusal rule (`*credentials*`, `*.env`, `id_rsa*`, `*.key`, `*.pem`). Layer 2 (harness enforcement) - user-level `~/.claude/settings.json` block with `defaultMode: "dontAsk"`, project-relative `Read(/**)`/`Edit(/**)`/`Write(/**)` allow rules, categorical secret/exfil denies, plus a `PreToolUse` hook (`enforce-project-boundary.sh` + PowerShell shim) for Bash subprocess containment. Install / uninstall / verify each gated by structured-prompt consent. Marker-bounded JSON-aware merge so user-managed keys in `settings.json` survive uninstall.
- **`runesmith-cc:bootstrap-cc` extension.** Now writes project-level `<project>/.claude/settings.json` (with `additionalDirectories: []` escape hatch) and `<project>/.claude/README.md` (boundary explanation). Surfaces a clear next-step nudge if the user-level guardrail isn't installed yet.
- **`/runesmith-cc:guardrail` slash command** wrapping the new skill.

### Driver - 2026-05-17 incident
A Cowork session in another workspace dispatched Claude Code, which read `.credentials` from a sibling project and echoed plaintext keys into the transcript before the misdirection was caught. The behavioral boundary in CLAUDE.md was the only catch and almost failed. Verification spike (`plans/active/cc-project-boundary/refs/2026-05-17-hook-contract-findings.md`) found that the handoff's hook contract draft was wrong and that Claude Code's `dontAsk` permission mode + project-relative `/path` anchor make most of the file-access boundary achievable via permission rules alone. The hook is now a narrow Bash-and-subagent backstop, not the primary enforcement.

### Known residual risks (documented, not solved)
- Subagents launched via Task tool do NOT inherit PreToolUse hooks or permission rules (platform bugs #27661, #23983). Layer 1 advisory rules are the only protection inside a subagent.
- Bash on Windows is unsandboxed; PowerShell pipes, indirect invocation, and shell escaping can evade the substring matchers. Hook is best-effort against accidents, not airtight against adversarial Bash.
- MCP tool calls are not boundary-aware. Follow-up plan (MCP scoping) to be tracked separately.

### Notes
- Marketplace version bump 0.6.0 → 0.7.0. `runesmith-cc` plugin version bump 0.6.0 → 0.7.0. Other plugins unchanged.
- Upgrade path: re-run `/runesmith-cc:bootstrap-cc` in existing workspaces to refresh CLAUDE.md and write project-level settings. Run `/runesmith-cc:guardrail install` once per machine. Pre-existing CC sessions are unprotected until both steps complete.

## [0.6.0] - 2026-05-11

### Changed (breaking - rename)
- **Marketplace renamed**: `claude-forge` → `runesmith`. All 8 plugin folders renamed: `claude-forge-{core,workspace,cc,jira,confluence,sprint,aiops,devtools}` → `runesmith-{core,workspace,cc,jira,confluence,sprint,aiops,devtools}`.
- **GitHub repos renamed**: `runemarklabs/claude-forge` → `runemarklabs/runesmith` (public marketplace); `runemarklabs/claude-forge-dev` → `runemarklabs/runesmith-dev` (private dev).
- **Slash commands renamed**: every `/claude-forge-{plugin}:{skill}` → `/runesmith-{plugin}:{skill}`. Users with the old plugins installed must uninstall and reinstall the new versions.
- **Marker tokens renamed**: `<!-- claude-forge:atlassian-start/end -->` (and any future feature markers) → `<!-- runesmith:atlassian-start/end -->`. Workspaces with the old markers in their Project Instructions or CLAUDE.md will need to update the marker names manually (or re-run `/runesmith-sprint:enable` if atlassian-enabled - it'll re-emit the supplement with the new markers).
- **Marketplace install path**: `/plugin marketplace add runemarklabs/runesmith` (was `runemarklabs/claude-forge`).

### Notes
- No functional skill changes in this release. Everything from v0.5.1 is preserved verbatim under new names.
- Skill content was rewritten only to the extent of swapping the old plugin name references. No behavior change.
- The "Forge" naming family (used by Atlassian's developer platform AND by several AI tool projects) was abandoned to avoid namespace collision and trademark exposure. "RuneSmith" carries the brand DNA of Runemark Labs (the maintainer) and is namespace-clean in the AI dev tooling space.

## [0.5.1] - 2026-05-11

### Added
- **Project Instructions awareness.** `runesmith-workspace:reallocate` now emits proposed Cowork Project Instructions text in its final report. The UI Project Instructions field is invisible to the agent and only editable in Cowork's app UI - the skill produces text for the user to paste. Base emission is behavioral only (no file paths, no plugin counts, no version numbers - those live in `CLAUDE.md`).
- **Atlassian supplement separation.** `runesmith-sprint:enable` emits an Atlassian Project Instructions supplement wrapped in `<!-- runesmith:atlassian-start/end -->` markers, for the user to append to their existing Project Instructions. `runesmith-sprint:disable` emits removal instructions for the same marker range. Reallocate's base emission carries no Atlassian content - each skill owns its supplement.
- **`runesmith-workspace/lib/project-instructions.md`** documenting the two-tier project context model (CLAUDE.md = structural, Project Instructions = behavioral) and the canonical template.
- **Structured-prompt enforcement** strengthened in `runesmith-workspace:reallocate` step 5 and in all `agent-operating-principles.md` copies: "Should I proceed?" in chat is explicitly a protocol violation, not a stylistic preference. Consent gates must use `AskUserQuestion` (or equivalent host tool); load via `ToolSearch` if not present in the session.

### Removed
- `scripts/release.sh` and `PUBLIC.manifest.txt` - defunct workspace/repo split era. The repo IS the marketplace; no separate public release step needed.
- Legacy `dist/{aiops,atlassian,core,devtools}.plugin` - pre-rename artifacts from v0.3.0.
- Redundant `cc-skill-templates/<name>/SKILL.md` files (5 total: 1 in cc, 4 in sprint). These were leftovers from the rename to `skill-template.md` (and `.txt` in the dist zip). Source now matches deploy reality.

### Fixed
- 4 truncated slash-command descriptions (`bootstrap-cc.md`, `check-comms.md`, `enable.md`, `disable.md`, `reallocate.md`) - mid-sentence truncations at placeholder boundaries caused Cowork to silently skip slash-command registration. Audit now catches these via `check_command_descriptions`.
- 2 angle-bracket `<word>` placeholders in SKILL.md frontmatter descriptions (`bootstrap-cc`, `plan-to-tickets`) - Cowork's upload validator rejects them. Replaced with `{WORD}`. Audit now catches these via `check_frontmatter_placeholders`.
- Internal `<name>.cc/` references in `naming.md` and `CLAUDE.parent.md` template normalized to `{PROJECT}.cc/`.

### Notes
- Workspace plugin's structural assumption clarified: marketplace dev workspaces are no different from any other workspace. The marketplace source lives inside the CC head repo (`runesmith.cc/runesmith/`), not at workspace root. The skill no longer treats marketplace-shaped content at workspace root as canonical to keep.

## [0.5.0] - 2026-05-10

### Changed (breaking - folder layout)
- **Tickets now live under their plan.** Jira ticket JSON drafts moved from a workspace-root `tickets/` directory to `plans/active/<slug>/tickets/<KEY>.json`. After push to Jira, drafts archive to `archive/tickets-pushed/<YYYY-MM>/<KEY>.json` for history. Workspaces upgrading from 0.4.0 must move any existing `tickets/<KEY>.json` files under the relevant plan or to `archive/superseded/<YYYY-MM>/tickets-orphan/`.
- **`research/` and `source-docs/` are canonical** - no longer treated as "legacy" by reallocate. `research/<topic>/` holds standalone analysis (migrates to a plan's `refs/` once adopted); `source-docs/<topic>/` holds external uploads being processed.
- **`archive/superseded/<YYYY-MM>/`** added as the canonical home for consumed / "don't look again" content. `archive/` is no longer reserved for operation snapshots only.
- **Root keep-list enforced.** `reallocate` now treats any root file not on the keep-list as an inbox-item. Loose `.md`, `.json`, and image files at root are routed instead of preserved. Marketplace standard files, workspace config, and canonical dirs are the only permitted root entries.
- **`_INBOX/` is no longer a parking spot for legacy content.** `reallocate` never auto-parks files in `_INBOX/`; it routes directly per the destination map when the home is unambiguous and prompts only when ambiguous.
- **Plan directory shape** now includes `tickets/` alongside `plan.md`, `decisions.md`, and `refs/`. Archived plans (`plans/archive/<YYYY-MM>/<slug>/`) carry their `refs/` and any remaining unpushed `tickets/` with them.

### Added
- **`runesmith-workspace/lib/folder-conventions.md`** - single source of truth for the canonical workspace layout, root keep-list, destination map, and lifecycle rules. Copied into `runesmith-sprint/lib/` and `runesmith-devtools/lib/` per the self-contained plugin rule.
- **`runesmith-workspace/lib/claude-md-section.md`** - marker-bounded section template (`<!-- folder-conventions:start/end -->`) that `reallocate` writes into the workspace's root `CLAUDE.md` so future sessions stay coherent across the canonical structure.
- **`runesmith-workspace/lib/STRUCTURE.template.md`** - moved from workspace root into the plugin. `reallocate` reads from here and writes `STRUCTURE.md` to the workspace root.
- New inbox categories: `handoff`, `research`, `source-doc`, `image`, `superseded` - each with a canonical destination.
- `runesmith-sprint:plan-to-tickets` now persists ticket drafts to `plans/active/<slug>/tickets/<DRAFT-ID>.json` BEFORE push (survives across sessions, reviewable on disk) and archives pushed drafts to `archive/tickets-pushed/<YYYY-MM>/<JIRA-KEY>.json`.
- **`runesmith-cc/cc-skill-templates/code-tech-debt/SKILL.md`** - new CC-side skill template for repo-level dead-code / unused-export / unused-dep scanning. Deployed by `bootstrap-cc` into `{PROJECT}.cc/.claude/skills/code-tech-debt/` so the skill is callable from CC via slash command. Per-language analyzers (TS, JS/Node, React, Next.js, Python in v1) governed by an extensible registry.
- **`runesmith-cc/lib/code-analyzers.md`** - per-language analyzer registry (detection signal, preferred tool, fallback heuristic, findings categories, cross-reference checks). Extensible by adding new language entries; the skill reads from the registry without code change.
- **Agent operating principles baked into every Forge-bootstrapped workspace.** Standard operating knowledge (sandbox-vs-real-fs distinction, file-ops as agent territory, destructive-op gates, structured prompts) now ships as a marker-bounded section (`<!-- agent-ops:start/end -->`) written into both the workspace root `CLAUDE.md` (by `reallocate`) and the CC head `CLAUDE.md` (by `bootstrap-cc`). Idempotent - re-runs refresh content between markers, user additions outside markers preserved. Source: `runesmith-workspace/lib/agent-operating-principles.md` (copied into `runesmith-cc/lib/` per the self-contained plugin rule). New marker template: `runesmith-workspace/lib/claude-md-agent-ops-section.md`.

### Removed
- **`/runesmith-devtools:verify-separation`** - retired. The workspace/repo boundary is enforced by the canonical structure (`{PROJECT}.cc/` contains source repos; everything else is workspace) and by forking as the customization path. The skill's check logic predated the plugin model and referenced a `.claude/skills/` workspace pattern that no longer exists.

### Fixed
- `runesmith-workspace:reallocate` no longer auto-routes `research/`, `source-docs/`, or loose root markdown into `_INBOX/`. The skill previously inherited stale assumptions from pre-plugin-era `cowork-bootstrap` config.
- `runesmith-workspace:reallocate` now has an explicit hard boundary at `{PROJECT}.cc/<repo>/`. Repo internals are CC's territory; reallocate moves repos as whole units when migrating and stops at the boundary.
- `runesmith-devtools:tech-debt` rewritten around a cross-reference graph (plans → refs/tickets/decisions → research/source-docs/drafts) rather than age heuristics. Identifies what is ACTUALLY tech debt (unreferenced from any live plan or recent note), not just what is old. On-the-fly graph by default; structured option for cached mode on heavy workspaces.
- All 4 copies of `lib/plan-format.md` (workspace, sprint, confluence, core) now agree on the per-plan directory shape and the post-push ticket archive path.

### Upgrade notes
Re-install plugins or run `/runesmith-core:sync` to pick up 0.5.0. Then run `/runesmith-workspace:reallocate` in any existing workspace to normalize to the new layout (snapshots first). If a `tickets/` directory exists at workspace root, reallocate will prompt for each JSON: which plan does it belong to, or archive to `archive/superseded/<YYYY-MM>/tickets-orphan/`.

### Known issues (tracked, not blocking ship)
- 73 files across plugins still reference the pre-rename plugin shorthand (`core:`, `atlassian:`, etc.) in documentation prose. Functional impact: none - slash commands use the full `runesmith-*` names. Documentation sweep is a follow-up.
- `plugins/runesmith-devtools/commands/verify-separation.md` exists as a tombstone (dev sandbox could not dele