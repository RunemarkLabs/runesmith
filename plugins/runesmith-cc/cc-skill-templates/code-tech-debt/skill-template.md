---
name: runesmith-code-tech-debt
description: "Scan repos inside this CC head for code-level tech debt - unused exports, dead functions, orphaned files, unused dependencies, leftover scaffolding from refactors. Runs in Claude Code, scoped to the current repo. Use when the user says \"code tech debt\", \"dead code\", \"unused imports\", \"what can I remove from this repo\", or proactively after a refactor. Read-only by default; mutations require explicit consent."
compatibility: Runs in Claude Code, inside the project's head.
---

# Code Tech Debt (CC-side)

Scan repos in `{PROJECT}.cc/{repo}/` for unused code, dead exports, orphaned files, and stale dependencies. Per-language analyzers, extensible via the language registry in `@lib/code-analyzers.md`. Read-only by default - flags findings, proposes removals; user consent required for any deletion.

This skill is deployed to `{PROJECT}.cc/.claude/skills/code-tech-debt/SKILL.md` by `/runesmith-cc:head` running in Cowork. Do not edit it directly here unless you intend the change to flow to all future bootstraps.

## References

- `@lib/code-analyzers.md` - per-language analyzer registry (tools, heuristics, fallbacks). Source of truth for adding new language support.
- `.claude-code-workspace` (marker, in CC root) - for `repos[]` list (which repos to consider in scope)
- The repo's own config files (`package.json`, `pyproject.toml`, `tsconfig.json`, etc.) drive per-repo language detection

## Scope

