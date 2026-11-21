---
name: ticket-done
description: "Mark a ticket complete from CC's side - write a comm requesting Cowork to transition the ticket to Done, tag with cc-done. Use when CC has finished implementation and verified the work meets acceptance criteria. Runs in Claude Code."
compatibility: Runs in Claude Code, inside the project's head.
---

# Ticket Done (CC-side)

CC's token cannot transition Jira state by design. CC requests the transition via a `type: ticket-transition` comm. The planner's `check-comms` makes the transition through the Jira REST API.

## References

- `@comms/README.md`
- `@lib/jira-tags.md`
- Sibling: `ticket-document` for the cc-done label

## Pre-Flight Checks

1. Marker says `atlassianEnabled: true`.
2. Implementation actually meets the ticket's acceptance criteria. Read the ticket to verify; if uncertain, surface ambiguity instead.

## Workflow

### 1. Self-check

Re-read the ticket description and acceptance criteria. Confirm:
- Each criterion is satisfied by committed code.
- All known tests pass.
- Required documentation is in place.

If anything fails, write a blocker through `blocker-write` instead - don't request Done.

### 2. Add `cc-done` label

If capability allows:
```
PUT {SITE_URL}/rest/api/3/issue/{KEY}
{ "update": { "labels": [{ "add": "cc-done" }] } }
```

Otherwise, request via the same comm in the next step.

### 3. Write the transition request comm

```
comms/open/{UTC}-{slug}/{UTC}-{slug}-ticket-transition-{n}.md     (in the current task's folder)
```

```yaml
---
id: {UTC}-{slug}-ticket-transition-{n}
from: cc
to: cowork
type: ticket-transition
parent: {UTC}-{slug}
ticket: {KEY}
target-state: Done
status: open
created: {ISO time, UTC}
also-add-labels: []                  # if cc-done already added directly, leave empty
also-remove-labels: [cc-blocked]     # in case ticket was previously blocked then unblocked
---

# Transition {KEY} → Done

## Body
Implementation complete. Acceptance criteria verified:
1. {criterion} - satisfied by {evidence: commit, test or file}
2. ...

Last commit: {sha}
Branch: {goal branch}
Pull request: {address}

## Acceptance
Transition the ticket to Done. Reply with `type: answer` confirming
transition succeeded.
```

### 4. Append `cc-action` comment with completion summary

Use `ticket-document` skill with `type: action` - body summarizing what was done. This becomes the audit trail on the ticket itself.

### 5. Move on

After writing the transition comm, carry on with the goal's next task. Never pick a ticket the goal doesn't name.

### 6. Report (in CC chat)

```
Done on {KEY}: {one-line summary}
Wrote: {transition comm filename}
Label cc-done: <direct | via comms>
Picking next available ticket…
```

## Guard Rails

- [ ] Self-check completed against ticket acceptance criteria
- [ ] Comm written with `type: ticket-transition`, `target-state: Done`
- [ ] `cc-action` comment captures completion summary on the ticket itself
- [ ] CC moves to next ticket; does not re-edit this one
- [ ] If self-check fails, write `cc-blocked` comm instead

## Error Cases

**Acceptance criteria unclear:** Don't claim Done. Write `to: cowork, type: ambiguity` asking for clarification.
**Label add fails:** Comm route handles it via `also-add-labels`.
**Ticket already in Done state:** No-op; surface in CC chat. Don't re-write the comm.
**Cowork rejects the transition (replies declining):** CC reads the reply, treats as feedback, addresses what's missing, retries.

---

<!--
  Deployed from RuneSmith marketplace.
  Copyright 2026 Runemark Labs. Licensed under Apache-2.0.
  Source: https://github.com/runemarklabs/runesmith
-->
