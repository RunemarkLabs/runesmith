---
name: runesmith-clean-code
description: "The project's standards for writing and changing code so a person can read and review it: reuse before you write, one purpose per function, clear names, no dead code, no narrating comments, small diffs, the surrounding style. Use on every task that writes or changes code, before writing and again before the pull request (linters, code-simplifier, tests, a correctness review)."
---

# Clean code

Use this while writing code, not only when reviewing it. The project's limits and the checks that enforce them belong in the developer docs (a "Clean code" section); the build fails on what a tool can see. This skill covers the judgment no tool makes.

## While writing

1. **Reuse first.** Before writing a helper, class, hook or utility, search for an existing one (search for the name you'd give it, and for the operation). In the pull request description, say what you searched for and what you reused.
2. **Follow the folder you're in.** Match the patterns and style of the code around you. Don't reformat or tidy untouched code in the same change.
3. **Solve today's task only.** No options, extension points, interfaces or layers for needs that don't exist yet.
4. **One purpose per function.** A function does one thing you can name in a few words; if the name needs "and", it does two. Split only when the extracted piece has a purpose you can name and hides detail from the caller. Don't split when the reader would have to read the helper anyway, when helpers share hidden state, or when they must be called in a fixed order. No pass-through methods, no interface with one implementation unless it marks a real boundary (an outside service, a test seam).
5. **Size and shape.** Aim for about 25 lines a function. Past 30, look for a cohesive piece to name and move. The project's hard limits (lines, complexity, nesting, parameters) are review triggers: simplify with early returns, guard clauses and fewer conditions, not by moving nested blocks into helpers. If it's still right as it is, say why in a comment on the same line as the suppression.
6. **No true/false mode parameters.** Use an enum or two well-named functions; never two booleans on one member. In UI components, one `variant` prop, not several boolean props. When a shared helper would need a new flag or `switch` for a new caller, stop: copy the logic into the caller, or design a new abstraction from current needs.
7. **One place per decision.** Each branch on a kind of thing lives in one place. Remove repeated knowledge right away (business rules, limits, outside services' contracts); tolerate code that only looks similar until the shared idea is clear.
8. **Names a reader understands without the code around them.** Full words, verbs for functions, length matched to scope (short names only for loop indexes and tiny lambdas). Follow the language's naming conventions; write the project's in the developer docs.
9. **Comments say why**: intent, constraints, an outside service's quirks, a deliberate trade-off. Never what the code already says; delete narrating comments. A comment that contradicts the code is a bug. Public contracts (shared types, API endpoints, exports) say what they promise, not how.
10. **Errors.** Expected outcomes (not found, over a limit, a duplicate, a service down) are return values or Try-functions. Throw only when an assumption is broken. Catch only what you can handle, and only at the edges (request handlers, middleware, background jobs); rethrow without losing the original. Make operations safe to repeat: approving something already approved succeeds and does nothing.
11. **Values that don't change** are declared that way (read-only fields, records or immutable types, `const`). In UI code, never change props, state or hook values in place.
12. **No unnamed numbers or strings** for limits, timeouts, retry counts, identifiers or paths: named constants or settings.
13. **UI code.** Compute derived values during render; put the logic for a user's action in its handler; use effects only to sync with something outside, and clean them up; fetch through the project's shared helpers.
14. **No dead code** in the project's own code, including code your own change made unused: no unused members, imports, parameters or exports, no commented-out blocks, no stale to-do notes. Shared parts kept on purpose for upcoming use are listed as kept in the unused-code check, with the reason; never delete those as unused.
15. **Never silence a check to make it pass.** Fix the cause. A suppression that's truly needed has its reason on the same line and is named in the pull request. Never add to a suppression or baseline file, never lower a severity or raise a limit.
16. **Tests** fail if the code breaks; none for cases that can't happen.
17. **Safety.** No secrets in code. Close every resource. Never build paths, queries or shell commands from user input without validating it.
18. **Small diffs.** One self-contained pull request, ideally about 100 changed lines and under 400; refactoring and dead-code removal in their own pull requests. A measured hot path may break the size rules, with the measurement in a comment.

## Before the pull request

Run these in order, and report each in the reply comm (what ran, what it changed).

1. **Linters and analyzers:** the project's build with warnings as errors, its type checker and its linters. Treat any new warning as a failure. The exact commands for this project: {LINT_COMMANDS}
2. **code-simplifier on this goal's changes.** The code-simplifier agent comes from Anthropic's official `code-simplifier` plugin, installed for this head when it was set up. Run it with:
   - the list of files this goal changed (`git diff --name-only origin/dev`);
   - "only refine what this branch changed";
   - "follow the repository's CLAUDE.md and developer docs over your generic defaults" (its built-in defaults assume a JavaScript and React stack);
   - "behavior must stay identical".

   If the agent isn't available in this session, launch a general-purpose subagent with the same brief and say so in the reply. Keep only changes that keep behavior identical, and review its diff yourself.
3. **Rerun the affected tests** (the head's testing rule), then the linters again.
4. **A fresh correctness review:** a subagent that has not seen your reasoning, given only the diff and the task's Acceptance, asked to find correctness and requirement problems only (not style, not structure), so the review doesn't push more abstraction. Fix what it finds that's real.
5. **In the reply comm:** that this skill was used, what the linters reported and what you fixed, what code-simplifier changed (or that it changed nothing), and what the review found.

<!--
  Deployed from RuneSmith marketplace (runesmith-cc). Adapted from the owner's builder tools, 2026-11-21.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
-->
