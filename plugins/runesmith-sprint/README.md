# runesmith-sprint

The planner and builder loop, with optional Jira wiring.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-sprint:task`**: Write a task comm with Acceptance and give the `/goal` line for Claude Code.
- **`/runesmith-sprint:check-comms`**: Verify Claude Code's replies against the repository, archive finished work, and give the next goal line.
- **`/runesmith-sprint:promote`**: Move a build from `dev` to `qa` to `beta` to `main`, only on the owner's word.
- **`/runesmith-sprint:qa-checklist`**: Publish and read the project's QA checklist page.
- **`/runesmith-sprint:enable`**: Turn on Jira and Confluence for the project.
- **`/runesmith-sprint:disable`**: Turn them off again, keeping comms, plans and credentials.
- **`/runesmith-sprint:start-sprint`**: Turn the active Jira sprint into task comms.
- **`/runesmith-sprint:sprint-status`**: Show the board and open comms. Writes nothing.
- **`/runesmith-sprint:plan-to-tickets`**: Draft Jira tickets from a plan and push them on approval.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-sprint@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Needs a Claude Code head for the loop. The Jira skills need the planner's Atlassian keys; Claude Code's read-only token goes in `{PROJECT}.cc/.credentials`.

## License

Apache-2.0. See `LICENSE`.
