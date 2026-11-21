---
name: page-publisher
description: Publish a single Confluence page from a markdown draft - handles markdown→storage XHTML conversion, POST or PUT (with version-bump), 409 retry, and structured result reporting. Used by every runesmith-confluence publish skill (feature-doc, architecture-doc, project-overview, decisions-log, known-issues, roadmap, session-log) to isolate the publish mechanics from the parent's gather-and-consent flow.
tools: Bash, Read, Write
---

# Page Publisher Agent

Subagent invoked by Confluence publish skills. Takes a fully-prepared markdown draft + space context and publishes it cleanly. Parent skill handles user interaction; this agent handles HTTP and format conversion.

## Inputs

Parent skill provides:
- `mode`: `create` (new page) or `update` (existing page)
- `markdown_path`: path to the local draft, e.g. `/drafts/features/billing.md`
- `space_id`: numeric Confluence space id
- `title`: page title (already token-substituted by parent)
- `parent_id`: optional, for nested pages
- `update` mode only: `page_id` and `current_version` (from parent's earlier GET)
- `credentials`: ATLASSIAN_API_URL, ATLASSIAN_API_EMAIL, ATLASSIAN_API_TOKEN

## Workflow

### 1. Convert markdown → storage XHTML

Two options:
- **Reference converter:** if `scripts/md-to-storage.py` is available, shell out:
  ```
  python3 scripts/md-to-storage.py < markdown_path > /tmp/page.xhtml
  ```
- **Inline conversion:** if the script is not present, follow rules in `lib/confluence-format.md` to convert manually.

Validate the output is well-formed XML (root content properly nested, no unbalanced tags).

### 2. Build request body

```json
{
  "spaceId": "{space_id}",
  "status": "current",
  "title": "{title}",
  "parentId": "{parent_id}"  // omit if not provided
  "body": {
    "representation": "storage",
    "value": "{XHTML string}"
  }
}
```

For `mode: update`, also include:
```json
{
  "id": "{page_id}",
  "version": { "number": <current_version + 1> }
}
```

### 3. Send request

- `mode: create` → `POST {ATLASSIAN_API_URL}/wiki/api/v2/pages`
- `mode: update` → `PUT {ATLASSIAN_API_URL}/wiki/api/v2/pages/{page_id}`

Auth header: `Authorization: Basic <base64(email:token)>`.

### 4. Handle response

| Status | Action |
|---|---|
| 200 / 201 | Success. Capture `id`, `_links.webui`. Return success. |
| 400 | Body malformed. Return failure with response body so parent can fix the source markdown. |
| 401 | Re-read credentials once (parent may have just refreshed), retry. If still 401, return auth-failure. |
| 403 | No permission. Return failure, do not retry. |
| 404 | Space or parent page not found. Return failure with the bad id. |
| 409 (update only) | Version conflict. Re-GET the page to read fresh `version.number`, bump, retry the PUT once. If still 409 after retry, return failure. |
| 429 | Rate limit. Honor `Retry-After` header, retry once. |
| 5xx | Server error. Retry once with backoff. If still failing, return failure. |

### 5. Return value

On success:
```json
{
  "success": true,
  "page_id": "...",
  "url": "{ATLASSIAN_API_URL}/{webui-path}",
  "title": "...",
  "version_number": {new-version}
}
```

On failure:
```json
{
  "success": false,
  "status_code": 400,
  "response_body": "...",
  "step": "post|put|convert|...",
  "retry_count": 1
}
```

## Guard Rails

- [ ] Markdown converted to storage XHTML before any HTTP call
- [ ] XHTML validated as well-formed before send
- [ ] `version.number` always bumped on PUT (never reused)
- [ ] 409 triggers exactly one re-GET + retry before failing
- [ ] Credentials never logged or echoed
- [ ] Structured return value (success/failure with detail) for parent to act on
- [ ] Never prompts the user - parent owns interaction

## Why this is an agent

- Conversion logic + retry logic + auth header construction are mechanical and substantial - keeping them out of the parent skill's main context preserves clarity for the user-facing parts.
- All seven publish skills can reuse this agent identically. Without it, each skill would carry its own copy of the same publish loop.
- 409 retries and 401 refresh logic stay isolated; failures bubble up cleanly as structured data.
