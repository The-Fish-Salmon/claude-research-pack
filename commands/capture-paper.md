---
description: Capture a paper into your Obsidian library -- fetch metadata, download PDF, write a 30_Literature/{citekey}.md note.
argument-hint: <DOI | arXiv id | URL | "Author Year keyword">  [--citekey {override}]  [--project {slug}]
---

Invoke the `paper-capture` skill on `$ARGUMENTS`.

## Do this

1. Parse `$ARGUMENTS`:
   - First positional argument is the paper identifier (DOI / arXiv / URL / search string).
   - Optional `--citekey {key}` overrides the auto-generated citekey (must match `^[a-z]+\d{4}[a-z][a-z0-9-]*$`).
   - Optional `--project {slug}` adds the project tag to the note's `projects` frontmatter list.
2. Read [skills/paper-capture/SKILL.md](../skills/paper-capture/SKILL.md) and follow the workflow.
3. Use the MCP servers in priority order per [skills/paper-capture/references/source_priority.md](../skills/paper-capture/references/source_priority.md).

## Output to user

One line on success:
> `Captured: {citekey} ({title trunc 60}) -> 30_Literature/{citekey}.md (PDF: {yes|no})`

If the paper was already in the library:
> `Updated: {citekey} (metadata refreshed; status/tags preserved)`

If the PDF download failed across all sources:
> `Captured: {citekey} (note only; PDF unavailable -- tried UPA, arXiv, paper-search, Sci-Hub)`

If metadata could not be resolved:
> `Failed: could not resolve {input}. Tried Semantic Scholar + paper-mcp. Try a DOI or full title.`
