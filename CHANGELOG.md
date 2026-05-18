# Changelog

All notable changes to the RuneSmith marketplace are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Rename note**: this marketplace was previously named "Claude Forge". Renamed to **RuneSmith** in v0.6.0 to avoid trademark confusion with Anthropic's "Claude" mark and conflict with Atlassian's "Forge" developer platform. Historical changelog entries below have been mechanically updated to reference plugins by their new names (`runesmith-*`) for consistency; the substance of past releases is unchanged.

## [0.7.0] — 2026-05-17

### Added
- **`runesmith-cc:guardrail` skill.** Two-layer project-boundary enforcement for Claude Code sessions. Layer 1 (behavioral) — two new refusal rules in the `agent-operating-principles.md` source, propagated into the `<!-- agent-ops:start/end -->` marker block of every workspace + CC-head CLAUDE.md by `reallocate` and `bootstrap-cc`: a cross-project refusal rule and a credentials-class refusal rule (`*credentials*`, `*.env`, `id_rsa*`, `*.key`, `*.pem`). Layer 2 (harness enforcement) — user-level `~/.claude/settings.json` block with `defaultMode: "dontAsk"`, project-relative `Read(/**)`/`Edit(/**)`/`Write(/**)` allow rules, categorical secret/exfil denies, plus a `PreToolUse` hook (`enforce-project-boundary.sh` + PowerShell shim) for Bash subprocess containment. Install / uninstall / verify each gated by structured-prompt consent. Marker-bounded JSON-aware merge so user-managed keys in `settings.json` survive uninstall.
- **`runesmith-cc:bootstrap-cc` extension.** Now writes project-level `<project>/.claude/settings.json` (with `additionalDirectories: []` escape hatch) and `<project>/.claude/README.md` (boundary explanation). Surfaces a clear next-step nudge if the user-level guardrail isn't installed yet.
- **`/runesmith-cc:guardrail` slash command** wrapping the new skill.

### Driver — 2026-05-17 incident
A Cowork session in another workspace dispatched Claude Code, which read `.credentials` from a sibling project and echoed plaintext keys into the transcript before the misdirection was caught. The behavioral boundary in CLAUDE.md was the only catch and almost failed. Verification spike (`plans/active/cc-project-boundary/refs/2026-05-17-hook-contract-findings.md`) found that the handoff's hook contract draft was wrong and that Claude Code's `dontAsk` permission mode + project-relative `/path` anchor make most of the file-access boundary achievable via permission rules alone. The hook is now a narrow Bash-and-subagent backstop, not the primary enforcement.

