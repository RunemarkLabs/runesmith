# runesmith-workspace

Project setup and workspace structure. `/init` is the single entry point for a project.

Part of the [RuneSmith marketplace](https://github.com/runemarklabs/runesmith).

## Skills

- **`/runesmith-workspace:init`**: Interview, workspace layout, `CLAUDE.md`, `STRUCTURE.md` and Project Instructions; for code projects, the Claude Code head through `runesmith-cc:head`. Safe to re-run.
- **`/runesmith-workspace:inbox`**: Classify files dropped in `_INBOX/` and route them on approval.
- **`/runesmith-workspace:reallocate`**: Pointer to `init` for this release.

## Install

```
/plugin marketplace add runemarklabs/runesmith
/plugin install runesmith-workspace@runesmith
```

Or build the `.plugin` files with `python scripts/build.py` and drag them from `dist/` into the Claude desktop plugin sidebar.

## Configure

Needs `runesmith-core`. Code projects also need `runesmith-cc` and `runesmith-sprint`.

## License

Apache-2.0. See `LICENSE`.
