# 80_Attachments

Binary attachments and non-markdown content. Obsidian's "Default location for new attachments" (Settings → Files & Links) should point here.

## Layout

```
80_Attachments/
├── papers/        ← PDFs captured by paper-capture (one per <citekey>.pdf)
├── figures/       ← inline images for project notes
└── data/          ← small CSVs / JSONs you want to wikilink from a note
```

## `papers/`

The `paper-capture` skill writes PDFs here as `<citekey>.pdf`. The corresponding markdown note in `30_Literature/<citekey>.md` has `pdf: 80_Attachments/papers/<citekey>.pdf` in its frontmatter.

If a download fails across all sources, the note is still written with `pdf: null`. You can drop a PDF here manually later — name it to match the citekey and update the frontmatter.

## Conventions

- One file per citekey for paper PDFs; don't bundle multiple papers into one PDF.
- Big binary blobs (>50 MB datasets, raw COMSOL `.mph` files) don't belong here — store on disk and wikilink to a path.
