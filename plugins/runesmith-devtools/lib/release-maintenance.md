# Release maintenance (HARD RULES)

Once a plugin is published in a marketplace, every subsequent change follows these rules. They are NOT optional. The plugin-builder skill scaffolds plugins that comply on day one; ongoing maintenance must too.

Cross-references the full rationale and per-bump checklist in `build-and-audit.md`. This file restates the rules in one place for quick reference and citation from the plugin-builder workflow.

## 1. Per-plugin versioning, no blanket bumps

Each plugin has its own independent SemVer track. When a release touches some plugins but not others, ONLY the changed plugins bump. Never blanket-bump all plugins to the same version because you're cutting a marketplace release.

**Wrong:**
```
v0.7.3: all 8 plugin.json bumped to 0.7.3
```

**Right:**
```
v0.8.1: workspace 0.8.0 -> 0.8.1, devtools 0.8.0 -> 0.8.1, other six unchanged
```

**Why:** Each plugin is independently installable. A user installing one plugin should see the version that reflects that plugin's actual change history, not a marketplace-wide release counter. Blanket-bumping makes the version field meaningless as a change signal.

## 2. Description prefix carries the version

Cowork's plugin directory UI shows the description but not the version field. Lead every plugin description (in `plugin.json` AND the corresponding `marketplace.json` `plugins[]` entry) with:

```
[{MarketplaceName} vX.Y.Z] {existing description}
```

Update both locations atomically on every bump. Users browsing the catalog see the version at a glance instead of having to install and inspect.

## 3. Marketplace `metadata.version` tracks the max

When a plugin moves to a new highest version, `marketplace.json` `metadata.version` follows. Other plugins do not get dragged along.

If `runesmith-devtools` moves from 0.8.1 to 0.8.2 and no other plugin changes, the marketplace metadata.version becomes 0.8.2. All other `plugin.json` versions stay where they are.

## 4. CHANGELOG lists only what moved

Per-release CHANGELOG entries should name the specific plugins that actually changed in that release. Do not write "all 8 plugins bumped to vX.Y.Z" unless all 8 plugins genuinely changed.

Pattern for the Versions block in a CHANGELOG entry:

```
### Versions
- {plugin-that-changed-1} {old} -> {new}
- {plugin-that-changed-2} {old} -> {new}
- Marketplace {old} -> {new}
- Other plugins unchanged
```

## 5. Per-bump checklist

For every release that bumps a plugin:

1. Update the plugin's `plugin.json` `version` field.
2. Update the plugin's `plugin.json` `description` prefix to the new version.
3. Update the corresponding entry in `marketplace.json` `plugins[]` - same description prefix.
4. Update `marketplace.json` `metadata.version` to the new highest version across all plugins.
5. Add a CHANGELOG entry listing ONLY the plugins that actually moved.
6. Run audit + build.

If your marketplace has `scripts/bump-version.py`, prefer running it over hand-editing - it does all four file updates atomically and leaves no room for drift.

## Audit enforcement

The marketplace audit script does not currently enforce per-plugin versioning at build time (it can't tell what changed without diffing). Enforcement is a process rule. Future audit could compare each plugin's version against its description prefix and fail on mismatch; that would catch desync between the two locations but not blanket-bump violations.
