#!/usr/bin/env python3
"""PreCompact hook — captures a structured handoff snapshot before Claude Code
auto-compacts (or on manual /compact). Runs silent; JSON payload on stdin.

Writes:
  <memory>/handoff_latest.md             (canonical, read by SessionStart)
  <memory>/handoffs/YYYY-MM-DD-HHMM.md   (rotated copy of previous)
  <vault>/00_Inbox/handoff-YYYY-MM-DD.md (mirror — only if OBSIDIAN_VAULT_PATH set)

Path resolution (cross-platform, no hardcoded user paths):
  - Memory dir derived from `transcript_path` in the payload.
  - Vault location read from $OBSIDIAN_VAULT_PATH; if unset, vault mirror is skipped.
  - Active project detected by scanning <vault>/10_Projects/*/overview.md for
    `status: active` (override with $ACTIVE_PROJECT). Generic — no project
    name baked in.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def parse_payload() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def memory_dir_from_payload(payload: dict) -> Path | None:
    transcript = payload.get("transcript_path") or ""
    if not transcript:
        return None
    return Path(transcript).parent / "memory"


def vault_path() -> Path | None:
    v = os.environ.get("OBSIDIAN_VAULT_PATH")
    return Path(v) if v else None


def git_branch(cwd: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(cwd), "branch", "--show-current"],
            capture_output=True, text=True, timeout=2,
        )
        return out.stdout.strip() if out.returncode == 0 else ""
    except Exception:
        return ""


def transcript_lookback(path: str) -> tuple[list[str], list[str]]:
    """Return (files_touched[-10:], unfinished_todos)."""
    files: list[str] = []
    todos_last: list[dict] = []
    if not path or not Path(path).exists():
        return [], []
    seen = set()
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                content = (
                    rec.get("message", {}).get("content") if isinstance(rec.get("message"), dict) else None
                )
                if not isinstance(content, list):
                    continue
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") != "tool_use":
                        continue
                    name = block.get("name")
                    inp = block.get("input", {}) if isinstance(block.get("input"), dict) else {}
                    if name in ("Edit", "Write", "Read"):
                        fp = inp.get("file_path")
                        if fp and fp not in seen:
                            seen.add(fp)
                            files.append(fp)
                    elif name == "TodoWrite":
                        tds = inp.get("todos")
                        if isinstance(tds, list):
                            todos_last = tds
    except Exception:
        pass

    files = files[-10:]
    todos = [
        f"- [{t.get('status')}] {t.get('content')}"
        for t in todos_last
        if isinstance(t, dict) and t.get("status") in ("in_progress", "pending")
    ]
    return files, todos


def find_active_project(vault: Path) -> tuple[str, Path | None] | tuple[str, None]:
    """Pick an active project from <vault>/10_Projects.

    Override with $ACTIVE_PROJECT (slug name). Otherwise scan overview.md
    frontmatter for `status: active`. Returns (slug, overview_path) or
    ("none", None).
    """
    projects_root = vault / "10_Projects"
    if not projects_root.exists():
        return "none", None

    forced = os.environ.get("ACTIVE_PROJECT", "").strip()
    if forced:
        ov = projects_root / forced / "overview.md"
        if ov.exists():
            return forced, ov

    for p in sorted(projects_root.iterdir()):
        if not p.is_dir():
            continue
        ov = p / "overview.md"
        if not ov.exists():
            continue
        try:
            for line in ov.read_text(encoding="utf-8").splitlines()[:30]:
                if line.lower().startswith("status:") and "active" in line.lower():
                    return p.name, ov
        except Exception:
            continue
    return "none", None


def active_project_summary(vault: Path | None) -> str:
    if vault is None:
        return "_(OBSIDIAN_VAULT_PATH not set)_"
    slug, ov = find_active_project(vault)
    if ov is None:
        return "_(no active project found in 10_Projects/)_"

    status = "unknown"
    try:
        for line in ov.read_text(encoding="utf-8").splitlines()[:30]:
            if line.lower().startswith("status:"):
                status = line.split(":", 1)[1].strip()
                break
    except Exception:
        pass

    runs_dir = ov.parent / "runs"
    latest_run = "none"
    if runs_dir.exists():
        runs = sorted(
            (p for p in runs_dir.iterdir() if p.is_file()),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        if runs:
            latest_run = runs[0].name
    return f"{slug} (status={status}, latest run: {latest_run})"


def rotate_previous(handoff: Path, hist_dir: Path):
    if not handoff.exists():
        return
    hist_dir.mkdir(parents=True, exist_ok=True)
    stamp = None
    try:
        for line in handoff.read_text(encoding="utf-8").splitlines()[:10]:
            if line.startswith("created:"):
                stamp = line.split(":", 1)[1].strip()
                break
    except Exception:
        pass
    if stamp:
        slug = stamp[:16].replace(" ", "-").replace(":", "").replace("+", "")
    else:
        slug = datetime.fromtimestamp(handoff.stat().st_mtime).strftime("%Y-%m-%d-%H%M")
    try:
        shutil.copy2(handoff, hist_dir / f"{slug}.md")
    except Exception:
        pass


def main():
    payload = parse_payload()
    session_id = payload.get("session_id", "unknown")
    transcript = payload.get("transcript_path", "")
    trigger = payload.get("trigger", "manual")
    focus = payload.get("custom_instructions", "")

    mem = memory_dir_from_payload(payload)
    if mem is None:
        # Without a transcript path we can't safely place files. Bail silently.
        return

    handoff = mem / "handoff_latest.md"
    hist_dir = mem / "handoffs"

    mem.mkdir(parents=True, exist_ok=True)
    hist_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.now()
    stamp_full = now.strftime("%Y-%m-%d %H:%M:%S %z") or now.strftime("%Y-%m-%d %H:%M:%S")
    stamp_short = now.strftime("%Y-%m-%d-%H%M")
    date_short = now.strftime("%Y-%m-%d")

    cwd = Path.cwd()
    branch = git_branch(cwd)
    files, todos = transcript_lookback(transcript)
    vault = vault_path()
    proj = active_project_summary(vault)

    files_block = "\n".join(f"- `{p}`" for p in files) if files else "_(transcript unavailable)_"
    todos_block = "\n".join(todos) if todos else "_(none captured)_"

    focus_line = f" — focus: {focus}" if focus else ""
    branch_line = f"  (branch: `{branch}`)" if branch else ""

    rotate_previous(handoff, hist_dir)

    body = f"""---
name: handoff-{stamp_short}
type: handoff
created: {stamp_full}
session: {session_id}
trigger: {trigger}
---

# Handoff — {stamp_full}

**Trigger:** `{trigger}`{focus_line}
**CWD:** `{cwd}`{branch_line}
**Active project:** {proj}

## Last files touched
{files_block}

## Open TODOs
{todos_block}

## Session ID
`{session_id}` — transcript: `{transcript}`

> Generated by ~/.claude/hooks/precompact-handoff.py
"""

    handoff.write_text(body, encoding="utf-8")

    # Mirror to vault inbox (non-fatal; only if vault is configured).
    if vault is not None:
        try:
            inbox = vault / "00_Inbox"
            inbox.mkdir(parents=True, exist_ok=True)
            (inbox / f"handoff-{date_short}.md").write_text(body, encoding="utf-8")
        except Exception:
            pass


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Hooks must never break the session — log to stderr and exit 0
        print(f"precompact-handoff: {e}", file=sys.stderr)
    sys.exit(0)
