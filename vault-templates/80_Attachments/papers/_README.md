# 80_Attachments/papers

PDFs captured by the `paper-capture` skill, named `<citekey>.pdf`.

Don't put anything else here -- this folder is the de-facto truth source for "do we have the PDF?". `paper-capture` checks for `<citekey>.pdf` before re-downloading.

If you need to drop a PDF in manually:

1. Name it to match the citekey of the note in `30_Literature/<citekey>.md`.
2. Update that note's frontmatter from `pdf: null` -> `pdf: 80_Attachments/papers/<citekey>.pdf`.
