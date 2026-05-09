---
name: use-project
description: Switch the active sub-project in a multi-project Obsidian vault. Updates 10_Projects/<slug>/overview.md frontmatter to status:active (and pauses the others), sets ACTIVE_PROJECT env var. Use /use-project <slug> or "switch to project <slug>".
argument-hint: <slug>  [--no-persist]  [--create]
---

# Use Project

Switch which sub-project under `10_Projects/` is currently active. The pack uses one Obsidian vault for all research and many sub-projects inside it; this skill is how you tell every other skill ("which project am I working on right now?").

## Resolve paths first

- **Vault root** -- `$OBSIDIAN_VAULT_PATH`. If unset, abort: tell the user to `setx OBSIDIAN_VAULT_PATH "<path>"` and reopen.
- **Project dir** -- `${OBSIDIAN_VAULT_PATH}/10_Projects/<slug>/`.
- **Overview file** -- `${OBSIDIAN_VAULT_PATH}/10_Projects/<slug>/overview.md`.

## Workflow

1. Parse `$ARGUMENTS`:
   - First positional arg is the slug (kebab-case, e.g. `ecram`, `prc`, `ion-gated-tx`).
   - Optional `--no-persist`: only update the current shell + frontmatter; don't `setx`.
   - Optional `--create`: if `10_Projects/<slug>/` does not exist, scaffold it from the template at `70_Templates/project-overview.md` instead of failing.

2. **Validate the slug:**
   - If `${OBSIDIAN_VAULT_PATH}/10_Projects/<slug>/` does not exist:
     - With `--create`: `mkdir` it, copy `70_Templates/project-overview.md` into it as `overview.md`, fill in the `project:` and `started:` fields, and continue.
     - Without `--create`: stop. Tell the user the slug doesn't exist and list the slugs that do (one per line, scanned from `10_Projects/*/`). Suggest `/use-project <slug> --create` if they meant to start a new one.

3. **Update frontmatter across all `10_Projects/*/overview.md`:**
   - The new active project: set `status: active` in its frontmatter.
   - Every other project currently `status: active`: set to `status: paused` (don't touch `done` or `abandoned`).
   - Use the obsidian MCP to read/write each note. Modify only the `status:` line in the frontmatter block; leave the body untouched.

4. **Set the env var (two scopes):**
   - **Current shell** -- run `$env:ACTIVE_PROJECT = "<slug>"` via PowerShell tool (or `export ACTIVE_PROJECT=<slug>` via Bash on WSL).
   - **Persistent (next session)** -- `setx ACTIVE_PROJECT <slug>` on Windows, or append/replace `export ACTIVE_PROJECT=<slug>` in `~/.bashrc` on WSL. Skip this if `--no-persist` was passed.

5. **Confirm to the user (one line):**
   ```
   Active project: <slug> (frontmatter updated, ACTIVE_PROJECT set, persistent: yes/no).
   ```

## Why frontmatter and env var both

The pack's other skills don't all read the env var. `statusline.ps1`, the `handoff` skill, the `precompact-handoff` hook, and `/status` all scan `10_Projects/*/overview.md` for `status: active` and use that. Skills like `paper-capture`'s `--project` flag and `paper-mention-detect` prefer the env var. Updating both means every skill ends up at the same answer; you never have to remember which one a specific tool reads.

## Constraints

- **Don't touch projects with `status: done` or `status: abandoned`** -- those are intentionally retired. Switching active never reactivates an archived project.
- **One active at a time.** Even if multiple were `active` before (which shouldn't happen but might from manual edits), this skill collapses to exactly one active project on completion.
- **No PDF / metadata side effects.** This skill only touches `overview.md` frontmatter and env vars; it never writes to `30_Literature/` or `80_Attachments/`.

## Related

- `Set-ActiveProject` PowerShell function (in user's `$PROFILE` from `scripts/Set-ActiveProject.ps1`) -- equivalent for direct shell use, no Claude needed.
- `/status` -- read-only snapshot of the *currently* active project.
- `/handoff` -- captures the active project's state for the next session.
- `vault-templates/70_Templates/project-overview.md` -- the canonical schema this skill enforces.
