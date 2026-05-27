#!/usr/bin/env python3
"""
RuneSmith marketplace per-plugin version bump.

Usage:
    python scripts/bump-version.py {plugin-name} {new-version}

Example:
    python scripts/bump-version.py runesmith-devtools 0.8.4

Updates atomically:
  1. plugins/{plugin-name}/.claude-plugin/plugin.json version field
  2. plugins/{plugin-name}/.claude-plugin/plugin.json description prefix
     ([MarketplaceName vX.Y.Z] ...) - leaves rest of description intact
  3. .claude-plugin/marketplace.json plugins[] entry description prefix
  4. .claude-plugin/marketplace.json metadata.version (set to max across
     all plugin versions)

Per the per-plugin versioning HARD RULE in
plugins/runesmith-devtools/lib/release-maintenance.md: only this plugin bumps,
others stay where they are. Marketplace metadata.version tracks the max.

Exit codes:
    0 = bump applied
    1 = error (plugin not found, invalid version, etc.)
"""

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)


def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def valid_version(s):
    return bool(re.fullmatch(r"\d+\.\d+\.\d+", s))


def max_version(versions):
    def tup(v):
        return tuple(int(x) for x in v.split("."))
    return max(versions, key=tup)


def update_description_prefix(desc, new_version):
    """Replace [MarketplaceName vOLD] with [MarketplaceName vNEW].
    Tolerant of any marketplace name; only matches the leading [Name v#.#.#]."""
    pattern = re.compile(r"^\[([^\]]+? v)\d+\.\d+\.\d+\]")
    m = pattern.match(desc)
    if not m:
        fail(f"description does not start with [Name vX.Y.Z] prefix: {desc[:80]!r}")
    return pattern.sub(f"[{m.group(1)}{new_version}]", desc, count=1)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    plugin_name, new_version = sys.argv[1], sys.argv[2]

    if not valid_version(new_version):
        fail(f"new-version must match X.Y.Z (got {new_version!r})")

    plugin_dir = Path("plugins") / plugin_name
    plugin_json_path = plugin_dir / ".claude-plugin" / "plugin.json"
    marketplace_path = Path(".claude-plugin/marketplace.json")

    if not plugin_json_path.exists():
        fail(f"{plugin_json_path} not found - plugin name correct?")
    if not marketplace_path.exists():
        fail(f"{marketplace_path} not found - run from marketplace root")

    # 1 + 2: plugin.json
    pj = json.loads(plugin_json_path.read_text(encoding="utf-8"))
    old_version = pj.get("version", "?")
    pj["version"] = new_version
    pj["description"] = update_description_prefix(pj["description"], new_version)
    plugin_json_path.write_text(
        json.dumps(pj, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    # 3 + 4: marketplace.json
    mk = json.loads(marketplace_path.read_text(encoding="utf-8"))
    found = False
    for entry in mk.get("plugins", []):
        if entry.get("name") == plugin_name:
            entry["description"] = update_description_prefix(
                entry["description"], new_version
            )
            found = True
            break
    if not found:
        fail(f"plugin {plugin_name} not listed in marketplace.json plugins[]")

    # Recompute marketplace metadata.version as max across all plugin versions
    all_versions = []
    for entry in mk["plugins"]:
        pj_path = Path(entry["source"].lstrip("./")) / ".claude-plugin/plugin.json"
        if pj_path.exists():
            v = json.loads(pj_path.read_text(encoding="utf-8")).get("version")
            if v:
                all_versions.append(v)
    if all_versions:
        new_max = max_version(all_versions)
        old_max = mk.get("metadata", {}).get("version", "?")
        mk.setdefault("metadata", {})["version"] = new_max
    else:
        new_max = old_max = "?"

    marketplace_path.write_text(
        json.dumps(mk, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"Bumped {plugin_name}: {old_version} -> {new_version}")
    print(f"Marketplace metadata.version: {old_max} -> {new_max}")
    print()
    print("Next steps:")
    print(f"  1. Add CHANGELOG entry under [{new_max}] (or new section if marketplace bumped)")
    print(f"  2. Run audit: python scripts/audit.py")
    print(f"  3. Build dist: python scripts/build.py")
    print(f"  4. Commit + push when ready")


if __name__ == "__main__":
    main()
