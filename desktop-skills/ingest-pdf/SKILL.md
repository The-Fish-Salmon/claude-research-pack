---
name: ingest-pdf
description: Ingest a local PDF (or a folder of PDFs) into the Obsidian vault -- extracts DOI/title, resolves metadata via Semantic Scholar, writes 30_Literature/CITEKEY.md.
---

# Ingest PDF (Desktop)

Use this skill when the user has a PDF *already on disk* (downloaded by hand,
emailed by a collaborator, scraped from a publisher) and wants it captured
into their vault as a proper `30_Literature/CITEKEY.md` note. This is the
companion to `paper-capture`, which only handles DOI / arXiv id / URL /
title-author-year inputs.

## Inputs accepted

- **A single file path**: `D:\downloads\smith2024.pdf`,
  `/mnt/d/papers/raw/foo.pdf`, or any absolute path.
- **A folder of PDFs**: e.g. `{vault}/80_Attachments/papers-inbox/`. Process
  every `*.pdf` under it; do NOT recurse into subfolders.
- **No path given**: ask the user once for the path or folder, then resume.

## Workflow

1. **Confirm vault path.** Read `OBSIDIAN_VAULT_PATH` from the env. If unset,
   ask the user once.
2. **Enumerate PDFs.** If the input is a directory, list its top-level `*.pdf`
   files. If it's a file, that's the list of one.
3. **For each PDF, extract metadata in this order:**
   - **(a) DOI sniff from text.** Use the `Read` tool to read the PDF (Claude
     Desktop's `Read` tool can ingest PDFs directly). Extract page-1 / page-2
     text. Run regex `\b10\.\d{4,9}/[-._;()/:a-zA-Z0-9]+\b` to find DOIs.
     If exactly one match: that's the DOI.
   - **(b) arXiv id sniff.** If no DOI, look for `arXiv:\d{4}\.\d{4,5}` or
     `https?://arxiv\.org/abs/\d{4}\.\d{4,5}`.
   - **(c) Title + first-author + year heuristic.** If neither id is present,
     parse the first-page text per
     [references/pdf_metadata_heuristics.md](references/pdf_metadata_heuristics.md):
     title is usually the first non-trivial line, first-author is the first
     name in the author list, year is the four-digit number near the title
     or in the running header.
4. **Resolve to canonical metadata.** Hand the DOI / arXiv id / (title +
   author + year) to `paper-capture`. paper-capture does the actual Semantic
   Scholar lookup, citekey generation, de-dup against existing
   `30_Literature/`, and note write. Do NOT re-implement that logic here.
5. **Move + rename the PDF.** Once paper-capture reports a citekey, move the
   original PDF to `{vault}/80_Attachments/papers/{citekey}.pdf`. If the file
   already exists at the destination (different paper, citekey collision),
   defer to paper-capture's collision rule (suffix `-b`, `-c`, ...).
6. **Update the note's frontmatter** so `pdf:` points to the renamed
   attachment path. paper-capture writes `pdf: null` by default; ingest-pdf
   replaces null with the real path after the move.
7. **Report.** One line per ingested PDF:
   `Ingested: {citekey} ({title trunc 60}) <- {original-path}`
   Plus a final summary: `Total: {n} ingested, {m} skipped, {k} failed.`

## Failure handling

- **Encrypted / scanned-image-only PDF.** No selectable text; DOI sniff
  returns nothing and the title heuristic is unreliable. Skip the file,
  report: `Skipped: {path} -- no extractable text. Run OCR first.`
- **DOI doesn't resolve in Semantic Scholar.** paper-capture will fall back
  to `paper-mcp` and then escalate to user. ingest-pdf surfaces that to the
  user and leaves the PDF in place.
- **PDF is already in the vault** (`{vault}/80_Attachments/papers/{citekey}.pdf`
  exists for the same DOI). Skip; report `Already captured: {citekey}`.

## What this skill does NOT do

- It does NOT OCR. Image-only PDFs are reported, not handled.
- It does NOT re-implement metadata resolution. That's paper-capture's job.
- It does NOT write to `30_Literature/` directly. Always goes through
  paper-capture.
- It does NOT auto-tag the new note with a project. The user does that
  manually or via `paper-map` later.
