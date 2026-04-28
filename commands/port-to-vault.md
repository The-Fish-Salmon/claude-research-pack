---
description: Draft a vault note in 00_Inbox/ from the current conversation's findings. User reviews before promoting out of Inbox.
argument-hint: {note-title}   (e.g. "srh cross-section impact")
---

The user wants the relevant findings from this conversation captured as a durable vault note. The user invoked this with `$ARGUMENTS`.

## Do this

1. If `$ARGUMENTS` is empty, ask "What should this note be titled? (short, specific)" and stop.

2. Identify what to capture. From the current conversation, extract:
   - Facts, numbers, or decisions that were *established* (not speculative)
   - Links/references to files, commits, papers
   - The user's reasoning or constraints when they steered a decision
   - Anything you would regret losing on a fresh session

   Skip: pure code chatter, debugging dead-ends, tool-call narration.

3. Decide note type — use the best match from: `concept` (atomic physics/method), `experiment` (run log), `paper` (literature), `log` (session/decision log), `moc` (map of content). If unclear, default to `log`.

4. Write the note to:
   `${OBSIDIAN_VAULT_PATH}/00_Inbox/{YYYY-MM-DD}-{slug}.md`

   (slug = `$ARGUMENTS` lowercased, spaces → dashes, punctuation stripped. If `$OBSIDIAN_VAULT_PATH` is unset, ask the user where their vault lives and stop.)

   With frontmatter:
   ```yaml
   ---
   type: {chosen type}
   tags: [{relevant tags}]
   status: active
   created: YYYY-MM-DD
   ---
   ```

5. Structure the body as:
   - `## Context` — one paragraph framing what prompted this note
   - `## What we learned / decided` — the durable substance
   - `## Numbers / artifacts` — any specific values, file paths, commit hashes
   - `## Open questions` — what's still unresolved
   - `## Related` — wiki-links to existing vault notes (use `[[note-name]]` syntax; only link to notes you're confident exist)

6. Report to user: "Drafted `00_Inbox/{date}-{slug}.md` ({type}). Review and move to the right numbered folder when ready. I did **not** commit."

## Constraints

- Do not use MCP to write — use the filesystem Write tool at the resolved vault path.
- Wikilinks only (`[[note]]`), never markdown links inside note bodies.
- Never promote out of `00_Inbox/` automatically — the user curates.
- If the conversation is clearly unproductive or has nothing worth capturing, say so and don't write the file.
