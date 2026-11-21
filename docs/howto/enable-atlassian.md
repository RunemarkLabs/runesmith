# How-to: Enable Jira and Confluence on a Project

RuneSmith projects work without Atlassian: plans and comms drive the work. Turning it on makes Jira hold work state and Confluence hold lasting documents.

For the model, see `docs/AGENT_PRIMER.md` ("Jira is optional").

## Prerequisites

- The project is set up with `/runesmith-workspace:init`. (Init can turn Jira on for you; this guide is for turning it on later.)
- The Jira project and Confluence space exist. The Cloud API can't create spaces, and project creation is usually admin-only.
- The planner's keys in `{WORKSPACE_ROOT}/.credentials`: `ATLASSIAN_API_URL`, `ATLASSIAN_API_EMAIL`, `ATLASSIAN_API_TOKEN` (token from https://id.atlassian.com/manage-profile/security/api-tokens). If they're missing, enable tells you which to paste.

## Run enable

```
/runesmith-sprint:enable
```

It asks for:

- **Jira project key**, for example `ENG`. It looks up the id.
- **Board:** picked from the project's boards.
- **Confluence space key.** It looks up the id.
- **Claude Code's token** (code projects): its own read-only token (default), or reuse yours. Reusing yours lets Claude Code change Jira directly.

Then it shows every file it will change. **Apply** or **Cancel**.

## What it changes

- The `atlassian-section` of the root `CLAUDE.md`, and of `{PROJECT}.cc/CLAUDE.md` for a code project.
- `.atlassian-enabled` at the root, the signal other skills check.
- The `atlassian` block in `{PROJECT}.cc/.claude-code-workspace`.
- `ATLASSIAN_BOARD_ID` in RuneSmith's block of `{PROJECT}.cc/.credentials`. The token lines stay empty for you.
- Claude Code's Jira skills, each in its own folder: `runesmith-sprint-pull`, `runesmith-ticket-document`, `runesmith-blocker-write`, `runesmith-ticket-done`.

Everything is snapshotted first to `archive/_pre-enable-{UTC}/`.

## Paste Claude Code's token

Open `{PROJECT}.cc/.credentials` and paste `CC_ATLASSIAN_API_EMAIL` and `CC_ATLASSIAN_API_TOKEN` (single-quoted). Tell the planner it's done; it checks the token with one read and reports the result. Never paste a token into chat.

## Paste the Project Instructions supplement

Enable gives a block between `<!-- runesmith:atlassian-start -->` and `<!-- runesmith:atlassian-end -->`. Add it to the end of the Project's instructions. If you run `/runesmith-workspace:init` afterwards, its fresh block already includes it.

## Verify

```
/runesmith-jira:project-status
```

Read only. Shows the active sprint and recent issues. A 401 means the email and token don't match; a 404 means the project key or board is wrong.

## Work with Jira on

- `/runesmith-sprint:plan-to-tickets` drafts tickets from a plan into `plans/active/{slug}/tickets/`. They're pushed to Jira only when you approve, then archived to `archive/tickets-pushed/{YYYY-MM}/`, and the plan's `tickets:` list fills in.
- `/runesmith-sprint:start-sprint` turns the active sprint into task comms through `/runesmith-sprint:task`.
- `/runesmith-sprint:sprint-status` shows the board and open comms. It writes nothing.
- Claude Code reads only the tickets its current task names. When a ticket must move, it writes a `ticket-transition` comm and the planner moves it on check comms.

## Turn it off

```
/runesmith-sprint:disable
```

Empties both `atlassian-section`s (the markers stay), removes `.atlassian-enabled`, clears the head's Atlassian settings, and moves Claude Code's Jira skills into the snapshot. Credentials, comms, plans and ticket history stay. It tells you which block to delete from the Project's instructions.

## Troubleshooting

**401 on every call.** The email and token must belong to the same account.

**404 on `/rest/api/3/search`.** That endpoint was retired; the current one is `POST /rest/api/3/search/jql`. Rebuild and reinstall the plugins.

**400 on a Confluence page create.** The body must be storage format. The Confluence skills convert it; run your markdown through `scripts/md-to-storage.py` if you call the API directly.

**409 on a Confluence update.** Version conflict. The skills read the current version and send the next number.

**Severity field rejected on a bug report.** Map severity to `priority`, or set `ATLASSIAN_BUG_SEVERITY_FIELD` to your custom field id.

**Claude Code's token check fails with "refused".** The request never left: the session's network allowlist blocks the site. The token may be fine.
