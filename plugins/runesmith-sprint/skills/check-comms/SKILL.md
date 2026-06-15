---
name: check-comms
description: "Triage open comms in {PROJECT}.cc/comms/open/ - surface to-user items, draft replies, archive resolved folders. Use when the user says \"check comms\", \"any messages from CC\", \"what does CC need\", \"check messages\", \"is CC blocked\", \"triage comms\", or wants to clear out CC's open comms."
compatibility: Requires Cowork desktop app environment.
---

# Check Comms

Walk every per-comm folder under `{PROJECT}.cc/comms/open/`. Surface `to: user` items first. Let user reply or defer. Archive resolved folders (the WHOLE folder) to `comms/archive/{YYYY-MM}/`.

Works in both base config and atlassian-enabled config. In atlassian config, comms may carry `ticket: {KEY}` and `type: ticket-transition` - this skill executes the Jira mutation when that's the request, via the workspace's MCP-connected Atlassian tools.

## Archive ownership

**Cowork (this skill) owns the archive move.** CC writes the reply and flips BOTH task and reply files to `status: resolved`, then LEAVES them in `comms/open/`. This skill is the next agent to touch the comm: it verifies the result, then moves the entire `{PREFIX}-{NNN}-{slug}/` folder (task + reply + any `attachments/`) to `comms/archive/{YYYY-MM}/{PREFIX}-{NNN}-{slug}/` as a single atomic move.

This resolves the prior three-way contradiction: CC parent used to say "CC archives", check-comms used to say "Cowork archives", protocol-doc was ambiguous. The canonical rule now: CC writes + flips status, Cowork moves.

## References

- `agents/comms-triager.md` - subagent for per-comm parsing and action
- `lib/comms-protocol.md` - file format, ID conventions (`{PREFIX}-{NNN}-{slug}`), folder layout, type enum, lifecycle
- `lib/comms-check.md` - same-named lib doc, but DIFFERENT thing (lib is the on-entry helper; this is the standalone triage skill)
- `lib/atlassian-enabled.md`
- `lib/jira-tags.md` - tags to add/remove on resolution
- `lib/user-prompts.md` - structured-input requirement for any user prompt

## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 1. Locate comms folder

Find `{PROJECT}.cc/comms/open/`. If missing or empty: report and exit clean.

### 2. Atlassian-enabled?

Read marker. Used to decide whether to handle `type: ticket-transition` items inline.

## When to Use

Use for:
- After CC has been working - "what's CC need from me / Cowork?"
- Before kicking off another planning skill (the on-entry lib does a quick version of this; this skill is the deep version)
- Closing the loop on resolved comm folders (archive)

Do not use for:
- Writing new comms yourself (do that within other skills)
- Cleaning up archive (out of scope; archive is permanent)

## Workflow

### 1. List open comm folders

Walk every subdirectory of `comms/open/`. Each folder is named `{PREFIX}-{NNN}-{slug}/` and contains:

- `{PREFIX}-{NNN}-{slug}.md` - the task
- `{PREFIX}-{NNN}-{slug}-reply.md` - the reply (if CC has answered)
- `attachments/` - optional, files CC needed from outside the repo

Parse frontmatter on both task and reply (if present). Group by reply state + `to:`:

- Reply present, both `status: resolved` → archive candidate
- Reply present but `to: user` items → highest priority (user must see)
- No reply, `to: cc` → CC is still working
- `to: cowork` (typically `ticket-transition`) → Cowork must act

### 2. Surface to-user items

For each comm folder where the reply has `to: user`:

```
[from cc, type: blocker]  {PREFIX}-{NNN}-{slug}
ticket: PROJ-42  (if atlassian-enabled)
created: {ISO}
body: <first 5 lines of reply>

What do you want to do?
  [r]eply  - write an answer comm in the same folder
  [d]efer  - leave folder open, move on
  [s]how   - print full comm
```

On `[r]eply`: prompt user for answer text. Write a new comm in the SAME folder with `from: user, to: cc, parent: {PREFIX}-{NNN}-{slug}, type: answer`. Flip the reply's `status: resolved`. On next iteration, the folder will archive.

On `[d]efer`: skip.

On `[s]how`: print full body, return to action prompt.

### 3. Handle to-cowork items

For each comm folder where the reply (or task, if Cowork is the destination) has `to: cowork`:

#### type: ticket-transition (atlassian-enabled only)

CC asked Cowork to transition a Jira ticket. Body specifies `ticket: {KEY}` and target state.

Show user:
```
[from cc, type: ticket-transition]  {KEY}: <summary>
Target state: <state>
```

Surface a structured single-pick prompt: question "Approve transition?", options "Approve" / "Deny" / "Show details first".

On approve:
1. Look up transition id via `GET {SITE_URL}/rest/api/3/issue/{KEY}/transitions`.
2. Find transition by name matching target state. (Use Cowork's MCP atlassian connector or REST fallback if MCP can't.)
3. POST the transition.
4. On 200: write reply comm `from: cowork, to: cc, type: answer, parent: {PREFIX}-{NNN}-{slug}`, status: resolved. Add `cowork-transition` label to the ticket. Remove `cc-done` label per `jira-tags.md`.
5. Flip both files to resolved, archive the folder.

On deny: write reply with reason. Don't archive yet - let user re-engage later.

#### type: ambiguity / blocker where to: cowork

CC is asking Cowork directly (e.g., "what's the convention for X?"). Show user, prompt for guidance, write reply on user's behalf in the same folder.

### 4. Show to-cc items

For folders where the task has `to: cc` and no reply yet (Cowork → CC, awaiting CC pickup):
- These need CC to act, not the user. Show as informational:
  ```
  [from cowork, type: task]  {PREFIX}-{NNN}-{slug}
  status: open since {ISO}
  CC will pick this up on next session.
  ```
- No action required from user; user can `[c]ancel` an outgoing task if it shouldn't be there.

### 5. Archive resolved folders

For every comm folder where BOTH the task and reply have `status: resolved`:
- Move the entire folder (task file + reply file + `attachments/` if present) to `comms/archive/{YYYY-MM}/{PREFIX}-{NNN}-{slug}/`.
- Single move; preserves filenames; the folder name is the comm id.

### 6. Report

```
[OK] Comms triaged
Surfaced to user: n
Handled (replied/transitioned): m
Archived: k folders
Still open: x

Open comm folders by audience:
  to user:    {n}
  to cowork:  {n}
  to cc:      {n}
```

## Guard Rails

- [ ] Comms folder located; exit clean if empty
- [ ] Frontmatter parsed for task + reply in every folder (skip with warning if malformed)
- [ ] User explicitly approves any reply or transition before write
- [ ] Atlassian transitions only attempted when atlassian-enabled
- [ ] Tags updated per `jira-tags.md` on transition
- [ ] Resolved folders archived (whole folder moves); not deleted
- [ ] Malformed comm files surfaced but not modified

## Error Cases

**Malformed frontmatter:** Surface folder + parse error; ask user - fix manually, delete (with consent), or skip.
**Transition fails (Jira 400/403):** Show error; reply comm captures the failure; ticket stays in current state. User can retry after fixing the cause.
**Comms folder doesn't exist:** Either CC head doesn't exist (suggest `/runesmith-cc:bootstrap-cc`) or user is in the wrong workspace.
**User wants to bulk-defer:** Provide a `[d]efer all` shortcut that skips through.
**Comm references a ticket the user can't access:** Surface the auth error; user fixes Jira permissions; retry.
**Loose files in `comms/open/` (no parent folder):** Legacy flat layout. Surface, ask user whether to migrate into per-comm folders or treat as orphans.
