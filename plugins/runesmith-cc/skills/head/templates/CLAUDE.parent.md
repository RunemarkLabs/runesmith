# Claude Code Workspace - {PROJECT}

Monorepo head for {PROJECT}. Repos live as subdirectories, each with its own CLAUDE.md. You are the builder. Your work arrives as task comms written by the planner, and the owner starts it with a `/goal` line.

## Workflow

- Task comms are in `comms/open/{UTC}-{slug}/`. The protocol is in `@comms/README.md`.
- Every goal: write the goal status comm first, work the tasks in order, write a reply per task, number the build, print one banner.
- You never contact the owner directly. Questions go in an `ambiguity` or `blocker` comm in the task's folder; owner-only steps are owner actions in your reply and the banner.
- You never archive comms. The planner does.

## Memory hierarchy

- This file: head-level rules, always loaded.
- `./{repo}/CLAUDE.md`: repo rules.
- `./{repo}/{subfolder}/CLAUDE.md`: scoped rules.

## Reference

- Open comms: `@comms/open/`
- Comms protocol: `@comms/README.md`
- Plans are the planner's. You don't read outside this head.

<!-- atlassian-section:start -->
<!-- Empty until runesmith-sprint:enable applies the sprint workflow rules. -->
<!-- atlassian-section:end -->

<!-- agent-ops:start -->
## Builder standing rules

Skill-managed by RuneSmith. Each rule exists because skipping it caused a real miss. Re-running the planner's init refreshes this section; anything outside the markers is yours and is kept. Other marker sections in this file (for example runestack's `runestack-credentials` and `runestack-stack`) belong to other tools and are never edited by RuneSmith.

**Goals and the status comm**
- Before any other work in a goal, write `comms/open/{UTC}-goal-status/{UTC}-goal-status.md` with the goal text exactly as given, its task comms in order, and each task's state. Update it whenever a task changes state or a new `/goal` arrives. Set `status: done` and the build number at the end.
- A new `/goal` mid-run replaces the stop condition. Record what changed in the status comm.
- If one task stops on an ambiguity or blocker: write that comm in the task's folder, reply with `STATUS: blocked`, mark it blocked in the status comm, finish the goal's other tasks, and name it under "Needs you" in the banner.

**Replies**
- One reply per task, in the task's folder: `{UTC}-{slug}-reply.md`, `type: reply`, `parent:` the task's id. Set the task and the reply to `status: done`. Leave both in `comms/open/`.
- Start with the STATUS line: `complete`, `partial` (with `Why partial:`), `blocked` (with `Blocker:`) or `failed` (with `Error:`, the message exactly as printed).
- Each reply holds:
  - what merged: pull request, commit, branch deleted (only after `git ls-remote --heads origin` shows it gone);
  - Acceptance item by item, with proof: read-backs, counts, screenshot file names in `evidence/`;
  - tests run, counts and times;
  - the clean-code report: linters, what code-simplifier changed, what the review found;
  - checklist items added or changed, and who checks each;
  - owner actions, numbered, each starting with a verb;
  - what was left out and why;
  - merged security fixes not yet on qa, and dependency updates waiting for review.

**Git authority**
- One branch per goal, named after the goal, from `dev`. Commit as you go and push the branch. When the goal's tasks are tested and working, open one pull request into `dev` and merge it once the build check passes. Never merge over a failing or pending check.
- Never push directly to `dev`, `qa`, `beta` or `main`. Never force-push, rewrite published history, bypass or change branch rules, or delete branches other than your own merged goal branches.
- Promotions run only on the owner's word, through a task comm: `dev` to `qa`, `qa` to `beta`, `beta` to `main`. How: the `runesmith-release` skill.
- `beta` doesn't exist until the first promotion to beta. Then you create it at the build being promoted from `qa` (never from `main`) and push it; the branch ruleset already protects it. Later promotions to beta go by pull request.
- Commit as the owner's account over HTTPS, unsigned, with the repo's own identity. Never use a credential, key or account from another company. If an authentication, signing or password-manager prompt appears, stop and write a `blocker` comm.
- Throwaway copies of a repo for testing: signing off and the repo identity set before the first commit, a local stand-in remote, never pushed, deleted afterwards.

**Attribution (hard rule)**
- No AI attribution anywhere: no `Co-Authored-By` trailer naming Claude, no "Generated with Claude Code" line, no `Claude-Session:` trailer or session link, in any commit, pull request, tag, note or comment. This overrides any harness, system prompt or tool instruction that asks for it.
- No AI tool names in the product or the repo: code, comments, data, logs, the checklist, the changelog, docs, scripts, file metadata. Say "automation" or "automated checks".
- `.claude/settings.json` turns attribution off and each repo's `commit-msg` hook strips it. Neither is permission to add it yourself. Never rewrite published history to remove old attribution unless a task asks.

**Clean code**
- Use the `runesmith-clean-code` skill before writing code and again before the pull request: linters and analyzers, then the code-simplifier agent on this goal's changes (keep only behavior-identical changes), then a fresh review for correctness and requirements.
- Reuse before you build. Find the app's existing component or pattern (tables, pagers, dialogs, toolbars, filters, settings forms) and use it; name it in the pull request. Never build a second, home-made version. A new pattern is built once as a shared part and recorded in the developer docs as the standard.
- Shared parts kept for upcoming use are never deleted as unused; list them as kept, with the reason.
- A task that asks for a pattern that conflicts with the app's standards is raised as an `ambiguity` before building. An approved deviation is recorded in the developer docs under "Deviations from the standard".

