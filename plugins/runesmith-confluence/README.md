# runesmith-confluence

Confluence pages drafted in markdown and published in storage format.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-confluence:project-overview`**: Project landing page.
- **`/runesmith-confluence:feature-doc`**: Feature specification.
- **`/runesmith-confluence:architecture-doc`**: Architecture decision record or overview.
- **`/runesmith-confluence:decisions-log`**: Running decisions log.
- **`/runesmith-confluence:known-issues`**: Known issues and tech debt tracker.
- **`/runesmith-confluence:roadmap`**: Roadmap page.
- **`/runesmith-confluence:session-log`**: Session summary.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-confluence@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Needs the planner's Atlassian keys and a target space.

## License

Apache-2.0. See `LICENSE`.
