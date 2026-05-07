---
description: Ingest a local PDF (or folder of PDFs) into the Obsidian vault. Extracts metadata, downloads canonical info via Semantic Scholar, writes a 30_Literature note, moves the PDF to 80_Attachments/papers/.
argument-hint: <path-to-pdf-or-folder>
---

The user wants to ingest a local PDF (or a folder of PDFs) into their Obsidian vault. The user invoked this with `$ARGUMENTS`.

## Do this

1. If `$ARGUMENTS` is empty, ask: "Path to the PDF (or folder)?" and stop.

2. Resolve the path. Treat as:
   - A folder if it ends in `\`, `/`, or its basename has no `.pdf` suffix and `Test-Path` reports it's a directory.
   - A single file otherwise.

3. Invoke the `ingest-pdf` skill with that path. The skill handles: DOI/arXiv/title sniff -> `paper-capture` for metadata + note write -> moving the PDF to `{vault}/80_Attachments/papers/{citekey}.pdf` -> updating the note's `pdf:` frontmatter.

4. Report the skill's result back as-is. For a folder ingest, that's the per-file lines + the final summary (`Total: N ingested, M skipped, K failed.`).

## Constraints

- Don't bypass the `ingest-pdf` skill. The slash command exists to give users a shorter way to invoke it; the skill body has the actual logic and the failure-mode coverage.
- Don't OCR. Image-only PDFs are reported, not handled.
- Never fabricate metadata. If the skill escalates because resolution failed, surface that to the user verbatim.
