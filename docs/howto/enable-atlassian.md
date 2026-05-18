# How-to: Enable Atlassian on a Workspace

By default, RuneSmith workspaces are plan-driven without any Atlassian dependency. Enabling Atlassian wires the project into Jira (work state) and Confluence (durable docs). Plans become tickets in sprints; decisions and design docs flow into Confluence pages.

For the architectural model, see `docs/AGENT_PRIMER.md` ("The Atlassian config split").

## Prerequisites

- Workspace already laid out via `/runesmith-workspace:reallocate`. If not, run that first — see `docs/howto/new-workspace.md`.
- Jira project + Confluence space exist on your Atlassian site. The marketplace can't create them via API (Confluence Cloud v2 doesn't expose space creation; same for Jira projects in self-serve).
- `.credentials` populated with `ATLASSIAN_API_URL`, `ATLASSIAN_API_EMAIL`, `ATLASSIAN_API_TOKEN`. See `.credentials.example`. Token from https://id.atlassian.com/manage-profile/security/api-tokens.

## What enabling does

`/runesmith-sprint:enable` is a one-shot wiring step. It:

1. Prompts (structured input) for the Jira project key, board id, default sprint board, Confluence space id, and default assignee accountId.
2. Saves those values to `.credentials` if not already present (under `ATLASSIAN_JIRA_PROJECT_KEY`, `ATLASSIAN_JIRA_BOARD_ID`, `ATLASSIAN_CONFLUENCE_SPACE_ID`, `ATLASSIAN_DEFAULT_ASSIGNEE_ACCOUNT_ID`).
3. Writes `.atlassian-enabled` at workspace root — the canonical marker that signals atlassian rules apply.
4. Appends a `<!-- runesmith:atlassian-start --> ... <!-- runesmith:atlassian-end -->` block to workspace `CLAUDE.md` (project-key, board-id, space-id pinned, lookup rules, scope rules).
5. Appends the same marker block to `{PROJECT}.cc/CLAUDE.md` so CC inherits the scope.
6. Surfaces a Project Instructions supplement block — append to your existing Cowork Project Instructions field. Same marker pair. Carries the behavioral rules (Jira owns work state, Confluence owns durable docs, mutations require explicit trigger phrases).
7. Deploys CC-side skill templates into `{PROJECT}.cc/.claude/skills/atlassian/`: `sprint-pull`, `ticket-document`, `blocker-write`, `ticket-done`. CC uses these to read sprints (read-only token) and write structured comms back to Cowork for mutations.

## Steps

### 1. Run enable

```
/runesmith-sprint:enable
```

Follow the structured prompts. Have these values handy:

- **Jira project key.** Short uppercase identifier, e.g. `ENG`, `BUG`, `INFRA`. You'll see it in URLs like `acme.atlassian.net/browse/ENG-123`.
- **Jira board id.** Numeric id of the scrum/kanban board this project uses. Find it in the board's URL: `acme.atlassian.net/jira/software/projects/ENG/boards/42` → `42`.
- **Confluence space id.** Numeric. Settings → Space Settings → Space details → "Space ID". Not the space key.
- **Default assignee accountId** (optional). Your Atlassian accountId. Find via `atlassianUserInfo` MCP call or in user profile URLs.

### 2. Paste the Project Instructions supplement

The skill ends with a copy-friendly code block. Append to your existing Cowork Project Instructions UI text (don't replace — append below the base content). Save.

The block carries the `<!-- runesmith:atlassian-start/end -->` markers so `/runesmith-sprint:disable` can find and remove it cleanly later.

### 3. Verify

```
/runesmith-jira:project-status
```

Read-only check. Should return your project's active sprint, recent issues, board state. If it errors with `401`, the email + token in `.credentials` don't match. If it errors with `404`, the project key or board id is wrong.

```
/runesmith-confluence:project-overview
```

Drafts a project overview page in markdown locally. Doesn't publish (publish requires the consent trigger phrase). Confirms the Confluence space id resolves.

### 4. First plan-to-tickets conversion

When you have a plan in `plans/active/<slug>/plan.md` ready to execute:

```
/runesmith-sprint:plan-to-tickets
```

The skill walks the plan, drafts Jira ticket JSON for each major work item, writes them to `plans/active/<slug>/tickets/<DRAFT-ID>.json`. **Drafts are local.** Review them on disk.

When you say "push the tickets," drafts POST to Jira, get renamed to `<JIRA-KEY>.json`, and archive to `archive/tickets-pushed/<YYYY-MM>/`. The plan's frontmatter `tickets:` array populates with the Jira keys.

## Disable

```
/runesmith-sprint:disable
```

Removes the `<!-- runesmith:atlassian-start/end -->` block from both CLAUDE.md files. Emits removal instructions for the Project Instructions supplement (you remove manually — the skill can't edit Cowork's UI). Deletes `.atlassian-enabled`. Deletes the CC-side atlassian skill templates.

`.credentials` Atlassian keys are left intact. Removing them is your call.

The workspace reverts to base config. Plans drive work without ticket sync.

## What atlassian-enabled changes about CC

- **CC reads sprints with a read-only token.** No mutation paths from inside CC. Every mutation routes through Cowork via MCP.
- **CC writes structured comms** when it finishes a ticket or hits a blocker: `comms/open/<iso>-<ticket-key>-result.md`, `comms/open/<iso>-<ticket-key>-blocker.md`. Cowork triages on `/runesmith-sprint:check-comms`.
- **Ticket-aware operations.** The deployed CC-side skills know how to look up a ticket by key, read its description and acceptance criteria, attach comments via Cowork-relayed mutations.

CC is NOT given the user's full Atlassian credentials. It has a read-only token scoped to the project. Writes go through Cowork.

## Troubleshooting

**`401` on every Atlassian call.** Email and token must match the account that minted the token. Verify in `.credentials` — `ATLASSIAN_API_EMAIL` is the account; `ATLASSIAN_API_TOKEN` is its token.

**`404` on `/rest/api/3/search`.** Deprecated endpoint. Marketplace skills use `POST /rest/api/3/search/jql`. If you see this, you have an outdated plugin — rebuild from `scripts/build.py` and reinstall.

**`400` on Confluence page create.** Body must be Confluence storage XHTML, not markdown. The marketplace's `runesmith-confluence` skills handle the conversion via `scripts/md-to-storage.py`. If you're calling the API directly, run your markdown through that script first.

**`409` on Confluence page update.** Version conflict — you didn't bump the version number. Skills handle this automatically (GET first, read `version.number`, PUT with `number + 1`).

**Severity custom field rejected on bug-report.** Severity is rarely a default Jira field. Either map to `priority` or set `ATLASSIAN_BUG_SEVERITY_FIELD` in `.credentials` to your tenant's custom field id (e.g. `customfield_10001`).

**`.atlassian-enabled` marker is gone but rules still apply.** The marker is the canonical signal. If skills are still firing atlassian rules without the marker, the marker block in CLAUDE.md wasn't removed cleanly — run `/runesmith-sprint:disable` again or manually remove the `<!-- runesmith:atlassian-start/end -->` content from both CLAUDE.md files.

**Plan-to-tickets writes drafts but won't push.** Push requires an explicit trigger phrase per `plugins/runesmith-sprint/lib/consent.md`. Phrases include "push the tickets", "create the tickets in Jira", "make the tickets". Freeform "go ahead" or "yes" don't work — by design.