### Known residual risks (documented, not solved)
- Subagents launched via Task tool do NOT inherit PreToolUse hooks or permission rules (platform bugs #27661, #23983). Layer 1 advisory rules are the only protection inside a subagent.
- Bash on Windows is unsandboxed; PowerShell pipes, indirect invocation, and shell escaping can evade the substring matchers. Hook is best-effort against accidents, not airtight against adversarial Bash.
- MCP tool calls are not boundary-aware. Follow-up plan (MCP scoping) to be tracked separately.

### Notes
- Marketplace version bump 0.6.0 → 0.7.0. `runesmith-cc` plugin version bump 0.6.0 → 0.7.0. Other plugins unchanged.
- Upgrade path: re-run `/runesmith-cc:bootstrap-cc` in existing workspaces to refresh CLAUDE.md and write project-level settings. Run `/runesmith-cc:guardrail install` once per machine. Pre-existing CC sessions are unprotected until both steps complete.

## [0.6.0] — 2026-05-11

### Changed (breaking — rename)
- **Marketplace renamed**: `claude-forge` → `runesmith`. All 8 plugin folders renamed: `claude-forge-{core,workspace,cc,jira,confluence,sprint,aiops,devtools}` → `runesmith-{core,workspace,cc,jira,confluence,sprint,aiops,devtools}`.
- **GitHub repos renamed**: `runemarklabs/claude-forge` → `runemarklabs/runesmith` (public marketplace); `runemarklabs/claude-forge-dev` → `runemarklabs/runesmith-dev` (private dev).
- **Slash commands renamed**: every `/claude-forge-{plugin}:{skill}` → `/runesmith-{plugin}:{skill}`. Users with the old plugins installed must uninstall and reinstall the new versions.
- **Marker tokens renamed**: `<!-- claude-forge:atlassian-start/end -->` (and any future feature markers) → `<!-- runesmith:atlassian-start/end -->`. Workspaces with the old markers in their Project Instructions or CLAUDE.md will need to update the marker names manually (or re-run `/runesmith-sprint:enable` if atlassian-enabled — it'll re-emit the supplement with the new markers).
- **Marketplace install path**: `/plugin marketplace add runemarklabs/runesmith` (was `runemarklabs/claude-forge`).

### Notes
- No functional skill changes in this release. Everything from v0.5.1 is preserved verbatim under new names.
- Skill content was rewritten only to the extent of swapping the old plugin name references. No behavior change.
- The "Forge" naming family (used by Atlassian's developer platform AND by several AI tool projects) was abandoned to avoid namespace collision and trademark exposure. "RuneSmith" carries the brand DNA of Runemark Labs (the maintainer) and is namespace-clean in the AI dev tooling space.

## [0.5.1] — 2026-05-11

### Added
- **Project Instructions awareness.** `runesmith-workspace:reallocate` now emits proposed Cowork Project Instructions text in its final report. The UI Project Instructions field is invisible to the agent and only editable in Cowork's app UI — the skill produces text for the user to paste. Base emission is behavioral only (no file paths, no plugin counts, no version numbers — those live in `CLAUDE.md`).
- **Atlassian supplement separation.** `runesmith-sprint:enable` emits an Atlassian Project Instructions supplement wrapped in `<!-- runesmith:atlassian-start/end -->` markers, for the user to append to their existing Project Instructions. `runesmith-sprint:disable` emits removal instructions for the same marker range. Reallocate's base emission carries no Atlassian content — each skill owns its supplement.
- **`runesmith-workspace/lib/project-instructions.md`** documenting the two-tier project context model (CLAUDE.md = structural, Project Instructions = behavioral) and the canonical template.
- **Structured-prompt enforcement** strengthened in `runesmith-workspace:reallocate` step 5 and in all `agent-operating-principles.md` copies: "Should I proceed?" in chat is explicitly a protocol violation, not a stylistic preference. Consent gates must use `AskUserQuestion` (or equivalent host tool); load via `ToolSearch` if not present in the session.

### Removed
- `scripts/release.sh` and `PUBLIC.manifest.txt` — defunct workspace/repo split era. The repo IS the marketplace; no separate public release step needed.
- Legacy `dist/{aiops,atlassian,core,devtools}.plugin` — pre-rename artifacts from v0.3.0.
- Redundant `cc-skill-templates/<name>/SKILL.md` files (5 total: 1 in cc, 4 in sprint). These were leftovers from the rename to `skill-template.md` (and `.txt` in the dist zip). Source now matches deploy reality.

### Fixed
- 4 truncated slash-command descriptions (`bootstrap-cc.md`, `check-comms.md`, `enable.md`, `disable.md`, `reallocate.md`) — mid-sentence truncations at placeholder boundaries caused Cowork to silently skip slash-command registration. Audit now catches these via `check_command_descriptions`.
- 2 angle-bracket `<word>` placeholders in SKILL.md frontmatter descriptions (`bootstrap-cc`, `plan-to-tickets`) — Cowork's upload validator rejects them. Replaced with `{WORD}`. Audit now catches these via `check_frontmatter_placeholders`.
- Internal `<name>.cc/` references in `naming.md` and `CLAUDE.parent.md` template normalized to `{PROJECT}.cc/`.

### Notes
- Workspace plugin's structural assumption clarified: marketplace dev workspaces are no different from any other workspace. The marketplace source lives inside the CC head repo (`runesmith.cc/runesmith/`), not at workspace root. The skill no longer treats marketplace-shaped content at workspace root as canonical to keep.

## [0.5.0] — 2026-05-10

### Changed (breaking — folder layout)
- **Tickets now live under their plan.** Jira ticket JSON drafts moved from a workspace-root `tickets/` directory to `plans/active/<slug>/tickets/<KEY>.json`. After push to Jira, drafts archive to `archive/tickets-pushed/<YYYY-MM>/<KEY>.json` for history. Workspaces upgrading from 0.4.0 must move any existing `tickets/<KEY>.json` files under the relevant plan or to `archive/superseded/<YYYY-MM>/tickets-orphan/`.
- **`research/` and `source-docs/` are canonical** — no longer treated as "legacy" by reallocate. `research/<topic>/` holds standalone analysis (migrates to a plan's `refs/` once adopted); `source-docs/<topic>/` holds external uploads being processed.
- **`archive/superseded/<YYYY-MM>/`** added as the canonical home for consumed / "don't look again" content. `archive/` is no longer reserved for operation snapshots only.
- **Root keep-list enforced.** `reallocate` now treats any root file not on the keep-list as an inbox-item. Loose `.md`, `.json`, and image files at root are routed instead of preserved. Marketplace standard files, workspace config, and canonical dirs are the only permitted root entries.
- **`_INBOX/` is no longer a parking spot for legacy content.** `reallocate` never auto-parks files in `_INBOX/`; it routes directly per the destination map when the home is unambiguous and prompts only when ambiguous.
- **Plan directory shape** now includes `tickets/` alongside `plan.md`, `decisions.md`, and `refs/`. Archived plans (`plans/archive/<YYYY-MM>/<slug>/`) carry their `refs/` and any remaining unpushed `tickets/` with them.

### Added
- **`runesmith-workspace/lib/folder-conventions.md`** — single source of truth for the canonical workspace layout, root keep-list, destination map, and lifecycle rules. Copied into `runesmith-sprint/lib/` and `runesmith-devtools/lib/` per the self-contained plugin rule.
- **`runesmith-workspace/lib/claude-md-section.md`** — marker-bounded section template (`<!-- folder-conventions:start/end -->`) that `reallocate` writes into the workspace's root `CLAUDE.md` so future sessions stay coherent across the canonical structure.
- **`runesmith-workspace/lib/STRUCTURE.template.md`** — moved from workspace root into the plugin. `reallocate` reads from here and writes `STRUCTURE.md` to the workspace root.
- New inbox categories: `handoff`, `research`, `source-doc`, `image`, `superseded` — each with a canonical destination.
- `runesmith-sprint:plan-to-tickets` now persists ticket drafts to `plans/active/<slug>/tickets/<DRAFT-ID>.json` BEFORE push (survives across sessions, reviewable on disk) and archives pushed drafts to `archive/tickets-pushed/<YYYY-MM>/<JIRA-KEY>.json`.
- **`runesmith-cc/cc-skill-templates/code-tech-debt/SKILL.md`** — new CC-side skill template for repo-level dead-code / unused-export / unused-dep scanning. Deployed by `bootstrap-cc` into `{PROJECT}.cc/.claude/skills/code-tech-debt/` so the skill is callable from CC via slash command. Per-language analyzers (TS, JS/Node, React, Next.js, Python in v1) governed by an extensible registry.
- **`runesmith-cc/lib/code-analyzers.md`** — per-language analyzer registry (detection signal, preferred tool, fallback heuristic, findings categories, cross-reference checks). Extensible by adding new language entries; the skill reads from the registry without code change.
- **Agent operating principles baked into every Forge-bootstrapped workspace.** Standard operating knowledge (sandbox-vs-real-fs distinction, file-ops as agent territory, destructive-op gates, structured prompts) now ships as a marker-bounded section (`<!-- agent-ops:start/end -->`) written into both the workspace root `CLAUDE.md` (by `reallocate`) and the CC head `CLAUDE.md` (by `bootstrap-cc`). Idempotent — re-runs refresh content between markers, user additions outside markers preserved. Source: `runesmith-workspace/lib/agent-operating-principles.md` (copied into `runesmith-cc/lib/` per the self-contained plugin rule). New marker template: `runesmith-workspace/lib/claude-md-agent-ops-section.md`.

### Removed
- **`/runesmith-devtools:verify-separation`** — retired. The workspace/repo boundary is enforced by the canonical structure (`{PROJECT}.cc/` contains source repos; everything else is workspace) and by forking as the customization path. The skill's check logic predated the plugin model and referenced a `.claude/skills/` workspace pattern that no longer exists.

### Fixed
- `runesmith-workspace:reallocate` no longer auto-routes `research/`, `source-docs/`, or loose root markdown into `_INBOX/`. The skill previously inherited stale assumptions from pre-plugin-era `cowork-bootstrap` config.
- `runesmith-workspace:reallocate` now has an explicit hard boundary at `{PROJECT}.cc/<repo>/`. Repo internals are CC's territory; reallocate moves repos as whole units when migrating and stops at the boundary.
- `runesmith-devtools:tech-debt` rewritten around a cross-reference graph (plans → refs/tickets/decisions → research/source-docs/drafts) rather than age heuristics. Identifies what is ACTUALLY tech debt (unreferenced from any live plan or recent note), not just what is old. On-the-fly graph by default; structured option for cached mode on heavy workspaces.
- All 4 copies of `lib/plan-format.md` (workspace, sprint, confluence, core) now agree on the per-plan directory shape and the post-push ticket archive path.

### Upgrade notes
Re-install plugins or run `/runesmith-core:sync` to pick up 0.5.0. Then run `/runesmith-workspace:reallocate` in any existing workspace to normalize to the new layout (snapshots first). If a `tickets/` directory exists at workspace root, reallocate will prompt for each JSON: which plan does it belong to, or archive to `archive/superseded/<YYYY-MM>/tickets-orphan/`.

### Known issues (tracked, not blocking ship)
- 73 files across plugins still reference the pre-rename plugin shorthand (`core:`, `atlassian:`, etc.) in documentation prose. Functional impact: none — slash commands use the full `runesmith-*` names. Documentation sweep is a follow-up.
- `plugins/runesmith-devtools/commands/verify-separation.md` exists as a tombstone (dev sandbox could not dele