---
description: Run a deep-research workflow — multi-mode literature discovery, synthesis, fact-check, or systematic review. Lands findings in your Obsidian vault.
argument-hint: [--mode quick|full|lit-review|fact-check|socratic|systematic-review|review] {topic or question}
---

Invoke the `deep-research` skill on the topic in `$ARGUMENTS`.

## Do this

1. Parse `$ARGUMENTS`:
   - If `--mode {name}` is present, capture it. Otherwise leave mode unset.
   - The remaining text is the topic.
2. Read [skills/deep-research/SKILL.md](../skills/deep-research/SKILL.md) and [skills/deep-research/references/iron_rules.md](../skills/deep-research/references/iron_rules.md).
3. If mode is unset, infer it per [skills/deep-research/references/mode_selection.md](../skills/deep-research/references/mode_selection.md). Announce the chosen mode in your first sentence.
4. Read the corresponding `skills/deep-research/modes/{mode}.md` and follow its workflow.
5. Spawn sub-agents per the SKILL.md spawn pattern. Cap at 3 parallel.
6. At hand-off, write the deliverable to `{vault}/00_Inbox/research-{slug}-{YYYY-MM-DD}.md` via the `obsidian` MCP. Slug = lowercased topic, dashes for spaces, max 40 chars.
7. Ensure every paper that was read at the `full` level was passed to `paper-capture`.

## Output to user

A short summary in chat (≤200 words):
- Mode chosen.
- Number of papers found / read / captured.
- Path to the Inbox draft note.
- Any Devil's Advocate or Ethics flags raised.
- Suggested next action (promote draft, capture additional papers, refine question).

The full deliverable lives in the Inbox note — don't dump it back into chat.
