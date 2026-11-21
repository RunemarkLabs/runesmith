# Atlassian-Enabled Detection

How skills determine whether the current workspace has the Atlassian interconnect turned on.

## Signal

A workspace is atlassian-enabled when ALL of:
1. `{workspace-root}/.atlassian-enabled` file exists.
2. `{workspace-root}/{PROJECT}.cc/.claude-code-workspace` has `"atlassianEnabled": true`.
3. The marker's `atlassian` block has at least: `siteUrl`, `jiraProjectKey`, `confluenceSpaceKey`.

`runesmith-sprint:enable` writes (1) and (2). `runesmith-sprint:disable` removes them.

## Resolution order for skills

```
def is_atlassian_enabled(workspace_root):
    marker = read_json(f"{workspace_root}/.atlassian-enabled")
    if not marker:
        return False

    cc_marker_path = find_cc_marker(workspace_root)
    if not cc_marker_path:
        return False

    cc_marker = read_json(cc_marker_path)
    return cc_marker.get("atlassianEnabled") is True
```

`find_cc_marker(workspace_root)` walks `{workspace-root}/*/.claude-code-workspace`. If multiple, prefer the one whose `project` field matches the workspace root folder name.

## Reading project values

Once enabled, skills read from the CC marker:

```json
{
  "atlassian": {
    "siteUrl": "https://...",
    "jiraProjectKey": "...",
    "jiraProjectId": ...,
    "boardId": ...,
    "activeSprintId": ...,
    "confluenceSpaceKey": "...",
    "confluenceSpaceId": ...
  }
}
```

These are the **user's** project values, gathered by `runesmith-sprint:enable` at run time. The marketplace ships zero hardcoded keys.

## When skills should branch

| Skill | Branches on enabled? |
|---|---|
| `runesmith-core:plan` | No - runs same in both configs |
| `runesmith-sprint:plan-to-tickets` | Yes - only available when enabled |
| `runesmith-sprint:start-sprint` / `sprint-status` | Yes - only available when enabled |
| `runesmith-sprint:check-comms` | No - works in both configs |
| Existing 6 publish skills | No - work standalone, optionally read plans/active/ in both configs |
| CC-side skill templates | Yes - only deployed by `enable`, only present when enabled |

## Disable behavior

`runesmith-sprint:disable` removes (1), sets `atlassianEnabled: false` in (2), and removes the deployed CC-side skills from `{PROJECT}.cc/.claude/skills/atlassian/`. The applied `atlassian-section` blocks in CLAUDE.md files are stripped.

## Edge cases

- **Marker present but values null:** Treat as not-enabled. Skills should error: "Atlassian marker exists but config is empty. Re-run `/runesmith-sprint:enable`."
- **Workspace marker but no CC marker:** Treat as not-enabled. CC head was deleted; skills should suggest re-running `/runesmith-cc:head`.
- **CC marker says enabled but no workspace marker:** Treat as not-enabled. The two must agree. Skills suggest re-running `/runesmith-sprint:enable`.
