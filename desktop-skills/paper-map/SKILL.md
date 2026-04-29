---
name: paper-map
description: Maintain the cross-device paper index at {vault}/00-Claude-Context/paper-map.md. Use for "update paper-map", "add this paper to the map", "rebuild paper-map".
---

# Paper Map (Desktop)

Use this skill to maintain `{vault}/00-Claude-Context/paper-map.md`. It is the
**portable** paper index -- a compact summary of the papers an active research
thread is using, kept in the synced continuity folder so the next device can
pick up the bibliographic state.

This is **not** the full library. The full library lives in `30_Literature/`
and is queried by the `lit-status` skill. `paper-map.md` is a curated subset:
just the papers the user is actively reasoning about, plus enough metadata for
a fresh device to reorient.

## Operating Rules

1. Write only to `00-Claude-Context/paper-map.md` (and, if a claim shifts,
   also `open-questions.md` / `decision-log.md` / `task-ledger.md` per the
   schema). Never write outside `00-Claude-Context/`.
2. Read `30_Literature/{citekey}.md` and `00-Claude-Context/paper-map.md` to
   collect data. Don't fetch papers -- that's `paper-capture`.
3. Keep entries compact and sortable by citekey. Don't delete useful prior
   context just because the user asked you to add a new paper.

## What an entry looks like

```markdown
## kim2023ionic

- Path: `30_Literature/kim2023ionic.md`
- Status: read | skimmed | unread | extracted | cited
- Main claim: Ion-gated synaptic transistors achieve memory-retention scaling
  proportional to ion residence time.
- Methods/data: WSe2 EDL transistor; pulsed I/V; 1 ns-10 ms regimes.
- Useful for: fading-memory characterization in active project.
- Caveats: Single-device measurements; no statistical population.
- Threads: [[#tau-c-trend]], [[#fading-memory-validation]]
- Tags: ion-gated, edl, memory, wse2
```

Citekey is the H2 anchor -- **stable**, never rename. If a paper's role in the
research changes, edit the entry's `Status` / `Useful for` / `Threads` fields,
don't move the heading.

## Procedure

1. Read the current `paper-map.md`. Build an in-memory map of citekey -> entry.
2. Determine the operation:
   - **Add** -- user pasted a citekey or DOI; check the entry doesn't exist;
     fetch metadata from `30_Literature/{citekey}.md` if available.
   - **Update** -- change Status / Useful for / Threads / Caveats based on what
     happened in this session.
   - **Cross-link** -- if an entry's Main claim conflicts with another, add a
     line to `open-questions.md` (or `decision-log.md` if the conflict is
     already resolved).
   - **Rebuild** -- user asked for a fresh build from `30_Literature/`. Walk the
     directory, build entries for papers tagged with the active project (or
     all of them, if user said so), and replace the file body. Don't touch
     frontmatter.
3. Write the result back. Update frontmatter `last_updated` to UTC ISO 8601
   and `source_device` to the active hostname slug.
4. Report one line: `paper-map updated: +{n} added, ~{m} updated, total {N}.`

## When to escalate

- A paper's Main claim contradicts an entry already in `decision-log.md` ->
  surface to the user before writing.
- The user asks to delete an entry -> confirm explicitly. The continuity layer
  is biased toward append-only; deletions are rare and should be deliberate.
- `30_Literature/{citekey}.md` is missing for a paper the user wants in the
  map -> suggest `paper-capture {DOI}` first; mark Status `unread` if user
  insists on adding without capturing.

## What this skill does NOT do

- It does NOT replace `lit-status` for library-wide queries (counts, gaps,
  orphans). That skill reads `30_Literature/` directly.
- It does NOT download papers. That's `paper-capture`.
- It does NOT auto-sync -- Obsidian Sync / your sync provider does that. This
  skill just writes the file.
