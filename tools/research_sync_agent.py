#!/usr/bin/env python3
"""research_sync_agent.py -- scaffold and validate the cross-device research
continuity folder (`00-Claude-Context/`) inside an Obsidian vault.

Subcommands:
  init      Create the context folder and its seven Markdown files + manifest.
            Idempotent: existing files are preserved; only missing ones are written.
  validate  Verify the folder structure, frontmatter, and snapshot directory.
            Exits 0 if Ready, 1 with a clear message otherwise.

Pure stdlib. Runs on any Python 3.10+ on Windows / macOS / Linux. Bundled into
each desktop continuity-skill's `bin/` directory by prepare-desktop-pack.ps1, so
SKILL.md references like `${CLAUDE_PLUGIN_ROOT}/bin/research_sync_agent.py`
resolve at runtime inside the imported skill.

CLI examples:
  python research_sync_agent.py init     --vault "C:\\Users\\me\\Documents\\Vault"
  python research_sync_agent.py validate --vault "C:\\Users\\me\\Documents\\Vault"
  python research_sync_agent.py init     --vault "/Users/me/Vault" --device my-laptop

Exit codes:
  0  success / Ready
  1  validation failure (missing files, broken frontmatter, etc.)
  2  bad invocation (missing --vault, etc.)
"""
from __future__ import annotations

import argparse
import json
import re
import socket
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = "1.0.0"
CONTEXT_DIR = "00-Claude-Context"
SNAPSHOTS_DIR = "session-snapshots"

# (filename, doc_type, opening header, body skeleton)
DURABLE_FILES: list[tuple[str, str, str, str]] = [
    (
        "current-state.md",
        "current-state",
        "# Current State",
        "_Latest accepted snapshot summary. Update from the newest session-snapshot._\n\n"
        "## Goal\n\n_Pending._\n\n## Active focus\n\n_Pending._\n\n## Last action\n\n_Pending._\n",
    ),
    (
        "research-memory.md",
        "research-memory",
        "# Research Memory",
        "_Durable facts, definitions, and findings worth carrying across sessions._\n",
    ),
    (
        "preferences.md",
        "preferences",
        "# Preferences",
        "_User preferences and corrections learned during research sessions._\n",
    ),
    (
        "decision-log.md",
        "decision-log",
        "# Decision Log",
        "_Append-only record of decisions: what, why, by when._\n",
    ),
    (
        "open-questions.md",
        "open-questions",
        "# Open Questions",
        "_Unresolved research questions that need an answer before progress._\n",
    ),
    (
        "task-ledger.md",
        "task-ledger",
        "# Task Ledger",
        "_Active tasks (in-progress, pending, blocked, deferred). Move closed items to a Done section._\n\n"
        "## Active\n\n## Done\n",
    ),
    (
        "paper-map.md",
        "paper-map",
        "# Paper Map",
        "_Portable index of papers and their role in the active research._\n\n"
        "_Each entry: citation key, vault path, main claim, methods, status, threads._\n",
    ),
]

REQUIRED_FRONTMATTER_KEYS = ("schema_version", "doc_type", "source_device", "last_updated")


def device_slug(override: str | None) -> str:
    if override:
        return _sanitize_slug(override)
    return _sanitize_slug(socket.gethostname() or "unknown")


def _sanitize_slug(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9-]+", "-", s).strip("-")
    return s[:32] or "unknown"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def render_frontmatter(doc_type: str, device: str, when: str) -> str:
    return (
        "---\n"
        f"schema_version: {SCHEMA_VERSION}\n"
        f"doc_type: {doc_type}\n"
        f"source_device: {device}\n"
        f"last_updated: {when}\n"
        "---\n\n"
    )


def render_initial_manifest(device: str, when: str) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "created_by": "research_sync_agent.py init",
        "created_on_device": device,
        "created_at": when,
        "snapshot_count": 0,
        "last_updated": when,
        "last_updated_device": device,
    }


def parse_frontmatter(text: str) -> dict | None:
    """Tiny YAML-ish parser: only handles `key: value` lines between two `---`
    delimiters at file head. Returns None if no frontmatter block found.

    Tolerant of unicode values and trailing whitespace. We don't validate types
    beyond presence -- schema docs say what's required, we just check the keys.
    """
    if not text.startswith("---"):
        return None
    # Find the closing --- on its own line (allow optional trailing whitespace).
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    out: dict[str, str] = {}
    for i in range(1, len(lines)):
        line = lines[i]
        stripped = line.strip()
        if stripped == "---":
            return out
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in stripped:
            # Tolerate weird lines; just skip.
            continue
        key, _, value = stripped.partition(":")
        out[key.strip()] = value.strip()
    # No closing delimiter found.
    return None


