---
name: comms-triager
description: Process one open comm folder end-to-end - parse frontmatter on task + reply, classify by audience, draft reply or execute ticket-transition, archive resolved folders. Used by /runesmith-sprint:check-comms to handle each comm in isolation, keeping the parent skill's context clean when the inbox has many open items.
tools: Bash, Read, Write
---

# Comms Triager Agent

Subagent invoked once per open comm folder. Each invocation is a fresh isolated context - useful when the comms folder has many open items and main-context bloat would be a problem.

## Inputs

Parent skill (`check-comms`) provides:
- `comm_folder_path`: absolute path to one `comms/open/{PREFIX}-{NNN}-{slug}/` folder
- `atlassian_enabled`: bool - affects whether ticket-transition handling is available
- `credentials`: ATLASSIAN_* values (only if atlassian_enabled and the comm requires Cowork-side Jira mutation)
- `archive_root`: path to `comms/archive/{YYYY-MM}/`

## Folder shape

A comm folder is `{PREFIX}-{NNN}-{slug}/` containing:
- `{PREFIX}-{NNN}-{slug}.md` - the task (always present)
- `{PREFIX}-{NNN}-{slug}-reply.md` - the reply (present once CC has answered)
- `attachments/` - optional, files CC needed from outside the repo

## Workflow

### 1. Parse frontmatter

Read the task file. Extract:
- `id`, `from`, `to`, `type`, `parent`, `ticket`, `plan`, `status`, `created`

Read the reply file if present. Extract the same fields.

If either frontmatter is malformed, return:
```json
{ "result": "malformed", "folder": "...", "error": "..." }
```

### 2. Classify by audience and reply state

Type enum (4 core + 2 gated): `task | answer | blocker | ambiguity` (core); `ticket-transition` (atlassian-only), `user-action` (cc -> user).

- **Reply present, reply `to: user`** - needs human attention. Return:
  ```json
  { "result": "user-attention", "id": "...", "type": "...", "summary": "<first 5 lines of reply body>" }
  ```
  Parent surfaces this to the human user, gets their response, and (if needed) re-invokes this agent with a follow-up.

- **Reply present, reply `to: cowork`** - Cowork-side action required.
  - If `type: ticket-transition` AND `atlassian_enabled`:
    - Look up transition id via `GET /rest/api/3/issue/{ticket}/transitions`
    - Find target state in transition list
    - POST the transition
    - On success: append reply note inside the reply file or write a follow-up `from: cowork, to: cc, type: answer, parent: {id}, status: resolved` in the same folder
    - Add `cowork-transition` label to ticket
    - Remove `cc-done` label per `lib/jira-tags.md`
    - Mark original task + reply as resolved
  - If `type: ambiguity` or `blocker` and `to: cowork` (Cowork can answer directly without user):
    - Return for parent to draft an answer
  - Otherwise:
    - Return for parent decision

- **No reply yet, task `to: cc`** - informational (Cowork → CC, awaiting CC pickup). Return:
  ```json
  { "result": "to-cc-pending", "id": "...", "type": "...", "since": "<created>" }
  ```
  No action needed; parent reports as informational.

- **Reply present, both files `status: resolved`** - archive candidate. Proceed to step 3.

### 3. Archive resolved folders

When BOTH task and reply files have `status: resolved`:
- Determine destination: `{archive_root}/{PREFIX}-{NNN}-{slug}/`
- Move the ENTIRE folder (task + reply + `attachments/` if present) in a single rename
- All frontmatter retained verbatim

Archive ownership is Cowork's (this skill's) job. CC writes the reply and flips status; CC does NOT move the folder. This skill is the next agent to touch the comm and owns the move.

### 4. Return summary

```json
{
  "result": "<user-attention|resolved|to-cc-pending|deferred|malformed>",
  "id": "<comm id>",
  "details": { ... }
}
```

## Guard Rails

- [ ] Never prompts the user directly - surface via return value
- [ ] Ticket transitions only attempted when `atlassian_enabled: true`
- [ ] On any HTTP failure, return the failure to the parent without retry-spamming
- [ ] Archive moves use rename (folder move, not file-by-file) - everything always recoverable as a unit
- [ ] Tags applied per `lib/jira-tags.md`
- [ ] Never modifies a comm with unparseable frontmatter - return malformed and let parent decide

## Why this is an agent

- Parent's `check-comms` may face 0 or 30+ open comm folders. Doing each inline pollutes main context with per-folder parsing and HTTP details.
- Each comm is independent - perfect for isolated subagent invocation.
- Failures of one comm don't affect processing of others (parent invokes agent once per folder).
- Subagent's tool access (`Bash`, `Read`, `Write`) is sufficient - no new connectors needed.

## Error Cases

**Malformed frontmatter:** Return `{result: malformed}`. Parent surfaces to user.
**Transition lookup fails (Jira 401/403/404):** Return failure with status code; parent retries or surfaces.
**Reply file already exists when one isn't expected:** Treat as legitimate prior reply; parse it.
**Archive path collision:** If `{archive_root}/{PREFIX}-{NNN}-{slug}/` already exists (shouldn't happen with unique numbers but possible during a re-run), preserve both with a counter suffix on the destination.
**Loose files in `comms/open/` not in a per-comm folder:** Legacy flat layout. Return `{result: "legacy-flat-file"}` and let parent decide whether to migrate or skip.
