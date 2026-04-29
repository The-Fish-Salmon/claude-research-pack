#!/usr/bin/env python3
"""Stop hook -- persist unfinished TodoWrite items to todos_latest.md so the next
session can resurface them.

Path resolution (cross-platform, no hardcoded user paths):
  - The Claude Code Stop event payload includes `transcript_path`, which points
    at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. The memory dir for
    that project is the sibling `memory/` next to the transcript. We derive it
    from the payload at run time so this hook works for any user on any host.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


def memory_dir_from_payload(payload: dict) -> Path | None:
    transcript = payload.get("transcript_path") or ""
    if not transcript:
        return None
    return Path(transcript).parent / "memory"


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    mem = memory_dir_from_payload(payload)
    if mem is None:
        return 0

    transcript = payload.get("transcript_path", "")
    session_id = payload.get("session_id", "unknown")
    tpath = Path(transcript)
    if not tpath.exists():
        return 0

    last_todos = None
    try:
        with tpath.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                content = (
                    rec.get("message", {}).get("content")
                    if isinstance(rec.get("message"), dict)
                    else None
                )
                if not isinstance(content, list):
                    continue
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "tool_use" and block.get("name") == "TodoWrite":
                        inp = block.get("input", {})
                        if isinstance(inp, dict) and isinstance(inp.get("todos"), list):
                            last_todos = inp["todos"]
    except Exception:
        pass

    out = mem / "todos_latest.md"

    if not last_todos:
        return 0

    unfinished = [
        f"- [{t.get('status')}] {t.get('content')}"
        for t in last_todos
        if isinstance(t, dict) and t.get("status") in ("in_progress", "pending")
    ]
    if not unfinished:
        try:
            out.unlink()
        except FileNotFoundError:
            pass
        return 0

    mem.mkdir(parents=True, exist_ok=True)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S %z") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    body = f"""---
name: todos-latest
type: handoff
created: {now}
session: {session_id}
---

# Carried-over TODOs

""" + "\n".join(unfinished) + """

_Persisted by ~/.claude/hooks/stop-persist-todos.py -- delete when resolved._
"""
    out.write_text(body, encoding="utf-8")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"stop-persist-todos: {e}", file=sys.stderr)
        sys.exit(0)
