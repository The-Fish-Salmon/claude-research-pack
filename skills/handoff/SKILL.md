---
name: handoff
description: Capture a structured handoff snapshot of the current session so the next chat can pick up where this one left off. Writes to the Claude Code memory dir (handoff_latest.md) and mirrors to the user's Obsidian vault inbox if OBSIDIAN_VAULT_PATH is set. Use when the user types /handoff, says "handoff", "switch chats", "save context before compact", or asks you to checkpoint before walking away.
argument-hint: [optional focus -- e.g. "drt voltage sweep", "phase 4 next steps"]
---

# Manual Session Handoff

This skill captures everything the next session needs to resume work. It supplements `/compact` -- `/compact` summarizes the conversation lossily; this writes durable, structured state.

## Resolve paths first

- **Memory dir** -- the `memory/` sibling next to the current session's transcript. The Claude Code path is `~/.claude/projects/{encoded-cwd}/memory/`. Use `~` (the user's home dir); never assume a specific username. `{encoded-cwd}` is the working directory with `/`, `:`, and `\` replaced by `-`.
- **Vault root** -- read `$OBSIDIAN_VAULT_PATH`. If unset, skip the vault mirror step and tell the user once at the end.
- **Active project slug** -- read `$ACTIVE_PROJECT` if set; otherwise scan `${OBSIDIAN_VAULT_PATH}/10_Projects/*/overview.md` for `status: active` and pick the first match. If none match, omit the active-project line.

## How to execute

1. **Build the handoff content yourself** -- do NOT delegate this to a subagent. The current session has the context; a fresh agent would not.
2. Collect the following from the conversation + live tools:
   - **Current focus** -- one paragraph: what are we working on *right now*?
   - **Focus arg** -- if the user passed `$ARGUMENTS`, lead with that
   - **Recent decisions** -- anything the user approved or steered (look for "yes", "do it that way", corrections)
   - **Open questions** -- unresolved items blocking progress
   - **Files touched this session** -- from your tool-call memory, list the last ~10 Read/Edit/Write paths
   - **Active project state** -- read `${OBSIDIAN_VAULT_PATH}/10_Projects/{active-slug}/overview.md` frontmatter, the latest note in `runs/`, and `~/.claude/projects/{encoded-cwd}/memory/MEMORY.md` if relevant
   - **In-progress TODOs** -- from the current TodoWrite list
   - **Next step** -- one sentence: what should the next session do first?

3. **Write two files** using the Write tool:

   **Primary:** `~/.claude/projects/{encoded-cwd}/memory/handoff_latest.md`
   **Vault mirror (only if `$OBSIDIAN_VAULT_PATH` is set):** `${OBSIDIAN_VAULT_PATH}/00_Inbox/handoff-{YYYY-MM-DD}.md`

   Frontmatter schema:
   ```yaml
   ---
   name: handoff-YYYY-MM-DD-HHMM
   type: handoff
   created: YYYY-MM-DD HH:MM:SS
   trigger: manual
   focus: "$ARGUMENTS"
   ---
   ```

4. **Archive the prior handoff** first: if `~/.claude/projects/{encoded-cwd}/memory/handoff_latest.md` exists, copy it to `~/.claude/projects/{encoded-cwd}/memory/handoffs/{its-created-timestamp}.md` before overwriting. Use Bash `cp` (POSIX) or `Copy-Item` (Windows) for this.

5. **Commit the vault** (only if the user's vault is a git repo and a vault root was resolved):
   ```
   git -C "$OBSIDIAN_VAULT_PATH" add 00_Inbox/ && \
     git -C "$OBSIDIAN_VAULT_PATH" commit -m "handoff: YYYY-MM-DD"
   ```
   Skip silently if the vault isn't under git or the commit returns non-zero.

## Report to the user

One short line: "Handoff written: `handoff_latest.md` + vault mirror. Focus: *$ARGUMENTS*. Next session will see it on start."

If the vault mirror was skipped (no `$OBSIDIAN_VAULT_PATH`), say so in the same line.

Do not dump the full handoff content back into chat -- that defeats the purpose.

## Handoff note template

```markdown
# Handoff -- {timestamp}

**Focus:** {$ARGUMENTS or "general session state"}
**Active project:** {slug -- status=, latest run=}
**CWD:** {current working dir}

## Current focus
{one paragraph}

## Recent decisions this session
- {bullet}
- {bullet}

## Open questions / blockers
- {bullet}

## Files touched
- `path/to/file.py`
- `...`

## In-progress TODOs
- [in_progress] {content}
- [pending] {content}

## Next session should
{one imperative sentence}

## Related vault notes
- [[10_Projects/{active-slug}/overview]]
- [[30_Literature/{citekey}]]
```

## Notes

- If the user types `/handoff` with no args, still write the handoff -- use "general session state" as focus.
- The PreCompact hook (at `~/.claude/hooks/precompact-handoff.py`) writes a lighter version automatically on `/compact`. `/handoff` is for when the user wants a *richer*, human-curated snapshot.
- Never delete history in `~/.claude/projects/{encoded-cwd}/memory/handoffs/` -- it's cheap and sometimes rescuing.
