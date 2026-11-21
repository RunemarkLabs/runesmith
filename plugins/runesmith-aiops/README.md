# runesmith-aiops

Populates an AI Operations Confluence space from template pages.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-aiops:bootstrap-aiops`**: Substitute `{COMPANY}`, `{SITE}`, `{SPACE_KEY}`, `{SPACE_ID}` and `{PROJECT_KEY}` into the templates and publish them. The space must already exist.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-aiops@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Needs the planner's Atlassian keys.

## License

Apache-2.0. See `LICENSE`.
