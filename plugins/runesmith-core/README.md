# runesmith-core

Foundation plugin: credentials, plugin install and sync, and planning before writes.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-core:plan`**: Discuss a change, check open issues, and write `plans/active/{slug}/plan.md` and `decisions.md`.
- **`/runesmith-core:setup`**: Set up the planner's `.credentials` blocks and run health checks. Never asks for a secret in chat.
- **`/runesmith-core:install`**: Browse and install plugins from this marketplace and extra sources.
- **`/runesmith-core:sync`**: Update installed plugins and refresh the AI Operations templates.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-core@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Install this first. `/runesmith-workspace:init` runs setup when keys are missing.

## License

Apache-2.0. See `LICENSE`.
