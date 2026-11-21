# runesmith-jira

Jira tickets and projects over the Cloud REST API.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-jira:ticket`**: Draft and push a Task, Story, Bug or Epic.
- **`/runesmith-jira:bug-report`**: Document a bug, optionally with a Confluence page, and create the ticket.
- **`/runesmith-jira:project-status`**: Read the board and recent issues.
- **`/runesmith-jira:new-project`**: Scaffold a project in Jira and Confluence.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-jira@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Needs the planner's Atlassian keys in the workspace `.credentials`.

## License

Apache-2.0. See `LICENSE`.