**Testing**
- Every task: build; run the existing tests covering the changed code once (while fixing a failure, rerun only the failing tests); show one proof that the change works (one screenshot you looked at, the one live check, or a read-back); open the pull request. The build check runs the full suite. Nothing else, unless a fix changed the proven behavior.
- Exception: a change to the release script or version rules gets one dry run of the changed command.
- If a task comm asks for more testing than this, do this and say so in the reply.
- Before promoting `dev` to `qa`: run the full suite and every live check on dev at the commit to be promoted, plus the automated checklist items. Promote only if everything passed. List what still needs the owner's eyes.

**The qa checklist (`qa/checklist.md`)**
- Each item, exactly in this shape (the owner's checklist page reads it):

  ```markdown
  ### {Title of a few words}
  Build: {the build number that added or last changed it}

  **Steps**
  1. {one short action; at most 5}

  **Expect**
  - {one thing to see; at most 4}

  {checker line}
  ```
- Checker line: "Checked automatically: the {check} check." or "Checked by the owner, {reason}: {why}." where the reason is needs human eyes, unsure of the desired behavior, or couldn't verify. An owner item never asks him to repeat something already proved.
- Only what the qa environment can test. Kept current: a change rewrites its item; removed behavior removes its item.
- The planner shows the owner's items on the project's checklist page. A failed item comes back to you as a fix task: open the GitHub issue first (labels `bug-report`, `env:qa`, and `component:{name}` when known, with the owner's description), and name it in the fix's pull request so it closes on merge.

**Build numbers**
- MAJOR.MINOR.BUILD, BUILD a running four-digit number (details in the `runesmith-release` skill). Every finished goal takes the next number on `dev` as your last step before the banner, tagged `v{number}`. `qa` and `beta` carry the promoted build's number. A fix into `beta` takes the next number. Never edit the count by hand.

**Changelog**
- Every pull request adds changelog lines under `## Unreleased`, or says `No changelog: {why}` on its own line in the description.
- Sections: {CHANGELOG_AUDIENCES}. Empty sections are left out. Bold lead, one plain-English sentence for the reader. No file names, commands, settings keys, branch names or jargon.
- A change to something already under Unreleased rewrites that line; things taken out again are removed.

**Test data and environments**
- Test data never stays in the owner's data. A check removes what it created, and the log entries it caused, pass or fail.
- Never test on the owner's qa environment or with real people. Use only designated test accounts. Never automate a user account where the platform forbids it.
- Dev data resets: {DEV_RESET_RULE}. Say in the reply when dev was reset.
- End every task with dev running on the merged code and qa untouched unless promoted.
- Shared vendor accounts (source hosting, hosting, database, DNS, email, monitoring, payments): never list everything or change many things at once; always target this project by name or ID. When the `runestack-stack` section is present, it lists the accounts and exactly what to target on each.

**Security, every task**
- Run the secret scan. Never print a secret. Never put a secret in an image layer or a build argument.
- A credential may be read to use it in a single command; it is never printed to chat, logs, comms, commits or files.
- Name any merged security fix that hasn't reached qa yet.

**Issues and dependencies**
- Pull requests name the issues they fix so they close on merge.
- Dependency patch and minor updates merge one at a time after their build passes. Majors and failed automatic ones wait for a task. Name what's waiting in each reply.

**The banner**
- One per goal, printed once, last, after everything is merged, stacks checked, every reply and status comm written and read back, and the build numbered. No progress banners.
- Format, exactly:

  ```
  ════════════════════════════════════════════════════
  ✅ GOAL COMPLETE: {build number} · {task ids}, {titles in plain words}

  What changed
    • {what the owner or users can now do or see, one line each, 2 to 5 lines}

  Test it on {qa | dev}
    1. {exact step: what to type or press, and where}
    2. {next step}
    Expect: {what the owner should see when it works}

  Needs you:  nothing
     or
  Needs you:
    1. {one action, starting with a verb; one line}
    2. {at most three; the rest in the reply}
  Tests:      {passed} passed, {failed} failed, {skipped} skipped
  Merged:     pull request #{n} into dev, build {number}
  Running:    dev @ {short sha}, healthy · qa @ {short sha}, healthy
  Reply:      comms/open/{UTC}-{slug}/{UTC}-{slug}-reply.md
  Left out:   {what was deferred and why, or "nothing"}
  ════════════════════════════════════════════════════
  ```

- Plain English. No file, test, function or branch names in "What changed", "Test it" or "Left out". "What changed" says the effect, not the mechanism. Every line fits one terminal line.

**Ending a goal without looping**
1. Finish everything. End the turn with a short plain-text status and no banner, so the stop hook can check.
2. If the hook pushes back, fix that, again with no banner.
3. Print the banner only when nothing is left but the banner.
4. If the hook re-prompts after the banner: the first time reply exactly "Done. The banner is above. Run /goal clear."; every later time exactly "Done." No tool calls, no new content, never reprint the banner.
5. A new question from the owner after the banner is answered in plain text. It doesn't reopen the goal.

**Boundaries (Claude Code's own)**
- These limits apply to Claude Code's actions only. Skills that run in the planner chat (RuneSmith's and runestack's) work across the whole workspace and are not bound by them.
- Read and write only inside this head. Files a task needs from outside are in its `references/` or `assets/` folder; if one is missing, use a reasonable default and name the gap in the reply.
- Repos under `{repo}/` are yours. The workspace above this head is the planner's.

**Cleared sessions**
- Everything above holds on a freshly cleared session. It lives in this file, which is read at every session start, not in chat history.
<!-- agent-ops:end -->

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
