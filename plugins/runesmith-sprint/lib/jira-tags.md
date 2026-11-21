# Jira Tag Taxonomy

Canonical labels both Cowork and Claude Code apply to tickets. Generic, project-agnostic - works for any user's Jira instance.

Tags are Jira **labels**, not custom fields. No special configuration needed in the user's Atlassian site beyond standard label support.

## Cowork-applied

| Tag | When |
|---|---|
| `cowork-planned` | Cowork created this ticket from a plan. Description links to plan slug. |
| `cowork-resolved` | Cowork answered a blocker that came from CC; comm archived. |
| `cowork-transition` | Cowork executed a Jira state transition on CC's behalf. |

## CC-applied

| Tag | When |
|---|---|
| `cc-plan` | CC documented its implementation plan as a ticket comment. |
| `cc-action` | CC took an action (commit, push, refactor) and recorded it. |
| `cc-decision` | CC made a non-obvious decision worth recording. |
| `cc-blocked` | CC is blocked on this ticket; paired with a blocker comm. |
| `cc-done` | CC completed the work; ready for transition. (Cowork transitions, see `cowork-transition`.) |

## Cross-cutting

| Tag | When |
|---|---|
| `needs-user` | Either side flags that user-only action is required (repo creation, secret rotation, click in a UI). |
| `bootstrap` | Created by a marketplace skill, not manually. Useful for filtering. |

## Tag application rules

- **Add, don't replace.** Skills append labels. Existing labels are preserved.
- **Remove on resolution.** When `cc-blocked` resolves, CC writes a comment + removes the `cc-blocked` label. `needs-user` works the same way.
- **Tags appear in JQL.** Skills use them: `JQL: project = X AND labels = cc-blocked AND sprint in openSprints()`.

## Skill responsibilities

| Skill | Tags it writes | Tags it removes |
|---|---|---|
| `runesmith-sprint:plan-to-tickets` | `cowork-planned`, `bootstrap` | - |
| `runesmith-sprint:check-comms` | `cowork-resolved` (on blocker resolution) | `cc-blocked`, `needs-user` (when resolving) |
| `runesmith-sprint:sprint-status` | - | - (read-only) |
| CC `ticket-document` | `cc-plan` / `cc-action` / `cc-decision` (per type) | - |
| CC `blocker-write` | `cc-blocked`, `needs-user` (if user-only) | - |
| CC `ticket-done` | `cc-done` | - (Cowork removes `cc-blocked` etc. when transitioning) |
| Cowork transition (response to `ticket-transition` comm) | `cowork-transition` | `cc-done` after successful transition |

## Audit views (suggested for the user)

The user can build saved JQL filters on their board:

- **CC blockers needing me:** `labels = cc-blocked AND labels = needs-user`
- **CC blockers Cowork can resolve:** `labels = cc-blocked AND labels NOT IN (needs-user)`
- **CC-completed pending transition:** `labels = cc-done AND status = "In Progress"`
- **Cowork-planned this sprint:** `labels = cowork-planned AND sprint in openSprints()`

## Custom field option (advanced)

If the user wants richer state than labels allow, the marketplace can be configured to use a Jira custom field instead. Set `ATLASSIAN_TAG_FIELD=customfield_XXXXX` in `.credentials`. Skills will read/write that field instead of labels. Default behavior uses labels.
