# User Prompts - Standard

Every RuneSmith skill that asks the user a question MUST use the host client's structured input UI, never freeform plain-text questions. This is a marketplace-wide invariant.

## The rule

When a skill needs user input:

| User-input type | What to use |
|---|---|
| Pick one of N options | **Structured single-pick form** (e.g. AskUserQuestion in Cowork with `multiSelect: false`) |
| Pick multiple of N options | **Structured multi-pick form** (`multiSelect: true`) |
| Type a value (name, URL, slug) | **Structured text-input form** with default pre-populated |
| Confirm an action | **Structured single-pick form** with `Apply` / `Preview` / `Cancel` options (or similar) |

Never use plain-text "yes/no", "[y/n]", "Proceed?", "Ready to ...?" or free-form prompts that require the user to type their response in chat.

## Why

- **Mobile and screen-reader users** can't type quickly or reliably. Structured forms map to native UI affordances.
- **Cowork's chat surface treats free-form questions ambiguously** - the user's next message may or may not be a response. Structured prompts have explicit response slots.
- **Auditability** - structured selections are recorded as discrete choices, not buried in chat scrollback.
- **Defaults** - structured forms can pre-fill the most-likely answer (e.g. normalized name preview), letting the user accept with a click.

## One question at a time

Ask one question per dialog, always (Ben, 2026-11-22). Never put two or more questions in the same form, even when the tool allows several. Ask the first, wait for the answer, then ask the next. Later questions often change or disappear once the first is answered; ask only the ones still needed.

## Drafts the owner approves

Anything the owner is asked to approve (a description, a CLAUDE.md section, a Project Instructions block, a plan, a ticket, a page, a table of moves) must be visible in full before he answers, and must stay visible while he answers.

- Put the draft itself in the question text, inside a fenced code block, under a one-line heading that says what it is ("Project description, written into CLAUDE.md and the Project Instructions:"). Never only refer to "this draft" or "the draft above": text written before a question may not be shown, or may be hidden by the question box.
- A draft too long for the question (a full CLAUDE.md section, a Project Instructions block): send it first as a message the owner reads verbatim (in hosts that have one, the send-message tool), then ask "Use the {name} shown above?".
- Changes come through the dialog's own text box. Apply what he types, show the new draft the same way, and ask again. Never make him retype the whole draft.

## Never end with a plain-text reply list

Every open item that needs the owner's answer is a structured question. Never end a turn with "Reply with: 1. ... 2. ..." for him to type. A question that depends on a table or draft carries it (above).

## Never add an edit option

The question dialog already has a free-text box for anything not listed. Never add an option that only opens text entry: no "Edit", "Change it", "Edit first", "Other", "Something else", "Custom" or "Type your own". It duplicates the box and confuses the owner. Every option must be a real answer. When the tool needs two options and there is only one real answer, offer a second real alternative (a second wording, or skipping the step), never an edit option.

## Exception: consent trigger phrases for writes

Per `consent.md`, write skills wait for explicit trigger phrases like "make the ticket" or "publish the page" before mutating Atlassian/Jira state. **This is not a freeform question** - it's a designed wait-for-user-intent gate where the user proactively states intent.

The skill does NOT prompt with a question first. It simply pauses and waits for the trigger phrase, or surfaces a single-pick structured prompt asking "Push this draft now?" with options `Push` / `Cancel`; changes are typed in the dialog's text box.

A consent trigger phrase IS valid for confirming a single prepared action. It is NOT valid as a substitute for collecting multi-field input.

## Pattern examples

### Confirming an action (structured single-pick)

```
Question: "Apply this migration?"
Header: "Confirm migration"
Options:
  - "Apply" (description: Move files per the plan, snapshot first)
  - "Preview only" (description: Show diff, no writes)
  - "Cancel" (description: Abort)
```

### Picking from N items (structured single-pick)

```
Question: "Which repo should be the primary?"
Header: "Primary repo"
Options:
  - "acme-frontend" (description: React/Vite, 1,247 commits)
  - "acme-backend"  (description: Go, 893 commits)
  - "acme-infra"    (description: Terraform, 312 commits)
```

### Collecting a typed value (structured text-input with default)

```
Question: "Name for the new repo? (will be normalized to kebab-case-lowercase)"
Header: "Repo name"
Default: "my-new-repo"   ← pre-populated, user edits or accepts
```

### Multi-select (structured multi-pick)

```
Question: "Which starter skills should be deployed?"
Header: "Starter skills"
multiSelect: true
Options:
  - "code-reviewer"
  - "test-runner"
  - "explorer"
  - "security-scanner"
```

## What this means for SKILL.md authoring

When writing a skill that asks the user something, document the prompt as:

```markdown
### N. Get user input - structured prompt

Surface a structured single-pick prompt:
- Question: "..."
- Options: A, B, C (with descriptions)
- Default: A
```

Never write:

```markdown
Ask: "Are you sure? (yes/no)"
```

Or:

```markdown
Wait for the user to type "yes" or "no".
```

## When the host client doesn't support structured forms

If running in a plain-text-only environment (rare):
- Fall back to a numbered-list prompt: `1) Apply  2) Preview  3) Cancel`
- Accept the number or matching keyword
- Default to the safest option on ambiguous input (usually Cancel)

This is a fallback, not the primary path. The primary path is always structured forms.

## Skills that follow this rule

All runesmith-* skills cite this doc. New skills MUST cite it. Existing skills are being audited and updated to remove plain-text prompts.

See also: `consent.md` (trigger-phrase rules for writes), `comms-check.md` (check-on-entry pattern).
