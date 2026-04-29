---
description: Inspect your literature library -- counts by status/tags, gaps, orphans, and citation links to active projects.
argument-hint: [summary | unread | tags | gaps | orphans | citation-map {citekey}]  [--project {slug}]
---

Invoke the `lit-status` skill against the Obsidian vault.

## Do this

1. Parse `$ARGUMENTS`. First token = mode (default `summary`). Optional `--project {slug}` scopes the report to one project's notes.
2. Read [skills/lit-status/SKILL.md](../skills/lit-status/SKILL.md).
3. Use the `obsidian` MCP to read frontmatter from every note in `30_Literature/` and to search for citekey references in `10_Projects/`, `60_MOCs/`, `00_Inbox/`.
4. Compose the requested report shape; cap each list at 30 entries.

## Output to user

The report itself, as markdown, in chat. Don't write to the vault -- this is read-only.

## Mode reference

- `summary` -- counts by status, tags, recent activity.
- `unread` -- unread papers ranked by project-reference count.
- `tags` -- tag cloud + papers per tag.
- `gaps` -- papers cited in projects but not in library (suggest `/capture-paper {id}` for each).
- `orphans` -- library papers not linked to any project.
- `citation-map {citekey}` -- show which project notes reference one paper.
