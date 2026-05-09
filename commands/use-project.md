---
description: Switch the active sub-project in a multi-project vault. Updates frontmatter + ACTIVE_PROJECT env var.
argument-hint: <slug>  [--no-persist]  [--create]
---

Invoke the `use-project` skill on `$ARGUMENTS`.

## Do this

1. Parse `$ARGUMENTS`:
   - First positional argument is the project slug (kebab-case).
   - Optional `--no-persist`: skip `setx` -- only the current shell + frontmatter change.
   - Optional `--create`: scaffold the project folder + `overview.md` from `70_Templates/project-overview.md` if it doesn't exist.
2. Read [skills/use-project/SKILL.md](../skills/use-project/SKILL.md) and follow the workflow.

## Output to user

One line on success:
> `Active project: {slug} (frontmatter updated, ACTIVE_PROJECT set, persistent: yes|no)`

If the slug doesn't exist (and `--create` not passed):
> `No project named '{slug}' under 10_Projects/. Existing: {a}, {b}, ... — use --create to scaffold a new one.`

If `OBSIDIAN_VAULT_PATH` is unset:
> `Vault unreachable: setx OBSIDIAN_VAULT_PATH "<path>" and reopen this session.`
