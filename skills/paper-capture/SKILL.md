---
name: paper-capture
description: Resolve a paper from a DOI, arXiv id, URL, or Author-Year-keyword into the Obsidian vault. Fetches metadata, downloads PDF, writes 30_Literature/CITEKEY.md. Use /capture-paper.
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
   - When calling `mcp__paper-mcp__paper_get_metadata`, prefix the input with `DOI:` (e.g. `DOI:10.1038/nature14236`). Calling without the prefix returns a confusing error.
   - Distinguish HTTP **429 (rate-limited)** from **404 (not found)**. A 429 is *not* permission to mark a paper as unverified -- retry with backoff (3 attempts, 2s/4s/8s) before treating it as a metadata failure. Only a clean 404 from BOTH Semantic Scholar and paper-mcp permits the "metadata not found" path.
3. **Retraction check.** After metadata is in hand:
   - Check Semantic Scholar `externalIds.DOI`, then call Crossref `https://api.crossref.org/works/{doi}` (HTTP GET, no key required). If the Crossref title starts with `RETRACTED:` (case-insensitive) OR if the response contains `"update-type": "retraction"` in the `update-to` field, mark the paper retracted.
   - Some sources strip the `RETRACTED:` prefix from titles -- treat Crossref as authoritative when there is disagreement.
   - When retracted: add `retracted: true` and `retraction_source: crossref` to the note frontmatter, prepend `[RETRACTED]` to the note title in the body, and emit a one-line warning when reporting back to the user.
4. **Generate citekey** per [references/citekey_rules.md](references/citekey_rules.md). De-dupe against existing `30_Literature/*.md` (use `obsidian` MCP search by frontmatter `citekey:`).
5. **Download the PDF** per [references/source_priority.md](references/source_priority.md): arxiv -> paper-search -> chrome-devtools (paywall bypass via library proxy). PDF lands at `{vault}/80_Attachments/papers/{citekey}.pdf`. **After every download, validate the file with `pdf_is_valid` from source_priority.md.** A returned path is NOT proof of success -- the underlying MCPs have been observed to save HTML error pages with a `.pdf` extension. If `pdf_is_valid` fails, delete the file and continue down the priority chain. If all paths fail, write the note anyway with `pdf: null` in frontmatter and report the failure.
6. **Write the vault note** at `{vault}/30_Literature/{citekey}.md` from `70_Templates/literature.md`. Populate frontmatter:
   - `citekey`, `authors` (list), `year`, `venue`, `doi`, `arxiv`, `s2_id`
   - `status: unread`
   - `tags: []` (user adds)
   - `projects: []` (user adds, or auto-tag if invoked from a known project)
   - `added: {today}`
   - `pdf: 80_Attachments/papers/{citekey}.pdf` (or `null`)
   - `retracted: true` (only when retraction check fires)
7. **Confirm to user**: one line -- `Captured: {citekey} ({title trunc 60}) -> 30_Literature/{citekey}.md`. If retracted, the confirmation line is `Captured (RETRACTED): {citekey} ...` -- surface this loudly.

## Re-capture / update behavior

If `30_Literature/{citekey}.md` already exists:

- Re-fetch metadata; update frontmatter fields **except** `status`, `tags`, `projects`, body sections (those are user-edited).
- Don't re-download PDF if file already exists at the expected path.
- Report: `Updated: {citekey} (metadata refreshed; status/tags preserved)`.

## When invoked from deep-research

The deep-research investigator agent calls this skill automatically for every paper it reads at the `full` level. The `projects` field is auto-tagged with the active project slug if one is detectable from `~/.claude/projects/.../memory/` or the working directory.

## Errors

- **Metadata not found** -> don't write a note; report and stop. Only counts when BOTH Semantic Scholar and paper-mcp return a clean 404 -- a 429 rate-limit is not "not found".
- **PDF download failed across all sources** -> write note with `pdf: null`, status `unread (no pdf)`. User can manually drop a PDF later.
- **PDF download appeared to succeed but `pdf_is_valid` returned false** (HTML error page saved as `.pdf`, response truncated, etc.) -> delete the file, continue down the priority chain, do not report success.
- **Citekey collision with a different paper** (same firstauthor/year/keyword for two real papers) -> suffix with `-b`, `-c`, etc., and note the collision in the body.
- **Retraction detected** -> still capture (researchers need access to retracted papers for context), but set `retracted: true` and surface the warning. Never silently capture a retraction as a normal paper.

## What this skill does NOT do

- Annotate the paper. The user reads and writes their own takeaways.
- Auto-add to the active project's MOC. The hook can suggest, but the user promotes.
- Write to the bibtex file. (Possible future hook; out of scope here.)
