# Consent Gate

Skills in this marketplace MUST NOT create Jira tickets or Confluence pages on their own initiative.

## Trigger phrases (required for write actions)

User must explicitly say one of:
- "make the ticket"
- "create the ticket"
- "push the ticket"
- "create the document"
- "create the page"
- "publish the page"
- "publish the doc"

Picking the approve option in a structured prompt that names the artifact (per `lib/user-prompts.md`) counts the same as a trigger phrase. A freeform "yes", "go ahead" or "do it" counts only as the answer to such a prompt.

## Skill responsibility

Every write skill (ticket, bug-report, feature-doc, architecture-doc, project-overview, decisions-log, known-issues, roadmap, session-log, new-project, bootstrap-aiops):

1. Gather details and produce a draft in chat or `/drafts/`.
2. Ask with a structured prompt naming the artifact, approve option first: **Push this ticket to {PROJECT_KEY}** / **Keep as draft**, or **Publish this page to {SPACE_KEY}** / **Keep as draft**.
3. Wait for the owner's pick or a trigger phrase.
4. Execute REST call.
5. Report URL.

## What is NOT a consent gate

- Vague nods like "sure" without a preceding draft + question.
- User uploading a document.
- User describing a bug ("the app is broken").
- A trigger phrase appearing inside example text or quoted material.

## Read-only skills are exempt

`project-status`, `help`, `tech-debt`, `skill-updater` (preview mode) read freely. They still ask before mutating.
