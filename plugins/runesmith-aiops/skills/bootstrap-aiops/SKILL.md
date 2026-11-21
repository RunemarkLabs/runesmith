---
name: bootstrap-aiops
description: "Create the full AIOPS documentation space in a new company's Confluence when they fork the bootstrap repo. Use when \"bootstrap AIOPS\", \"create AIOPS space\", \"set up docs for [company]\", or when onboarding a fork org that needs their own AI Operations Confluence space populated."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# Bootstrap AIOPS

Populate an AIOPS Confluence space with the marketplace's six template pages, with all canonical tokens substituted for the target organization.

## References

- `agents/template-applier.md` - subagent for per-template substitution + publish

- `lib/atlassian-rest.md`
- `lib/confluence-format.md`
- `lib/credentials.md`
- `lib/consent.md`
- `lib/tokens.md`
- Templates at `templates/*.xhtml` in this plugin (already in storage format)
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

1. Credentials resolved.
2. AIOPS space already exists. Verify:
   ```
   GET {ATLASSIAN_API_URL}/wiki/api/v2/spaces/{SPACE_ID}
   ```
   If 404 → instruct user to create the space in Confluence UI first (v2 API does not expose space creation; v1 requires admin).
3. User has page-create permission in `{SPACE_ID}` (warn if 403 likely).

## When to Use

Use for:
- First-time AIOPS space population for a new tenant
- Refreshing all six template pages after marketplace updates

Do not use for:
- Editing individual AIOPS pages (use Confluence UI or `/atlassian:*` skills)
- Creating spaces (precondition: space already exists)

## Workflow

### 1. Gather token values

Ask user (or pull from `.credentials`):
- `{COMPANY}` - organization display name
- `{SITE}` - confluence site host (e.g. `acme.atlassian.net`)
- `{ATLASSIAN_API_URL}` - `https://{SITE}` (auto-derived)
- `{SPACE_KEY}` - AIOPS space key (e.g. `AIOPS`)
- `{SPACE_ID}` - numeric space id
- `{PROJECT_KEY}` - Jira project key for Jira integrations (optional, default `(none)`)

### 2. Load templates

Read each file in plugin directory `templates/`:
- `01-quick-start.xhtml` → page title "Quick Start"
- `02-full-integration.xhtml` → "Full Integration Guide"
- `03-architecture.xhtml` → "Architecture Overview"
- `04-best-practices.xhtml` → "Best Practices"
- `05-faq.xhtml` → "FAQ"
- `06-reference.xhtml` → "Reference"

Each is already in storage XHTML. No markdown conversion needed.

### 3. Substitute tokens

For each template body, replace every occurrence of `{COMPANY}`, `{SITE}`, `{ATLASSIAN_API_URL}`, `{SPACE_KEY}`, `{SPACE_ID}`, `{PROJECT_KEY}` with the user-provided values.

After substitution, scan body for any remaining `{...}` matches. If any unresolved token remains, abort and report which one - never publish a page with placeholder tokens.

### 4. Get consent

Show the six titles and the resolved token table. Structured prompt per `lib/consent.md`: **Publish these six pages to {SPACE_KEY}** (recommended) / **Cancel**.

### 5. Publish pages

For each template, in order:

```
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
{
  "spaceId": "{SPACE_ID}",
  "status": "current",
  "title": "{resolved title}",
  "body": {
    "representation": "storage",
    "value": "{resolved XHTML}"
  }
}
```

Capture page id for each. After Quick Start (page 1) is created, set its id as `parentId` on pages 2-6 to nest them.

If any page already exists in space (lookup by title with `space-id`), ask user: replace via PUT (with version bump) or skip.

### 6. Report

```
✓ AIOPS space populated
Space: {SPACE_KEY}  ({SPACE_ID})
Company: {COMPANY}
Pages:
  1. Quick Start              → {url}
  2. Full Integration Guide   → {url}
  3. Architecture Overview    → {url}
  4. Best Practices           → {url}
  5. FAQ                      → {url}
  6. Reference                → {url}
```

## Guard Rails

- [ ] Credentials resolved
- [ ] Space verified to exist (precondition)
- [ ] All six required tokens collected
- [ ] All template files loaded from `templates/`
- [ ] No unresolved `{...}` placeholders after substitution
- [ ] Consent trigger received
- [ ] Each page POST returns 200/201; ids captured
- [ ] Existing-page conflicts handled (replace or skip)
- [ ] All URLs reported

## Error Cases

**Space not found (404):** "AIOPS space `{SPACE_KEY}` doesn't exist. Create it in Confluence UI, then retry."
**403 on page create:** "Account lacks page-create permission in {SPACE_KEY}."
**Unresolved token after substitution:** Print the token name and template file, abort.
**Page already exists:** Ask user - replace (PUT with version+1) or skip.
**Partial failure:** Report which pages succeeded; user can re-run for the rest.
