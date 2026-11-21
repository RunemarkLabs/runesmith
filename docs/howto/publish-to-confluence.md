# How-to: Publish Docs to Confluence

The `runesmith-confluence` plugin drafts pages in markdown, converts them to Confluence storage format, and publishes them on your approval.

## Prerequisites

- The planner's Atlassian keys in `{WORKSPACE_ROOT}/.credentials` (`ATLASSIAN_API_URL`, `ATLASSIAN_API_EMAIL`, `ATLASSIAN_API_TOKEN`), and a target space: either Jira enabled for the project or `ATLASSIAN_CONFLUENCE_SPACE_ID` set.
- The space exists. The Cloud API can't create spaces; make it in Confluence first.

## Pick the skill for the page

| Skill | Use for |
|---|---|
| `/runesmith-confluence:project-overview` | Landing page: what the project is, who's on it, current phase |
| `/runesmith-confluence:feature-doc` | Feature spec: scope, behavior, acceptance; also fits how-to pages |
| `/runesmith-confluence:architecture-doc` | Architecture decision record: context, decision, consequences, alternatives |
| `/runesmith-confluence:decisions-log` | Running log of decisions |
| `/runesmith-confluence:known-issues` | Known issues with severity, workaround and status |
| `/runesmith-confluence:roadmap` | Now, Next, Later, Someday |
| `/runesmith-confluence:session-log` | Session summary: decisions, actions, progress |

## The flow

1. Check comms and surface anything addressed to you.
2. Resolve the credentials and the space.
3. Ask for the page details (title, parent page, sections) through structured prompts.
4. Offer to prefill from a plan in `plans/active/{slug}/`.
5. Draft the markdown to `drafts/project-docs/{slug}/` (or the plan's `refs/`) for you to review.
6. Ask for approval with a structured prompt: **Publish** (recommended) or **Keep as draft**.
7. Convert to storage format with `scripts/md-to-storage.py`.
8. Create the page (`POST /wiki/api/v2/pages`), or update it: read the current `version.number` and send the next number.
9. Report the link.

Nothing is written without your approval, and markdown is never sent as a page body.

## Publishing existing markdown

To mirror files you already have (this repo's `docs/`, for example):

1. Find the parent page in Confluence and note its id from the address (`/wiki/spaces/{SPACE_KEY}/pages/{PAGE_ID}/...`).
2. Run the matching skill, give the title and parent id, and choose to use an existing markdown file. Give its path.
3. Review the draft copy, then approve.

Repeat per file. `project-overview` suits a primer; `feature-doc` suits a how-to.

## What converts cleanly

Headings, paragraphs, inline and block code (with language), tables, lists (nested too), links, emphasis, quotes and rules.

Not cleanly:
- Footnotes become inline links.
- Merged or multi-line table cells are best effort.
- Mermaid blocks aren't converted. Use Confluence's own diagram tools or paste an image.

## Updating a page

Run the same skill with the same title or the page id. It reads the current page and sends the next version; Confluence keeps every earlier version. A changed title creates a new page, because Confluence identifies pages by id: give the id to update.

## Which site and space

`ATLASSIAN_API_URL` and the space id decide where pages go. Publishing for another organization means that organization's keys in that workspace's `.credentials`; RuneSmith never mixes them.

## Troubleshooting

**400 on create.** The body wasn't storage format. Use the skill, or convert with `scripts/md-to-storage.py` first.

**401 on every call.** The email and token must belong to the same account.

**404 on the parent page.** Wrong id, or the parent is in a different space.

**409 on update.** Someone changed the page between the read and the write. Run the skill again.

**The page renders oddly.** Run `scripts/md-to-storage.py` on the markdown and look at the output; that output is exactly what gets published.

**Links between docs don't resolve.** Confluence builds its tree from parent ids, not markdown links. Relative links become Confluence links only when the target page has been published and can be found.
