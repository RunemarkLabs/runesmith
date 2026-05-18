# How-to: Publish Docs to Confluence

The marketplace's `runesmith-confluence` plugin converts markdown to Confluence storage XHTML and publishes pages. Use it for any docs you want mirrored from this repo (or any RuneSmith workspace) into your org's Confluence space.

## Prerequisites

- Workspace has Atlassian enabled, OR you have `ATLASSIAN_API_URL`, `ATLASSIAN_API_EMAIL`, `ATLASSIAN_API_TOKEN`, and a target `ATLASSIAN_CONFLUENCE_SPACE_ID` in `.credentials`.
- The target Confluence space already exists (Confluence Cloud v2 doesn't expose space creation via API — make it via UI first).

## Pick the right skill for the shape of doc

| Skill | Use for |
|---|---|
| `/runesmith-confluence:project-overview` | Landing pages — what the project is, who's on it, current phase |
| `/runesmith-confluence:feature-doc` | Feature specs — what's being built, scope, behavior, acceptance criteria |
| `/runesmith-confluence:architecture-doc` | ADRs — context, decision, consequences, alternatives |
| `/runesmith-confluence:decisions-log` | Append-only running log of project decisions |
| `/runesmith-confluence:known-issues` | Known issues tracker with severity, workaround, status |
| `/runesmith-confluence:roadmap` | Now / Next / Later / Someday phase view |
| `/runesmith-confluence:session-log` | Session summary — decisions, action items, progress |

Each skill knows its target page shape (templates pinned in `plugins/runesmith-confluence/lib/`). Don't try to make `feature-doc` produce a roadmap page — pick the right tool.

## The flow

Every Confluence skill follows the same gate:

1. **Comms check.** Pre-flight; surfaces user-facing comms first.
2. **Resolve `.credentials`** and the target space id.
3. **Gather details.** Structured prompts for the page's specifics (title, parent page id, content sections).
4. **Optionally pull from a plan.** If you're publishing a `feature-doc` for a feature that has a plan, the skill offers to pre-fill from `plans/active/<slug>/plan.md`.
5. **Draft locally to markdown.** Saved to `drafts/project-docs/<slug>/` (or `plans/active/<slug>/refs/` if plan-bound). You review on disk.
6. **Wait for the consent trigger** — "publish the page", "create the document", "ship the doc".
7. **Convert markdown → Confluence storage XHTML** via `scripts/md-to-storage.py`.
8. **POST/PUT to Confluence.**
   - New page: `POST /wiki/api/v2/pages` with the storage XHTML body and the resolved space id.
   - Updated page: GET the current page, read `version.number`, PUT with `number + 1`. Skill handles automatically.
9. **Report the published URL.**

No write without the trigger. No markdown bodies posted to Confluence (the v2 API rejects them as 400).

## Steps for publishing this marketplace's docs

You're reading `docs/` markdown right now. To mirror to Confluence:

### 1. Pick a parent page in your space

In Confluence UI, navigate to the page you want the RuneSmith docs to live under. Note the page id (visible in the URL: `wiki/spaces/<SPACE_KEY>/pages/<PAGE_ID>/...`).

### 2. Publish one doc at a time

For the agent primer:

```
/runesmith-confluence:project-overview
```

Structured prompts:
- Title: "RuneSmith Agent Primer"
- Parent page id: paste the id from step 1
- Content source: structured single-pick — "use existing markdown file" / "draft from scratch"
- Pick "use existing markdown file"
- File path: `docs/AGENT_PRIMER.md`

The skill copies the markdown to `drafts/project-docs/runesmith-agent-primer/` for review, then on consent ("publish the page") converts and posts.

### 3. Repeat for each how-to

```
/runesmith-confluence:feature-doc       → docs/howto/new-workspace.md
/runesmith-confluence:feature-doc       → docs/howto/install-guardrail.md
/runesmith-confluence:feature-doc       → docs/howto/enable-atlassian.md
/runesmith-confluence:feature-doc       → docs/howto/add-repo.md
/runesmith-confluence:feature-doc       → docs/howto/daily-workflow.md
/runesmith-confluence:feature-doc       → docs/howto/migrate-workspace.md
/runesmith-confluence:feature-doc       → docs/howto/publish-to-confluence.md
```

Each gets its own Confluence page under the parent. `feature-doc` is the right shape for how-to content — it's not really a feature spec, but the skill's page template fits the how-to shape (context, walkthrough, considerations).

### 4. Verify

In Confluence UI, navigate to the parent page. All published docs appear as children. Click each, confirm the rendering. Storage XHTML preserves markdown semantics:
- Headings, paragraphs
- Inline + block code (with language hints)
- Tables
- Lists (bulleted, numbered, nested)
- Links (internal and external)
- Emphasis / strong / strikethrough
- Blockquotes
- Horizontal rules

Things that DON'T round-trip cleanly through Confluence storage XHTML:
- Footnotes — converted to inline links
- Complex tables (merged cells, multi-line cells) — best-effort
- Mermaid diagrams — Confluence has its own diagram macro; the marketplace's `md-to-storage.py` doesn't convert Mermaid blocks. Use Confluence's native diagram editor.

## Updating an already-published page

Re-run the same skill against the same title (or page id if you saved it). The skill detects the existing page, GETs current state, computes the version bump, PUTs the new body. Confluence's version history retains every prior revision.

If the page title changed, the skill creates a NEW page instead of updating — Confluence identifies pages by id, not title. Use the page id explicitly to update.

## Publishing the public Runemark docs vs Sapient mirror docs

The public `runemarklabs/runesmith` repo and the private Sapient `sapientindustries/claude-forge` mirror have parallel `docs/` folders with `runesmith-*` / `claude-forge-*` naming respectively. Publish to whichever Confluence space is appropriate:

- Runemark public docs → a Runemark Labs Confluence space (if you have one for the open-source project).
- Sapient internal docs → Sapient's Confluence space.

The marketplace doesn't enforce the split. `ATLASSIAN_API_URL` and `ATLASSIAN_CONFLUENCE_SPACE_ID` in `.credentials` decide which site/space publishes get.

## Troubleshooting

**`400` on page create.** Body must be storage XHTML, not markdown. The marketplace skills handle conversion automatically. If you bypassed the skill and POSTed markdown directly, that's the failure.

**`401` on every Confluence call.** Email + token mismatch in `.credentials`. The token's owning account email goes in `ATLASSIAN_API_EMAIL`.

**`404` on the parent page id.** Wrong id, or the parent is in a different space than `ATLASSIAN_CONFLUENCE_SPACE_ID`. Verify the parent's URL path matches the space.

**`409` on update.** Version conflict. The skill should retry with the latest version automatically; if it doesn't, check `plugins/runesmith-confluence/lib/confluence-format.md` for the canonical version-bump pattern. Possible the page was updated by another user between your GET and PUT.

**Storage XHTML preview renders weird.** Run the markdown through `scripts/md-to-storage.py` standalone first; preview the XHTML output locally before publishing. The script's output is what gets POSTed; if it's wrong, the page will be wrong.

**Mermaid diagrams don't render.** Expected. Use Confluence's native diagram editor or paste a rendered SVG/PNG. The marketplace's md-to-storage converter intentionally doesn't try to translate Mermaid into a Confluence-specific macro (vendor-specific, brittle).

**Page hierarchy doesn't preserve from markdown links.** Confluence's page tree is built from parent-id relationships, not markdown links. Set parent page id explicitly via structured prompt. Internal markdown links (`[text](other-doc.md)`) convert to Confluence links if you publish all docs and the skill resolves the destination page ids — otherwise they're left as relative-path text.
