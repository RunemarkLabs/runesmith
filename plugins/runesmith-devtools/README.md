# runesmith-devtools

Tools for plugin authors.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-devtools:help`**: List installed plugins and skills with their triggers.
- **`/runesmith-devtools:plugin-builder`**: Scaffold a new plugin.
- **`/runesmith-devtools:tech-debt`**: Find stale or orphaned files in the workspace and act on approval.
- **`/runesmith-devtools:skill-updater`**: Carry a convention change into every skill and shared library copy.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-devtools@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

No credentials needed.

## License

Apache-2.0. See `LICENSE`.
