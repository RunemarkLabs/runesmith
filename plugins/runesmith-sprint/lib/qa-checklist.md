# The qa checklist

What the owner checks by hand before a build leaves qa, where he ticks it off, and how the result reaches the gate.

## The source: `qa/checklist.md` in the repo

Claude Code writes and keeps it (head rules). Each item:

```markdown
### {Bold title of a few words}
Build: {the build number that added or last changed it}

**Steps**
1. {one short action}
2. {at most 5}

**Expect**
- {one thing to see}
- {at most 4}

Checked by the owner, {reason}: {why}.
```

- The checker line is either "Checked automatically: the {check} check." or "Checked by the owner, {reason}: {why}.", where the reason is **needs human eyes**, **unsure of the desired behavior** (phrased as the question, with what was built and why) or **couldn't verify** (what blocked it; also an owner action in the reply).
- No sentence over about 20 words, no item over about 80. Longer means two items.
- Only what the qa environment can test. Anything needing beta or production goes in the beta promotion's reply as an owner action.
- Kept current: a change rewrites its item; an item for removed behavior is removed.
- The format is enforced by a build check (runestack-ci when runestack is in use).

## The page: one Claude artifact per project

The owner ticks items off on one artifact page per project, published by the planner from the template `skills/qa-checklist/page.html` in this plugin. It works on a phone and needs nothing from the project's stack.

- **Created** on the project's first promotion to qa. Its id is recorded in the workspace CLAUDE.md, outside the marker sections, as `QA checklist page: {slug}`.
- **Never republished per build.** The page reads its content from the artifact's database; each promotion only writes new data. The page itself is republished only when this template changes.
- **Capabilities:** `{db: {}, user: {}, assets: {}}`. Only the owner and editors write; viewers see a read-only page.

### Data

| Document | Written by | Holds |
|---|---|---|
| `checklist/current` | planner (`db_write`) | `project`, `build`, `target` ("beta"), `items`: `[{key, title, build, steps[], expect[], checker}]`, owner items only |
| `results/{key}` | the page | `state` (`passed` or `failing`), `note`, `shot` (asset id), `build`, `at` |

- **`key`** is the first 16 hexadecimal characters of the SHA-256 of the item's title, steps and expect lines, each trimmed and joined with newlines. Unchanged wording keeps its key, so its pass carries over to the next build. Changed wording gets a new key and starts again.
- Results whose key isn't in the current list are left alone; they come back if the wording returns.

### What the page shows

- **Summary:** build number, passed out of total, a bar of passed, failing and left, and the titles left to test.
- **One card per item:** title and build, Steps, Expect, the checker line, its state, and buttons: **Passes**, **Failing**, **Undo**.
- **Failing** opens a short form: what the owner saw (required) and an optional screenshot, uploaded to the artifact.
- An empty database says no checklist is published yet; a checklist with no owner items says nothing needs his eyes.

## Reading results and the qa gate

On "check comms" after a promotion to qa (`runesmith-sprint:check-comms` step 6):

1. Read `checklist/current` and every `results/{key}` with `db_get` and `db_list`.
2. Record each item's state in the promotion's comm folder and in the plan's `decisions.md`.
3. For each failing item, write a fix task through `runesmith-sprint:task`: the owner's note in "The problem", the screenshot (fetched from the artifact's assets) in `references/`. Claude Code opens the GitHub issue first: labels `bug-report`, `env:qa`, and `component:{name}` when known, with the owner's description and the build number.
4. **The qa gate is clear** when every owner item in `checklist/current` has `passed`, nothing is `failing`, and beta isn't held. Otherwise the planner names what's blocking.
