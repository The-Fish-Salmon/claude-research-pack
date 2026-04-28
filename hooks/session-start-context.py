#!/usr/bin/env python3
"""SessionStart hook — emits JSON on stdout to inject recent handoff, latest
auto-review summary, and carried-over TODOs as additionalContext.

Path resolution: the SessionStart payload includes `transcript_path`. The memory
dir is the `memory/` sibling next to the transcript. Cross-platform — no
hardcoded user paths.
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

MAX_AGE_DAYS = 7
NOW = time.time()


def memory_dir_from_payload(payload: dict) -> Path | None:
    transcript = payload.get("transcript_path") or ""
    if not transcript:
        return None
    return Path(transcript).parent / "memory"


def fresh_section(file: Path, label: str) -> str | None:
    if not file.exists():
        return None
    age_days = int((NOW - file.stat().st_mtime) // 86400)
    if age_days > MAX_AGE_DAYS:
        return None
    try:
        body = file.read_text(encoding="utf-8")
    except Exception:
        return None
    return f"\n\n## {label} (age: {age_days}d)\n\n{body}"


def main():
    raw = sys.stdin.read()
    payload: dict = {}
    if raw.strip():
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = {}

    mem = memory_dir_from_payload(payload)
    if mem is None or not mem.exists():
        return 0

    parts: list[str] = []
    for file, label in [
        (mem / "handoff_latest.md", "Last handoff"),
        (mem / "review_latest.md", "Latest auto-review"),
        (mem / "todos_latest.md", "Carried-over TODOs"),
    ]:
        s = fresh_section(file, label)
        if s:
            parts.append(s)

    if not parts:
        return 0

    ctx = "".join(parts)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": ctx,
        }
    }))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"session-start-context: {e}", file=sys.stderr)
        sys.exit(0)
