# runesmith-cc

The Claude Code head (`{PROJECT}.cc/`) and the project-boundary guardrail.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-cc:head`**: Build or refresh the head: builder rules, settings (no attribution, stop hook cap of 3, code-simplifier), comms folders, the `runesmith-clean-code`, `runesmith-code-tech-debt` and `runesmith-release` skills, repos, and the `dev`, `qa` and `beta` branches.
- **`/runesmith-cc:guardrail`**: Copy the one-shot installer that keeps every Claude Code session inside its project; install, verify or uninstall.
- **`/runesmith-cc:bootstrap-cc`**: Pointer to `head` for this release.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-cc@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Usually run through `/runesmith-workspace:init`. Creating repos needs `RUNESMITH_GITHUB_PAT` in the workspace `.credentials`.

## License

Apache-2.0. See `LICENSE`.
