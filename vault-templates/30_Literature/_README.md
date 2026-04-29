# 30_Literature

This folder is your **paper library**. One markdown note per paper, named by `<citekey>.md`.

Notes are created automatically by the `paper-capture` skill (and by `/capture-paper`). Don't create them by hand -- it'll skew citekey conventions.

## What lives here

- One `<citekey>.md` per captured paper.
- The actual PDFs live at `../80_Attachments/papers/<citekey>.pdf`.
- The note is the canonical record: frontmatter (metadata) + body (your annotations).

## Status field

Each note has a `status:` in frontmatter. Update it as you go:

- `unread` -- captured, not yet read.
- `skimmed` -- abstract + figures, no deep read.
- `read` -- full read; takeaways noted.
- `cited` -- used in a project / paper / talk.
- `dismissed` -- captured, then determined off-topic. Keep the note (so you don't re-capture it) but won't show in default reading queues.

## Conventions

- Don't move or rename notes -- citekeys are stable references from project notes.
- If a paper is wrong (mis-resolved metadata), edit the frontmatter, but keep the citekey.
- Use the `tags:` and `projects:` lists to organize. Don't fold them into folders.

## See also

- [`70_Templates/literature.md`](../70_Templates/literature.md) -- the template each new note is built from.
- The `lit-status` skill / `/lit-map` slash command -- query this folder.
