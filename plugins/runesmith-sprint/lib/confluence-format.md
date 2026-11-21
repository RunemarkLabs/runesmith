# Confluence Body Format

Confluence Cloud v2 API does not accept markdown. All page bodies use the `storage` representation (Confluence XHTML).

A reference Python implementation of these conversion rules ships at `scripts/md-to-storage.py` in the RuneSmith marketplace repo. Skills MAY shell out to it for deterministic conversion, or MAY perform the conversion inline following these rules. Either way, the rules in this file are authoritative.

## Request shape

Create:

```http
POST {ATLASSIAN_API_URL}/wiki/api/v2/pages
Content-Type: application/json

{
  "spaceId": "{SPACE_ID}",
  "status": "current",
  "title": "Page Title",
  "parentId": "{optional parent page id}",
  "body": {
    "representation": "storage",
    "value": "{XHTML storage string}"
  }
}
```

Update (must increment version):

```http
PUT {ATLASSIAN_API_URL}/wiki/api/v2/pages/{page_id}
Content-Type: application/json

{
  "id": "{page_id}",
  "status": "current",
  "title": "Page Title",
  "version": { "number": <existing_version + 1> },
  "body": {
    "representation": "storage",
    "value": "{XHTML storage string}"
  }
}
```

Always GET the page first to read `version.number`, then PUT with `number + 1`. Otherwise → 409 conflict.

## Markdown → storage conversion

Skills draft in markdown for review, then convert before publishing. Supported mappings:

| Markdown | Storage XHTML |
|---|---|
| `# H1` | `<h1>H1</h1>` |
| `## H2` | `<h2>H2</h2>` |
| `### H3` | `<h3>H3</h3>` |
| `**bold**` | `<strong>bold</strong>` |
| `*italic*` | `<em>italic</em>` |
| `` `code` `` | `<code>code</code>` |
| ` ```lang\n...\n``` ` | `<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">lang</ac:parameter><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>` |
| `- item` | `<ul><li>item</li></ul>` |
| `1. item` | `<ol><li>item</li></ol>` |
| `[label](url)` | `<a href="url">label</a>` |
| `> quote` | `<blockquote><p>quote</p></blockquote>` |
| paragraph | `<p>...</p>` |
| `---` | `<hr/>` |
| Table | `<table><tbody><tr><th>...</th></tr><tr><td>...</td></tr></tbody></table>` |

## Macros (storage format)

Info panel:
```xml
<ac:structured-macro ac:name="info"><ac:rich-text-body><p>Body text</p></ac:rich-text-body></ac:structured-macro>
```

Warning panel:
```xml
<ac:structured-macro ac:name="warning"><ac:rich-text-body><p>Body</p></ac:rich-text-body></ac:structured-macro>
```

Status lozenge:
```xml
<ac:structured-macro ac:name="status"><ac:parameter ac:name="colour">Green</ac:parameter><ac:parameter ac:name="title">DONE</ac:parameter></ac:structured-macro>
```

Table of contents:
```xml
<ac:structured-macro ac:name="toc"/>
```

## Escaping

- Escape `<`, `>`, `&` inside `<p>`, `<li>`, `<td>` as `&lt;`, `&gt;`, `&amp;`.
- Inside `<ac:plain-text-body><![CDATA[...]]></ac:plain-text-body>` no escaping needed.
- Storage XHTML must be well-formed XML. Self-close empty elements (`<hr/>`, `<br/>`).

## Page lookup by title

Always scope by space id:

```http
GET {ATLASSIAN_API_URL}/wiki/api/v2/pages?space-id={SPACE_ID}&title={URL-encoded title}&status=current
```

Without `space-id`, results cross spaces and the wrong page may be edited.

## Error handling

| Status | Meaning | Action |
|---|---|---|
| 400 | Bad body / missing field | Validate XHTML, log offending element, abort |
| 401 | Auth failed | Re-read `.credentials`, retry once, then "Run `/runesmith-core:setup`." |
| 403 | No permission | Surface to user, do not retry |
| 404 | Space/page not found | Verify SPACE_ID, abort |
| 409 | Version conflict on PUT | Re-GET version, retry once |
| 429 | Rate limited | Honor `Retry-After` header, retry once |
