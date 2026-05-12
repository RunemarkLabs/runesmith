#!/usr/bin/env python3
"""
RuneSmith marketplace audit.

Runs every check that should pass before a plugin set is shipped:
  - marketplace.json schema
  - per-plugin plugin.json schema (name matches folder)
  - SKILL.md frontmatter (name, description, name matches folder)
  - Forbidden patterns (angle-bracket placeholders, security-keyword scanner triggers,
    plain-text yes/no prompts)
  - Broken lib/ and agents/ references

Used by .github/workflows/build.yml. Can also be run locally:

    python scripts/audit.py

Exit code: 0 on pass, 1 on fail.
"""

import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)

# Forbidden patterns -- the upload scanner rejects content matching these
FORBIDDEN_PATTERNS = {
    r"<project>": "angle-bracket placeholder (use {PROJECT})",
    r"\binject(s|ed|ing|ion)?\b": "injection vocabulary (use apply or embed)",
    r"paste secret": "secret-paste phrasing (use 'provide a configuration value')",
    r"stripe-key": "specific API key brand (use generic placeholder)",
    r"\[y/n\]": "plain-text yes/no prompt (use structured form)",
    r"\[y\]es\s*/\s*\[n\]o": "plain-text yes/no prompt (use structured form)",
}

# Files exempt from FORBIDDEN_PATTERNS (they document the forbidden patterns)
EXEMPT_FILES = {"user-prompts.md", "naming.md"}


def fail(msg, fails):
    fails.append(msg)


def check_marketplace_json(fails):
    p = Path(".claude-plugin/marketplace.json")
    if not p.exists():
        fail(f"missing {p}", fails)
        return None
    try:
        m = json.loads(p.read_text(encoding='utf-8'))
    except Exception as e:
        fail(f"{p}: invalid JSON: {e}", fails)
        return None
    for required in ("name", "owner", "plugins"):
        if required not in m:
            fail(f"{p}: missing field '{required}'", fails)
    if not isinstance(m.get("plugins"), list):
        fail(f"{p}: plugins must be a list", fails)
        return None
    for entry in m["plugins"]:
        if not entry.get("name"):
            fail(f"{p}: plugin entry missing name", fails)
        if not entry.get("source"):
            fail(f"{p}: plugin entry missing source", fails)
    return m


def check_plugin_manifests(fails):
    plugin_names = []
    plugin_deps = {}
    for plugin_dir in sorted(Path("plugins").iterdir() if Path("plugins").exists() else []):
        if not plugin_dir.is_dir():
            continue
        pj = plugin_dir / ".claude-plugin" / "plugin.json"
        if not pj.exists():
            fail(f"{plugin_dir.name}: missing .claude-plugin/plugin.json", fails)
            continue
        try:
            d = json.loads(pj.read_text(encoding='utf-8'))
        except Exception as e:
            fail(f"{pj}: invalid JSON: {e}", fails)
            continue
        for required in ("name", "version", "description"):
            if required not in d:
                fail(f"{plugin_dir.name}: plugin.json missing '{required}'", fails)
        if d.get("name") != plugin_dir.name:
            fail(
                f"{plugin_dir.name}: plugin.json name '{d.get('name')}' != folder",
                fails,
            )
        plugin_names.append(d.get("name", plugin_dir.name))
        plugin_deps[d.get("name", plugin_dir.name)] = d.get("dependencies", [])
    return plugin_names, plugin_deps


def check_dependency_dag(plugin_names, plugin_deps, fails):
    def has_cycle(node, visited, stack):
        visited.add(node)
        stack.add(node)
        for dep in plugin_deps.get(node, []):
            if dep not in plugin_names:
                fail(f"{node}: depends on unknown plugin '{dep}'", fails)
                continue
            if dep in stack:
                return True
            if dep not in visited and has_cycle(dep, visited, stack):
                return True
        stack.discard(node)
        return False

    visited = set()
    for p in plugin_names:
        if has_cycle(p, visited, set()):
            fail(f"dependency cycle involving '{p}'", fails)


def check_skill_frontmatter(fails):
    for sk_md in Path("plugins").rglob("SKILL.md"):
        content = sk_md.read_text(encoding='utf-8')
        parts = content.split("---", 2)
        if len(parts) < 3:
            fail(f"{sk_md}: no frontmatter", fails)
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except Exception as e:
            fail(f"{sk_md}: YAML error: {e}", fails)
            continue
        if not isinstance(fm, dict):
            fail(f"{sk_md}: frontmatter not a dict", fails)
            continue
        if "name" not in fm or "description" not in fm:
            fail(f"{sk_md}: missing name or description", fails)
            continue
        skill_dir = sk_md.parent.name
        if fm.get("name") != skill_dir:
            fail(
                f"{sk_md}: name '{fm.get('name')}' != folder '{skill_dir}'",
                fails,
            )


