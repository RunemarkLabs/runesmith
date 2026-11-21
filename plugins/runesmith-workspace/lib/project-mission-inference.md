# Project mission inference

When `runesmith-workspace:init` emits Project Instructions text on a re-run (or fresh-run with existing workspace content), the PROJECT section's mission can often be inferred from workspace signal instead of being left as a fill-in placeholder. This file documents the inference procedure.

## When to infer

Run inference at step 3 of init ("What is this project?"), BEFORE rendering the template.

## Signal sources (read in this order; stop at first strong hit)

1. **`README.md`** at workspace root. The top section (intro + tagline + first paragraph after the H1) is usually the mission. High signal.
2. **`source-docs/*.md`** - the top-level files only, not recursive. These are the canonical project docs the user has dropped in. Look for an intro / overview section in the first 1-2 files (sorted alphabetically). High signal.
3. **Prior `CLAUDE.md` content outside markers** - if `CLAUDE.md` exists, read content BEFORE the `<!-- folder-conventions:start -->` marker (the user preamble). Often contains a "## What we're doing" or similar section. Medium signal.
4. **`package.json` description** or **`pyproject.toml` description** if either exists at workspace root or inside a single detected git repo. Usually one sentence; sufficient as a seed. Low-medium signal.
5. **Top-level `notes/*.md`** - last resort. Notes can be too narrow (single-session working memory). Skip unless nothing else hits.

Do NOT read `plans/active/*/plan.md` or `tickets/*` for mission inference. Plans describe current work, not the project as a whole. Pulling from them produces a draft that's too narrow ("this project is about implementing the guardrail" - that's a plan, not the project's mission).

## Inference rules

1. **First strong hit wins.** Stop reading after the first source that produces a coherent 1-3 sentence draft. Don't merge across sources - that produces salad.
2. **Stay terse.** The PROJECT section is 1-3 sentences. Don't draft a paragraph; if the source has more, summarize.
3. **No structural details.** Per `lib/project-instructions.md`, Project Instructions must NOT contain file paths, plugin names, folder layouts. If the source has those, paraphrase to behavioral / mission terms only.
4. **No certainty claims.** The draft is a proposal. Phrase as "this project IS about X" matter-of-factly; the user will edit if wrong.

## Structured prompt format

Show the draft and where it came from, then ask:

```
Drafted from {source}:
"{drafted 1-3 sentences}"

- Use this (default)
- Edit
```

On Edit, a text-input form pre-filled with the draft.

## No signal

Offer two short drafted descriptions built from what the owner has said in the chat (the question tool needs at least two options); he can type his own in "Other". There is no placeholder option: a "fill this in" placeholder was rejected by the owner (2026-11-21).

## ROLE section is NOT inferred

ROLE is not inferred either. It comes from init's "Will this project hold code?" answer, per the template in `lib/project-instructions.md`.

## Idempotence

On a re-run, init skips the question when the project description is already in CLAUDE.md's preamble, and reuses it.

## Implementation note (inline, not subagent)

Inference reads 4-6 small files. Inline file reads inside the init skill are appropriate; no subagent dispatch needed. Subagent would add 10-30s latency for a deterministic read+summarize job.