def cmd_init(vault: Path, device: str) -> int:
    if not vault.exists():
        print(f"[err] vault path does not exist: {vault}", file=sys.stderr)
        return 2
    if not vault.is_dir():
        print(f"[err] vault path is not a directory: {vault}", file=sys.stderr)
        return 2

    ctx = vault / CONTEXT_DIR
    snaps = ctx / SNAPSHOTS_DIR

    created: list[str] = []
    skipped: list[str] = []

    ctx.mkdir(parents=True, exist_ok=True)
    snaps.mkdir(parents=True, exist_ok=True)

    when = utc_now_iso()

    for fname, doc_type, header, body in DURABLE_FILES:
        target = ctx / fname
        if target.exists():
            skipped.append(fname)
            continue
        content = render_frontmatter(doc_type, device, when) + header + "\n\n" + body
        target.write_text(content, encoding="utf-8")
        created.append(fname)

    manifest_path = ctx / "manifest.json"
    if manifest_path.exists():
        skipped.append("manifest.json")
    else:
        manifest_path.write_text(
            json.dumps(render_initial_manifest(device, when), indent=2) + "\n",
            encoding="utf-8",
        )
        created.append("manifest.json")

    # Visible README so users notice the folder in Obsidian.
    readme = ctx / "_README.md"
    if not readme.exists():
        readme.write_text(
            "# 00-Claude-Context\n\n"
            "This folder is the cross-device research-continuity layer used by the\n"
            "Claude Desktop research-continuity skills (`capture-research-state`,\n"
            "`resume-research-state`, `sync-check`, `paper-map`).\n\n"
            "Do not hand-edit `manifest.json` or the frontmatter of the seven\n"
            "Markdown files unless you know what you are doing -- `validate` will\n"
            "tell you what's wrong if you do.\n\n"
            "Run sync-check at the start of any session that needs cross-device\n"
            "context. The full schema lives in each skill's\n"
            "`references/context-schema.md`.\n",
            encoding="utf-8",
        )
        created.append("_README.md")
    else:
        skipped.append("_README.md")

    print(f"[init] vault:  {vault}")
    print(f"[init] device: {device}")
    print(f"[init] created: {len(created)}: {', '.join(created) if created else '-'}")
    print(f"[init] skipped: {len(skipped)}: {', '.join(skipped) if skipped else '-'}")
    print(f"[init] context dir: {ctx}")
    return 0


def cmd_validate(vault: Path) -> int:
    if not vault.exists() or not vault.is_dir():
        print(f"[validate] NOT READY -- vault path missing: {vault}")
        return 1

    ctx = vault / CONTEXT_DIR
    if not ctx.is_dir():
        print(f"[validate] NOT READY -- missing folder: {ctx}")
        print("           run: research_sync_agent.py init --vault <path>")
        return 1

    problems: list[str] = []

    # Check Markdown files.
    for fname, doc_type, _hdr, _body in DURABLE_FILES:
        target = ctx / fname
        if not target.exists():
            problems.append(f"missing file: {CONTEXT_DIR}/{fname}")
            continue
        try:
            text = target.read_text(encoding="utf-8")
        except Exception as exc:
            problems.append(f"cannot read {fname}: {exc}")
            continue
        fm = parse_frontmatter(text)
        if fm is None:
            problems.append(f"{fname}: missing or malformed frontmatter (no `---` block at file head)")
            continue
        for key in REQUIRED_FRONTMATTER_KEYS:
            if key not in fm:
                problems.append(f"{fname}: frontmatter missing key `{key}`")
        if fm.get("doc_type") and fm["doc_type"] != doc_type:
            problems.append(f"{fname}: frontmatter doc_type=`{fm['doc_type']}` (expected `{doc_type}`)")

    # Check manifest.
    manifest_path = ctx / "manifest.json"
    snapshot_count_recorded: int | None = None
    if not manifest_path.exists():
        problems.append("missing file: manifest.json")
    else:
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            if not isinstance(manifest, dict):
                problems.append("manifest.json: not a JSON object")
            else:
                if manifest.get("schema_version") != SCHEMA_VERSION:
                    problems.append(
                        f"manifest.json: schema_version=`{manifest.get('schema_version')}` "
                        f"(expected `{SCHEMA_VERSION}`)"
                    )
                snapshot_count_recorded = manifest.get("snapshot_count")
        except json.JSONDecodeError as exc:
            problems.append(f"manifest.json: invalid JSON: {exc}")

    # Check snapshots dir.
    snaps = ctx / SNAPSHOTS_DIR
    newest_snapshot = "none"
    on_disk_count: int | None = None
    if not snaps.is_dir():
        problems.append(f"missing folder: {CONTEXT_DIR}/{SNAPSHOTS_DIR}")
    else:
        snap_files = sorted(p.name for p in snaps.iterdir() if p.is_file() and p.suffix == ".md")
        on_disk_count = len(snap_files)
        if snap_files:
            newest_snapshot = snap_files[-1]
        if (
            snapshot_count_recorded is not None
            and on_disk_count is not None
            and on_disk_count < snapshot_count_recorded
        ):
            problems.append(
                f"snapshot count regressed: manifest=`{snapshot_count_recorded}`, "
                f"on disk=`{on_disk_count}` -- append-only invariant violated"
            )

    if problems:
        print("[validate] NOT READY")
        for p in problems:
            print(f"  - {p}")
        return 1

    snap_count = on_disk_count if on_disk_count is not None else 0
    print("[validate] READY")
    print(f"  vault:            {vault}")
    print(f"  context dir:      {ctx}")
    print(f"  durable files:    {len(DURABLE_FILES)} present, frontmatter ok")
    print(f"  snapshots:        {snap_count}")
    print(f"  newest snapshot:  {newest_snapshot}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="research_sync_agent.py",
        description="Scaffold / validate the cross-device research-continuity vault folder.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init", help="Create 00-Claude-Context/ in the given vault.")
    p_init.add_argument("--vault", required=True, type=Path, help="Vault root directory.")
    p_init.add_argument("--device", default=None, help="Device slug (default: derived from hostname).")

    p_val = sub.add_parser("validate", help="Verify the context folder is ready.")
    p_val.add_argument("--vault", required=True, type=Path, help="Vault root directory.")

    args = parser.parse_args(argv)

    if args.cmd == "init":
        return cmd_init(args.vault.resolve(), device_slug(args.device))
    if args.cmd == "validate":
        return cmd_validate(args.vault.resolve())

    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
