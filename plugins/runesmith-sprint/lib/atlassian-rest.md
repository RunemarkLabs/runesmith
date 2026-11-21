# Atlassian REST - canonical endpoints

All Jira/Confluence calls in this marketplace use these exact endpoints. No deprecated paths.

Base: `{ATLASSIAN_API_URL}`. Auth: see `credentials.md`. Body format: see `confluence-format.md`.

## Jira Cloud (REST v3)

### Issues

Create:
```
POST /rest/api/3/issue
{
  "fields": {
    "project": { "key": "{PROJECT_KEY}" },
    "issuetype": { "name": "Task" | "Story" | "Bug" | "Epic" },
    "summary": "...",
    "description": {ADF document},
    "labels": ["..."],
    "assignee": { "accountId": "{LEAD_ACCOUNT_ID}" },
    "priority": { "name": "High" }
  }
}
```

`description` must be Atlassian Document Format (ADF), not plain string. Minimal ADF:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    { "type": "paragraph", "content": [{ "type": "text", "text": "body text" }] }
  ]
}
```

Get:
```
GET /rest/api/3/issue/{issueIdOrKey}
```

Update:
```
PUT /rest/api/3/issue/{issueIdOrKey}
{ "fields": { ... } }
```

Transition (status change):
```
GET  /rest/api/3/issue/{issueIdOrKey}/transitions  (list transition ids)
POST /rest/api/3/issue/{issueIdOrKey}/transitions
{ "transition": { "id": "{id}" } }
```

### Search (JQL)

```
POST /rest/api/3/search/jql
{
  "jql": "project = {PROJECT_KEY} ORDER BY updated DESC",
  "fields": ["summary", "status", "assignee", "priority", "labels"],
  "maxResults": 50,
  "nextPageToken": null
}
```

`/rest/api/3/search` (GET) is deprecated on Cloud. Always use `/search/jql` POST.

### Projects

List:
```
GET /rest/api/3/project/search
```

Get:
```
GET /rest/api/3/project/{projectIdOrKey}
```

Create (admin only):
```
POST /rest/api/3/project
{
  "key": "{PROJECT_KEY}",
  "name": "...",
  "projectTypeKey": "software" | "business" | "service_desk",
  "projectTemplateKey": "com.pyxis.greenhopper.jira:gh-simplified-kanban-classic",
  "leadAccountId": "{LEAD_ACCOUNT_ID}"
}
```

Project creation requires Jira admin permissions. Surface required perms before attempting.

### Accounts

Lookup user by email:
```
GET /rest/api/3/user/search?query={email}
```

Returns `accountId` for use in `assignee.accountId` and `leadAccountId`.

### Custom field discovery

```
GET /rest/api/3/field
```

Use this to find Severity, Story Points, Epic Link custom field ids. Severity is rarely a default field; map to `priority` unless `ATLASSIAN_BUG_SEVERITY_FIELD` is set.

## Confluence Cloud (REST v2)

### Pages

Create:
```
POST /wiki/api/v2/pages
```
Body: see `confluence-format.md`.

Get by id:
```
GET /wiki/api/v2/pages/{id}?body-format=storage
```

Lookup by title (always pass `space-id`):
```
GET /wiki/api/v2/pages?space-id={SPACE_ID}&title={URL-encoded}&status=current
```

Update (must increment version):
```
PUT /wiki/api/v2/pages/{id}
```
See `confluence-format.md`.

Delete (move to trash):
```
DELETE /wiki/api/v2/pages/{id}
```

Children:
```
GET /wiki/api/v2/pages/{id}/children
```

### Spaces

List:
```
GET /wiki/api/v2/spaces
```

Get:
```
GET /wiki/api/v2/spaces/{id}
```

Pages in space:
```
GET /wiki/api/v2/spaces/{id}/pages
```

Create: not exposed on v2 public API. v1 `/wiki/rest/api/space` POST works but requires Confluence admin. Skills MUST treat space as a precondition (already exists). For new tenants, instruct user to create the space in Confluence UI first.

### Comments

Inline / footer comments on pages:
```
POST /wiki/api/v2/footer-comments
POST /wiki/api/v2/inline-comments
```

## Common patterns

### Pagination

v2 uses `cursor`-based pagination via `Link` header `rel="next"`. v3 search uses `nextPageToken` in body.

### Idempotency

Atlassian REST is not idempotent. Skills must:
- For create: check existence first (e.g., page lookup by title) and ask user before creating duplicate.
- For update: GET → bump version → PUT.

### Required precondition documentation

Each skill that calls these endpoints must list in its Pre-Flight Checks:
- Required `.credentials` keys
- Required existing space/project
- Required user permissions