def check_forbidden_patterns(fails):
    for f in Path("plugins").rglob("*"):
        if not f.is_file() or f.suffix not in (".md", ".json", ".xhtml"):
            continue
        if f.name in EXEMPT_FILES:
            continue
        try:
            text = f.read_text(encoding='utf-8')
        except Exception:
            continue
        for pat, label in FORBIDDEN_PATTERNS.items():
            for m in re.finditer(pat, text, re.IGNORECASE):
                line = text[: m.start()].count("\n") + 1
                fail(f"{f}:{line}: forbidden pattern '{m.group()}' ({label})", fails)


def check_references(fails):
    for sk_md in Path("plugins").rglob("SKILL.md"):
        plugin_root = sk_md.parents[2]
        text = sk_md.read_text(encoding='utf-8')
        for m in re.finditer(r"`(lib/[a-z0-9-]+\.md)`", text):
            target = plugin_root / m.group(1)
            if not target.exists():
                fail(f"{sk_md}: missing lib ref `{m.group(1)}`", fails)
        for m in re.finditer(r"`(agents/[a-z0-9-]+\.md)`", text):
            target = plugin_root / m.group(1)
            if not target.exists():
                fail(f"{sk_md}: missing agent ref `{m.group(1)}`", fails)


def check_command_descriptions(fails):
    """Command descriptions get registered as Cowork slash-command tooltips.
    A description truncated mid-sentence (e.g. ending with '{PROJECT}.' or 'CLAUDE.')
    causes Cowork to silently skip command registration — the slash command then
    returns 'Unknown command'. Reject descriptions shorter than 30 chars or that
    appear truncated at a placeholder boundary."""
    truncated_re = re.compile(r"(\{[A-Z_]+\}|CLAUDE)\.\s*$")
    for cmd_md in Path("plugins").rglob("commands/*.md"):
        text = cmd_md.read_text(encoding='utf-8')
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except Exception:
            continue
        if not isinstance(fm, dict):
            continue
        desc = (fm.get("description") or "").strip()
        if len(desc) < 30:
            fail(f"{cmd_md}: description too short ({len(desc)} chars) — likely truncated", fails)
            continue
        if truncated_re.search(desc):
            fail(f"{cmd_md}: description appears truncated at placeholder boundary: '{desc[-40:]}'", fails)


def check_frontmatter_placeholders(fails):
    """Cowork's upload validator rejects <word> patterns in SKILL.md frontmatter.
    Canonical placeholder syntax is {WORD} (curly braces). Body content is exempt —
    it can legitimately contain HTML/XML examples in code blocks."""
    angle_re = re.compile(r"<[a-zA-Z][a-zA-Z0-9_-]*>")
    for sk_md in Path("plugins").rglob("SKILL.md"):
        text = sk_md.read_text(encoding='utf-8')
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        frontmatter = parts[1]
        for m in angle_re.finditer(frontmatter):
            line = frontmatter[: m.start()].count("\n") + 2  # +2 for opening ---
            fail(
                f"{sk_md}:{line}: angle-bracket placeholder '{m.group()}' in frontmatter — use {{WORD}} (curly braces). Cowork rejects <word> as unsubstituted templating syntax.",
                fails,
            )
    # Also check plugin.json description fields (Cowork's metadata scanner reads these)
    for pj in Path("plugins").rglob(".claude-plugin/plugin.json"):
        try:
            d = json.loads(pj.read_text(encoding='utf-8'))
        except Exception:
            continue
        desc = d.get("description", "")
        for m in angle_re.finditer(desc):
            fail(
                f"{pj}: angle-bracket placeholder '{m.group()}' in description — use {{WORD}}.",
                fails,
            )


def check_forbidden_plugin_fields(fails):
    """Cowork's plugin loader silently drops plugins whose plugin.json carries
    unsupported fields. Known offender: `dependencies` (not part of the Claude
    plugin schema; loader interprets it as a gate it can't satisfy and rejects
    the plugin from the runtime skill registry). The plugin still appears in
    the session-start manifest but `/<plugin>:<skill>` returns 'Unknown command'.
    Add more entries here as new offenders are identified."""
    FORBIDDEN = {"dependencies"}
    for pj in Path("plugins").rglob(".claude-plugin/plugin.json"):
        try:
            d = json.loads(pj.read_text(encoding='utf-8'))
        except Exception:
            continue
        for key in FORBIDDEN:
            if key in d:
                fail(
                    f"{pj}: forbidden field '{key}' — Cowork's plugin loader rejects plugins carrying this. Remove the field.",
                    fails,
                )


def main():
    fails = []
    m = check_marketplace_json(fails)
    plugin_names, plugin_deps = check_plugin_manifests(fails)
    check_dependency_dag(plugin_names, plugin_deps, fails)
    check_skill_frontmatter(fails)
    check_forbidden_patterns(fails)
    check_frontmatter_placeholders(fails)
    check_command_descriptions(fails)
    check_forbidden_plugin_fields(fails)
    check_references(fails)

    print(f"Plugins: {len(plugin_names)}")
    print(f"Audit fails: {len(fails)}")
    if fails:
        for f in fails:
            print(f"  FAIL: {f}")
        return 1
    print("OK: all checks pass.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
