---
name: paper-capture
description: Resolve a paper from a DOI, arXiv id, URL, or "Author Year keyword" string into the user's Obsidian vault -- fetches metadata, downloads PDF via the highest-priority MCP source available, generates a citekey, and writes a 30_Literature/CITEKEY.md note from the literature template. Use whenever the user wants to add a paper to their library, when deep-research reads a paper's full text, or when the user invokes /capture-paper.
---

# Paper Capture

Turn a reference into a vault entry: metadata, PDF, structured note. Idempotent -- captures the same paper twice will update the existing note, not duplicate it.

## Inputs accepted

- **DOI**: `10.1038/s41586-021-03819-2` or `https://doi.org/10.1038/...`
- **arXiv id**: `2103.04822` or `arXiv:2103.04822` or `https://arxiv.org/abs/2103.04822`
- **URL**: any publisher URL -- extract DOI from the page if needed
- **Title-author-year**: `"Kim 2023 ionic transistor"` -- looser, requires Semantic Scholar resolution

## Workflow

1. **Resolve to a paper id**. Prefer DOI > arXiv id > Semantic Scholar paperId. If only a title is given, search Semantic Scholar; if 0 or >1 high-confidence hits, escalate to user.
2. **Fetch metadata** (Semantic Scholar first, then `paper-mcp` fallback). Required fields: title, authors (full), year, venue, DOI, abstract.
3. **Generate citekey** per [references/citekey_rules.md](references/citekey_rules.md). De-dupe against existing `30_Literature/*.md` (use `obsidian` MCP search by frontmatter `citekey:`).
4. **Download the PDF** per [references/source_priority.md](references/source_priority.md): university-paper-access -> arxiv -> scihub. PDF lands at `{vault}/80_Attachments/papers/{citekey}.pdf`. If all paths fail, write the note anyway with `pdf: null` in frontmatter and report the failure.
5. **Write the vault note** at `{vault}/30_Literature/{citekey}.md` from `70_Templates/literature.md`. Populate frontmatter:
   - `citekey`, `authors` (list), `year`, `venue`, `doi`, `arxiv`, `s2_id`
   - `status: unread`
   - `tags: []` (user adds)
   - `projects: []` (user adds, or auto-tag if invoked from a known project)
   - `added: {today}`
   - `pdf: 80_Attachments/papers/{citekey}.pdf` (or `null`)
6. **Confirm to user**: one line -- `Captured: {citekey} ({title trunc 60}) -> 30_Literature/{citekey}.md`.

## Re-capture / update behavior

If `30_Literature/{citekey}.md` already exists:

- Re-fetch metadata; update frontmatter fields **except** `status`, `tags`, `projects`, body sections (those are user-edited).
- Don't re-download PDF if file already exists at the expected path.
- Report: `Updated: {citekey} (metadata refreshed; status/tags preserved)`.

## When invoked from deep-research

The deep-research investigator agent calls this skill automatically for every paper it reads at the `full` level. The `projects` field is auto-tagged with the active project slug if one is detectable from `~/.claude/projects/.../memory/` or the working directory.

## Errors

- **Metadata not found** -> don't write a note; report and stop.
- **PDF download failed across all sources** -> write note with `pdf: null`, status `unread (no pdf)`. User can manually drop a PDF later.
- **Citekey collision with a different paper** (same firstauthor/year/keyword for two real papers) -> suffix with `-b`, `-c`, etc., and note the collision in the body.

## What this skill does NOT do

- Annotate the paper. The user reads and writes their own takeaways.
- Auto-add to the active project's MOC. The hook can suggest, but the user promotes.
- Write to the bibtex file. (Possible future hook; out of scope here.)
