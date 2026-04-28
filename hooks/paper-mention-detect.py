#!/usr/bin/env python3
"""UserPromptSubmit hook: detect DOI / arXiv id mentions and suggest /capture-paper.

Reads the user's prompt from stdin (Claude Code passes a JSON payload on
UserPromptSubmit). If the prompt contains a DOI or arXiv id and the citekey
is not already present in the Obsidian vault's 30_Literature/ folder, emit
a non-blocking additionalContext hint.

Off-by-default: enable in settings.json by adding this script to the
UserPromptSubmit hooks array.

Env:
  OBSIDIAN_VAULT_PATH   absolute path to the vault (e.g. /mnt/d/.../MyVault)
  PAPER_MENTION_HOOK    set to "off" to disable at runtime
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

DOI_RE = re.compile(r"\b10\.\d{4,9}/[\w./()\-:;]+")
ARXIV_RE = re.compile(r"\b(?:arXiv:)?(\d{4}\.\d{4,5})(?:v\d+)?\b", re.IGNORECASE)

VAULT_LIT_DIR = "30_Literature"


def main() -> int:
    if os.environ.get("PAPER_MENTION_HOOK", "").lower() == "off":
        return 0

    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    prompt = payload.get("prompt") or payload.get("user_prompt") or ""
    if not prompt:
        return 0

    dois = sorted(set(m.group(0) for m in DOI_RE.finditer(prompt)))
    arxivs = sorted(set(m.group(1) for m in ARXIV_RE.finditer(prompt)))

    if not dois and not arxivs:
        return 0

    vault = os.environ.get("OBSIDIAN_VAULT_PATH")
    captured_dois: set[str] = set()
    captured_arxivs: set[str] = set()
    if vault:
        lit = Path(vault) / VAULT_LIT_DIR
        if lit.is_dir():
            for note in lit.glob("*.md"):
                try:
                    text = note.read_text(encoding="utf-8", errors="ignore")
                except OSError:
                    continue
                for m in DOI_RE.finditer(text):
                    captured_dois.add(m.group(0))
                for m in ARXIV_RE.finditer(text):
                    captured_arxivs.add(m.group(1))

    new_dois = [d for d in dois if d not in captured_dois]
    new_arxivs = [a for a in arxivs if a not in captured_arxivs]

    if not new_dois and not new_arxivs:
        return 0

    lines = ["[paper-mention-detect] Detected paper references not yet in your vault:"]
    for d in new_dois:
        lines.append(f"  - DOI: {d}  →  /capture-paper {d}")
    for a in new_arxivs:
        lines.append(f"  - arXiv: {a}  →  /capture-paper arXiv:{a}")
    lines.append("(disable: set PAPER_MENTION_HOOK=off in your env)")

    output = {
        "additionalContext": "\n".join(lines),
    }
    print(json.dumps(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
