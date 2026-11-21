# Naming Normalization

Canonical rules for deriving folder names, repo names, and slugs. Used by `reallocate`, `bootstrap-cc`, and any skill that creates a directory or repo on behalf of the user.

## Placeholder syntax (HARD RULE)

**Always use curly braces** `{PLACEHOLDER}` for template values. **Never** use angle brackets (a word wrapped in `<` and `>`).

| Use | Don't use |
|---|---|
| `{PROJECT}` | `{name}`, `{project}` |
| `{slug}` | `{slug}` |
| `{KEY}` | `{KEY}` |
| `{YYYY-MM}` | `{YYYY-MM}` |
| `{PATH}` | `{path}` |

**Why:** Cowork's plugin upload validator rejects angle-bracket patterns (a word wrapped in `<` and `>`) in SKILL.md frontmatter and `plugin.json` descriptions as unsubstituted templating syntax. The rejection comes back as a generic "Plugin validation failed" with no detail - debugging eats hours. The rule applies everywhere for consistency, even in body content where Cowork won't catch it.

**Audit enforces this** in `scripts/audit.py` via `check_frontmatter_placeholders`. Body content is exempt from automated check (HTML/XML examples in code blocks legitimately use angle brackets) but should still prefer `{WORD}` for placeholders.

If the user types `{value}` to you as a placeholder, transcribe to `{VALUE}` before persisting to any plugin file.

## Why

- GitHub repo names must match `^[A-Za-z0-9._-]+$`, max 100 chars, cannot start with `.` or `-`.
- Cross-platform file system safety: avoid spaces, capitals (case-insensitive filesystems collide), and special characters (`/ \ : * ? " < > |`).
- Consistency: kebab-case-lowercase reads cleanly everywhere - GitHub, IDEs, shells, URLs.

## The rule

Apply this transformation to any user-provided or detected name destined for a folder/repo/slug:

1. **Lowercase** the entire string.
2. **Replace** any character not in `[a-z0-9-]` with `-`.
3. **Collapse** consecutive `-` into a single `-`.
4. **Strip** leading and trailing `-`.
5. **Truncate** to 100 characters if longer.
6. **Reject** if the result is empty after step 4.

## Examples

| Input | Output |
|---|---|
| `Resume Unbound` | `resume-unbound` |
| `Acme Portal v2` | `acme-portal-v2` |
| `Müller_Söhne` | `m-ller-s-hne`   (non-ASCII collapses; rename manually if needed) |
| `my.cool.project` | `my-cool-project` |
| `  spaced   name  ` | `spaced-name` |
| `___underscore___` | `underscore` |
| `123-numeric-start` | `123-numeric-start` |
| `--leading-dashes` | `leading-dashes` |
| `&lt;placeholder&gt;` | `placeholder` |
| empty / only symbols | reject - ask user for a name |

## Reference Python implementation

```python
import re

def normalize_name(raw: str) -> str:
    """Normalize a user-facing name to GitHub-safe kebab-case-lowercase."""
    s = raw.lower()
    s = re.sub(r"[^a-z0-9-]+", "-", s)
    s = re.sub(r"-+", "-", s)
    s = s.strip("-")
    s = s[:100]
    if not s:
        raise ValueError("Name normalizes to empty - provide a different name.")
    return s
```

## Source-of-truth precedence

When determining a Claude Code workspace folder name (`{PROJECT}.cc/`):

1. **Existing git repo at workspace root** - if there's exactly one git repo subdir, normalize its folder name. Use that as the primary.
2. **Multiple git repos** - surface a structured choice to the user; whichever they pick becomes the primary and gives the `.cc/` its name. The others migrate into the `.cc/` alongside.
3. **No git repo, but workspace folder name is reasonable** - normalize the workspace folder name.
4. **No git repo, workspace folder name normalizes to empty** - prompt the user via structured input for a name.

## When the user provides a name

If user types a name with disallowed characters:
- Show them the normalized form
- Ask for confirmation via structured prompt (not freeform yes/no)
- Default to "yes" so they can hit enter to accept

Never silently use a name that differs from what the user typed. Always show the normalized form and confirm.

## Skills that apply this rule

- `runesmith-workspace:init` - when picking `{PROJECT}.cc/` during workspace migration
- `runesmith-cc:head` - when creating the head folder and when accepting a new repo name
- `runesmith-sprint:enable` - when accepting Jira project keys or board names that need filesystem-safe equivalents
- `runesmith-cc/agents/repo-bootstrapper` - when accepting new repo names for GitHub creation
