---
name: new-project
description: "Scaffold a new project in Confluence and Jira. Use when the user says \"new project\", \"set up a project\", \"create a project\", \"scaffold\", or wants to initialize Confluence and Jira for a new codebase. Also triggers on \"start a new repo\", \"project setup\", or \"initialize project\"."
compatibility: Runs in the planner chat with the project's workspace folder connected.
---

# New Project Setup

Scaffold a new project across Confluence and Jira.

Note: project and space creation require Atlassian admin permissions. Without admin rights, this skill detects the missing perms early and falls back to "use existing space + project" mode.

## References

- `lib/atlassian-rest.md`
- `lib/confluence-format.md`
- `lib/credentials.md`
- `lib/consent.md`
- `lib/tokens.md`
- `lib/comms-check.md` - runs first
- Sibling skills: `project-overview`, `roadmap`, `known-issues`, `architecture-doc`
- `lib/user-prompts.md` - structured-input requirement for any user prompt


## User input rules

This skill follows the marketplace-wide user-prompt standard in `lib/user-prompts.md`. Every user prompt MUST use the host client's structured input UI (single-pick, multi-pick, or text-input form). Never freeform plain-text yes/no questions. The only exception is the consent-trigger gate documented in `lib/consent.md`, which waits for user-initiated phrases like "make the ticket".

## Pre-Flight Checks

### 0. Comms check (always first)

See `lib/comms-check.md`. Pause for `to: user` items.

1. Credentials resolved.
2. Permissions check:
   - Jira: `GET /rest/api/3/mypermissions?permissions=ADMINISTER` → look for `ADMINISTER.havePermission == true`.
   - Confluence: space-create perm is admin-only on Cloud; v2 API does not expose space creation. Detect by attempting v1 `POST /wiki/rest/api/space` only after explicit user confirmation.
3. If admin missing → switch to "existing-resources" mode and ask for existing `{SPACE_ID}` and `{PROJECT_KEY}`.

## When to Use

Use for:
- New team initiative needing both Jira project + Confluence space
- Adding initial documentation skeleton

Do not use for:
- Adding to existing projects (use individual skills)
- Renaming / restructuring (use Jira/Confluence UIs)

## Workflow

### 1. Gather details

- Project / product name
- Project key (3-10 uppercase chars; Jira validates)
- Space key (typically same as project key)
- Description
- Project lead email → resolve to `{LEAD_ACCOUNT_ID}` via `GET /rest/api/3/user/search?query={email}`
- Project type: software | business | service_desk
- Project template: e.g. `com.pyxis.greenhopper.jira:gh-simplified-kanban-classic`

### 2. Get consent

"Create Jira project {PROJECT_KEY} and Confluence space {SPACE_KEY}?" - wait for trigger phrase.

### 3a. Create Jira project (admin only)

```
POST {ATLASSIAN_API_URL}/rest/api/3/project
{
  "key": "{PROJECT_KEY}",
  "name": "{name}",
  "projectTypeKey": "software",
  "projectTemplateKey": "com.pyxis.greenhopper.jira:gh-simplified-kanban-classic",
  "leadAccountId": "{LEAD_ACCOUNT_ID}",
  "description": "{description}"
}
```

Capture `id` and `key` from response.

### 3b. Create Confluence space (admin only, v1 endpoint)

```
POST {ATLASSIAN_API_URL}/wiki/rest/api/space
{
  "key": "{SPACE_KEY}",
  "name": "{name}",
  "description": { "plain": { "value": "{description}", "representation": "plain" } }
}
```

Capture `id`. (v2 API has no space-create endpoint as of writing.)

### 4. Initialize pages

For each, call sibling skill workflow with prefilled details and the new `{SPACE_ID}`:
- `project-overview` → "Project Overview"
- `roadmap` → "Roadmap" (Now / Next / Later / Someday scaffold)
- `known-issues` → "Known Issues" (empty table)
- `architecture-doc` → "Architecture Overview" (empty ADR index)

Each page-create inherits the consent state from this workflow's main consent. Do not re-prompt for each.

### 5. Cross-link

- Add Jira project sidebar link to Confluence space (manual instruction; Atlassian doesn't expose this via API consistently).
- In Confluence overview page, link to Jira project URL.

### 6. Report

```
✓ Project initialized
Jira: {PROJECT_KEY} → {ATLASSIAN_API_URL}/jira/software/projects/{PROJECT_KEY}
Confluence: {SPACE_KEY} → {ATLASSIAN_API_URL}/wiki/spaces/{SPACE_KEY}
Pages: Project Overview, Roadmap, Known Issues, Architecture Overview
```

## Guard Rails

- [ ] Permissions check before write attempts
- [ ] Project key 3-10 uppercase, unique
- [ ] Lead resolved to `accountId`
- [ ] Consent trigger received
- [ ] Both creates succeed before page init
- [ ] Initial pages published successfully
- [ ] No credentials echoed

## Error Cases

**Jira 403:** "Need Jira admin to create projects. Switch to existing-project mode?"
**Jira 400 - key in use:** "Project key {PROJECT_KEY} already exists. Pick another."
**Confluence 403 on space create:** Same as above for Confluence admin.
**Lead lookup empty:** "No user found for that email. Use a different email or set `ATLASSIAN_DEFAULT_ASSIGNEE_ACCOUNT_ID`."
**Partial failure (Jira created, Confluence failed):** Report what succeeded, prompt to retry Confluence or roll back Jira manually.
