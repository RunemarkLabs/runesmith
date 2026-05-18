---
description: Install, uninstall, or verify the CC project-boundary guardrail. Locks Claude Code sessions to their launch project's root via user-level permission rules and a PreToolUse hook. Run once per machine. Prevents cross-project credential leaks (the Mix Tape incident class). Pass an action argument or the skill will prompt.
argument-hint: "[install|uninstall|verify]"
---

Invoke the `guardrail` skill in `runesmith-cc`. Pass `$ARGUMENTS` as the requested action.
