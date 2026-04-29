---
name: lit-status
description: Query the user's Obsidian literature library -- counts by status, tags, projects, and citation links. Reports unread / under-read papers, papers cited in active projects but missing from the vault, and tag clusters. Use when the user asks "what have I read on X?", "what's in my library?", "what should I read next?", or "show me the gaps in my reading".
---

# Lit Status (Desktop)

A read-only skill that surfaces what's in `30_Literature/` and how it relates to the user's active projects.

This skill is identical to the Code variant -- no `Agent` tool dependency. Desktop has no `/lit-map` slash command, so the user invokes by free text. Recognize phrasings like "what's in my library", "what should I read next on X", "what gaps do I have in topic Y".

## What it answers

- **How many papers are in the library**, broken down by `status` (unread / skimmed / read / cited / dismissed) and by `year`.
- **What tags / topics** are present, and how concentrated.
- **What's been read recently** (last 30 / 90 days, by `added` and by `status` change time).
- **What papers are cited in active project notes but missing from the library** (so the user can capture them).
- **What papers in the library don't link to any project** (orphaned reading).
- **Reading queue**: unread papers, ranked by how often their citekey is referenced in active project notes.

## Workflow

1. Use the `obsidian` MCP to enumerate notes in `30_Literature/`. Read frontmatter for each (citekey, status, tags, projects, added, year, doi, arxiv).
2. Use `obsidian` MCP search to find citekey references across `10_Projects/`, `60_MOCs/`, `00_Inbox/`. Build a citation count map.
3. Compose the requested report.

## Modes

The skill supports several report shapes; the slash command or invocation passes a mode hint:

- **`summary`** (default) -- one-paragraph overview + counts.
- **`unread`** -- list of unread papers, ranked by project-reference count.
- **`tags`** -- tag cloud + papers per tag.
- **`gaps`** -- papers cited in projects but not captured.
- **`orphans`** -- papers in library not linked to any project or MOC.
- **`citation-map {citekey}`** -- for one paper, show which project notes reference it.

## Constraints

- **Read-only.** Never writes to the vault. If the user wants to update a paper's status, point them to the file path; don't edit it for them.
- If the `obsidian` MCP is offline, fall back to filesystem `Glob` + `Grep` against the vault path from `OBSIDIAN_VAULT_PATH`.
- Limit each report section to <=30 entries; if there are more, show top 30 and the total count.

## Output style

Markdown tables for lists; one paragraph for summaries. Always include the count at the top of each table so the user knows whether they're seeing all or a subset.

## Example output

```
## Library status (2026-04-27)

**Total**: 142 papers -- 61 read, 23 skimmed, 53 unread, 5 cited, 0 dismissed.
**Most-referenced unread** (top 5):
| Citekey | Title | References in active project notes |
|---|---|---|
| kim2023ionic | ... | 7 |
| ... |

**Tags** (top 8):
- ion-gated-transistor (38), reservoir-computing (29), edl (22), ...

**Gaps** (cited in 10_Projects/{active-slug} but not in library): 3
- 10.1038/s41928-... -> suggested: /capture-paper 10.1038/s41928-...
- ...
```