This skill scans repos under `{PROJECT}.cc/{repo}/`. It does NOT touch:
- Workspace-level files outside the CC head
- `{PROJECT}.cc/comms/` (CC's exchange area)
- `{PROJECT}.cc/.claude/` (CC's own config and skills)
- `.git/` directories
- Any path under `node_modules/`, `__pycache__/`, `dist/`, `build/`, `.next/`, `target/`, etc. (build artifacts)

For workspace-level tech debt (orphaned plans, unreferenced drafts, stale research), use `/runesmith-devtools:tech-debt` on the Cowork side.

## When to Use

Use for:
- After a refactor - find leftover dead code
- Before a release - verify no orphaned files or unused deps
- Periodic hygiene per repo
- When file count seems too high vs. what's actually in use

Do not use for:
- Functional code review (use `/engineering:code-review` if available, or PR review tooling)
- Security scanning (use dedicated security tools)
- Workspace-level concerns (Cowork's tech-debt)

## Pre-Flight Checks

### 1. Repo target

If the user invokes without a target repo, list repos from `{PROJECT}.cc/.claude-code-workspace`'s `repos[]` array. Surface a structured single-pick for the user to choose. Default to the repo of the current working directory if running inside one.

### 2. Language detection

For the target repo, detect languages by:
- Presence of `package.json` → JavaScript / TypeScript / Node / React / Next.js (further refined below)
- Presence of `pyproject.toml`, `setup.py`, `requirements.txt`, or `.python-version` → Python
- Presence of `tsconfig.json` → TypeScript
- Presence of `next.config.{js,ts,mjs}` → Next.js
- `react` or `react-dom` in `package.json` dependencies → React
- File extensions across the tree (sample first 500 files)

If a language is detected but not in `@lib/code-analyzers.md`, surface "Language detected but no analyzer registered: {lang}. Skipping that scope." Do not fail the whole scan.

### 3. Tool availability

For each detected language, check whether its preferred analyzer is installed (per `@lib/code-analyzers.md`). If not installed:
- Note in the report which analyzer would be ideal
- Fall back to the grep/AST heuristics defined in the analyzer spec
- Never auto-install tools; surface as a recommendation for the user

## Workflow

### 1. Build the scan plan

For each detected language scope in the target repo:

| Scope | Findings categories |
|---|---|
| TypeScript / JavaScript | unused exports, unused imports, unreferenced files, unused dependencies, dead branches |
| React | unused components, unused props, unreachable component files |
| Next.js | unreferenced pages, unused API routes, unused layouts, unused middleware |
| Node.js | unused dependencies, unreachable scripts, orphaned config files |
| Python | unused functions/classes, unused imports, unreachable modules, unused dependencies |

Show the plan as a structured preview before scanning:
```
Code tech debt scan: {repo-name}
Languages: TypeScript (preferred: ts-prune), React, Next.js (heuristic)
Scopes:
  - {N} unused exports
  - {M} unused imports
  - {P} unreferenced files
  - {Q} unused dependencies
  - {R} unused components/props
```

### 2. Run analyzers

Per `@lib/code-analyzers.md`, invoke the configured analyzer for each scope. Capture raw output. If preferred tool missing, run the heuristic fallback (grep-based or AST-based as documented).

Cap walk depth and file count to keep runtime bounded. For very large repos, default to scanning the entry-point graph (from `package.json` `main` / `exports` or Next.js `app/`/`pages/`) and surface "Full-tree scan available with --deep" as an option.

### 3. Cross-reference within the repo

Many findings need confirmation that they're truly unused, not just unused at one analyzer's level:

- An "unused export" might be consumed via dynamic import / string-based require - grep for the name as a string before flagging.
- An "unreferenced file" might be referenced via a glob (e.g. Next.js `pages/`, route auto-discovery) - check framework conventions.
- An "unused dependency" might be runtime-imported via a config file or string template - grep the package name across the tree.

Findings that survive this cross-reference are high-confidence debt. Findings that don't are flagged as **likely-orphan** vs **confirmed-orphan**.

### 4. Group + propose

Surface findings grouped by category. For each, show the file path, line (where applicable), and proposed action:

```
Code tech debt: {repo-name}

Confirmed unused exports ({N})
  src/utils/legacy-format.ts:12   formatLegacy()   → delete export?
  src/hooks/useDeprecated.ts:8    useDeprecated()  → delete file?

Unused imports ({M})
  src/api/handler.ts:3   import { unused } from '...'   → remove line?
  ...

Unreferenced files ({P})
  src/components/OldNav.tsx   no importers   → delete file?
  src/lib/deprecated.ts       last edit > 6mo, no importers   → delete file?

Unused dependencies ({Q})
  lodash.merge (package.json:14)   not imported anywhere   → npm uninstall?

Likely-orphan (low confidence - review)
  src/types/legacy.ts   referenced only by tests, tests may also be orphaned

Total: {total} items
```

### 5. Get consent (structured)

Surface a structured multi-pick:

```
What do you want to act on?
  [ ] Delete confirmed unused exports
  [ ] Delete unreferenced files
  [ ] Remove unused imports (auto-fixable)
  [ ] Uninstall unused dependencies
  [ ] Review likely-orphans individually
  [ ] Preview only - no changes
```

For destructive actions (delete file, uninstall dep), require the consent-trigger phrase from `lib/consent.md` ("remove", "delete them", "apply").

### 6. Execute (if consented)

- Run the corresponding analyzer's fix mode where supported (e.g. `ts-prune --auto-fix` for unused exports if available; `eslint --fix` for unused imports if eslint configured; `npm uninstall {pkg}` for unused deps).
- For file deletions, use `git rm` if the repo is a git repo (CC head's repos always are), so the deletion is staged for the next commit.
- Never push, never commit. Stop at staging.

### 7. Comms output

If running on behalf of a Cowork-driven task (i.e. the request arrived via a `comms/open/{id}-task.md` comm), write a `comms/open/{reply-id}-answer.md`:

```yaml
---
from: cc
to: cowork
type: answer
parent: {original-task-id}
status: open
created: {ISO}
---

Code tech debt scan: {repo-name}
Found: {N} items ({n confirmed unused exports}, {m unreferenced files}, etc.)
Applied: {k} changes (staged for commit, not pushed)
See git status in {PROJECT}.cc/{repo-name}/ for staged changes.
```

If invoked directly (not via comms), just report to the user in chat.

### 8. Report summary

```
✓ Code tech debt scan complete: {repo-name}

Scanned: {N} files across {L} language scopes
Confirmed debt: {n} items
Applied: {k} changes (git-staged)
Remaining (preview only): {m} items

Recommended tools to install for better coverage:
  - ts-prune  (TypeScript unused exports - currently using heuristic)
  - vulture   (Python dead code - currently using heuristic)

Next: review staged changes with `git diff --staged` and commit when ready.
```

## Guard Rails

- [ ] Read-only until user consents per category
- [ ] Cross-reference confirms unused before high-confidence flag
- [ ] No auto-install of analyzer tools - only recommends
- [ ] Cap walk depth + file count; surface --deep option for full scan
- [ ] Never commits, never pushes - stops at git-staged
- [ ] Boundary respected: never edits outside the target repo
- [ ] Comms reply if invoked via task; chat reply if invoked directly
- [ ] Per-language analyzers governed by `@lib/code-analyzers.md` for extensibility

## Error Cases

**No supported language detected:** "No analyzer registered for this repo's stack. Add support in @lib/code-analyzers.md or skip."
**Analyzer tool missing AND no fallback:** Surface installation instructions per `@lib/code-analyzers.md`; offer to run partial scan with available tools.
**File flagged as orphan but recently edited:** Demote to likely-orphan; require user confirmation per item.
**Repo has uncommitted changes:** Surface a warning; user can proceed (changes will mix with their WIP) or abort.
**Repo is not a git repo:** Skip git-rm style staging; ask user how to record deletions.

## Extending to a new language

To add a language scope, edit `@lib/code-analyzers.md`:
1. Define detection signal (config file, dep name, file extension)
2. Specify preferred analyzer tool + invocation
3. Specify fallback heuristic (grep / AST pattern) for when tool missing
4. Define which findings categories the analyzer covers
5. Update this skill's "Build the scan plan" table if a new category emerges

No code change to this SKILL.md required for additive language support - the registry drives it.
