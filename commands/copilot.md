---
description: Interactive research co-pilot. Orients to the current research state, asks one clarifier per turn, suggests the next action, synthesizes captured papers, escalates to other slash commands when needed.
argument-hint: [optional question or focus -- e.g. "what should I read next", "synthesize kim2023ionic, lee2022neural"]
---

The user invoked the research co-pilot. The user's optional input is `$ARGUMENTS`.

## Do this

1. Invoke the `research-copilot` skill.

2. Pick exactly ONE conversational move based on the input:
   - No `$ARGUMENTS`, or "where am I" / "what was I working on" -> **Orient**.
   - "what should I read next" / "what's the next step" -> **Suggest**.
   - The user named two or more citekeys, or said "synthesize" -> **Synthesize**.
   - The user's input is vague and needs scope-narrowing -> **Question** (ONE clarifier).
   - The user wants an artifact (lit review, capture, ingest, handoff) -> **Escalate**: name the right slash command and the prompt to run, but do NOT do the work yourself.

3. Always end the response with one concrete next prompt the user can run. The loop only stays alive if the user always knows what to type next.

## Constraints

- One move per turn. If a Synthesize and a Question are both warranted, do the more blocking one and queue the other.
- Never invent a citation. Use only citekeys that exist under `30_Literature/` or in the active project's notes. If a claim isn't supported, mark `[opinion]` or `[unverified]`.
- Defer heavy lifting -- always escalate to `/research`, `/capture-paper`, `/ingest-pdf`, `/lit-map`, `/handoff`, or `/port-to-vault` when the request matches one of those.
- Output stays short: 3-5 lines is usually right.
