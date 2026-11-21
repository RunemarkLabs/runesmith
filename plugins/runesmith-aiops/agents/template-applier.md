---
name: template-applier
description: Apply one AIOPS template (token substitution + POST to Confluence) and return the published URL. Used by /runesmith-aiops:bootstrap-aiops to handle each of the six template pages in isolation, with per-template error handling so one failure doesn't blow up the rest of the populate run.
tools: Bash, Read, Write
---

# Template Applier Agent

Subagent invoked once per AIOPS template. The bootstrap-aiops skill calls this agent six times (one per template); each invocation handles one page's substitution + publish in isolation.

## Inputs

Parent skill provides:
- `template_path`: path to the storage-XHTML template, e.g. `templates/01-quick-start.xhtml`
- `target_title`: page title for Confluence, already token-substituted
- `parent_page_id`: optional - the Quick Start page's id (for nesting pages 2-6 under it)
- `tokens`: dict of {COMPANY, SITE, ATLASSIAN_API_URL, SPACE_KEY, SPACE_ID, PROJECT_KEY} resolved values
- `space_id`: Confluence space numeric id (target)
- `replace_existing`: bool - if a page with the same title already exists, replace via PUT instead of erroring
- `credentials`: ATLASSIAN_API_URL, ATLASSIAN_API_EMAIL, ATLASSIAN_API_TOKEN

## Workflow

### 1. Load template

Read `template_path`. The file is already in Confluence storage XHTML format (no markdown conversion needed for AIOPS templates).

### 2. Substitute tokens

Replace every occurrence of `{COMPANY}`, `{SITE}`, `{ATLASSIAN_API_URL}`, `{SPACE_KEY}`, `{SPACE_ID}`, `{PROJECT_KEY}` with the corresponding values from `tokens`.

After substitution, scan for any remaining `{...}` placeholders. If any unresolved token remains, return failure:
```json
{ "success": false, "error": "unresolved_tokens", "tokens": ["{ORG}"] }
```

Never publish a page with placeholder syntax still in it.

### 3. Check for existing page

```
GET {ATLASSIAN_API_URL}/wiki/api/v2/pages?space-id={space_id}&title={URL-encoded title}&status=current
```

If exists:
- If `replace_existing: true` - capture `id` and `version.number`, prepare for PUT
- If `replace_existing: false` - return failure: `{ "success": false, "error": "page_exists", "page_id": "..." }`

If not exists:
- Prepare for POST

### 4. Publish

**POST (new page):**
```
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
{
  "spaceId": "{space_id}",
  "status": "current",
  "title": "{target_title}",
  "parentId": "{parent_page_id}",   // omit for the first page (Quick Start)
  "body": {
    "representation": "storage",
    "value": "{substituted XHTML}"
  }
}
```

**PUT (replace existing):**
```
PUT {ATLASSIAN_API_URL}/wiki/api/v2/pages/{page_id}
{
  "id": "{page_id}",
  "status": "current",
  "title": "{target_title}",
  "version": { "number": <current_version + 1> },
  "body": { "representation": "storage", "value": "{substituted XHTML}" }
}
```

### 5. Return

On success:
```json
{
  "success": true,
  "template": "01-quick-start.xhtml",
  "page_id": "...",
  "url": "{browse url}",
  "title": "...",
  "is_replacement": false
}
```

On failure: structured error with status code, response body, and which step failed. Parent decides whether to continue with remaining templates or abort.

## Guard Rails

- [ ] All required tokens substituted before publish
- [ ] No unresolved `{...}` placeholders in published body
- [ ] Existence check uses space-scoped query (`space-id` param)
- [ ] PUT path: GET version → bump → PUT (handled inline; on 409 retry once with fresh GET)
- [ ] One template = one HTTP request (no batch - keeps failures isolated)
- [ ] Subagent is idempotent - re-running with same inputs and `replace_existing: true` produces consistent results

## Why this is an agent

- `bootstrap-aiops` iterates over 6 templates. Doing each inline keeps the parent context filled with HTTP details and substitution diffs.
- Failure of template #4 (e.g. one token unresolved) shouldn't abort templates #5 and #6 from being published. Parent sees per-template result and decides batch behavior.
- Each agent invocation is small and focused - easier to debug than a single mega-skill that does all six in sequence.

## Error Cases

**Unresolved token after substitution:** Return failure naming the token. Parent typically halts and asks user.
**Page exists, replace_existing false:** Return failure with existing page_id. Parent asks user whether to replace.
**409 on PUT after retry:** Return failure. Parent surfaces and may suggest manual intervention.
**Network failure mid-publish:** Return failure. Parent decides whether to retry this template or skip.
