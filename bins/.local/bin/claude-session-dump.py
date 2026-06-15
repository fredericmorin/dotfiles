#!/usr/bin/env python3
"""Convert a Claude Code .jsonl session into a Markdown transcript.

Lightweight import path: produces a single Markdown document you can paste
as the opening message of a fresh coding-agent session (T3 Code, Codex,
Cursor, OpenCode, ...) to carry context across. None of these can adopt
another tool's native session, so a pasted transcript is the common
denominator. Tool calls are summarized as one-liners; tool output is
omitted to keep context small.

Usage:
    cc_transcript.py <session.jsonl> [-o out.md] [--max-text N]
    cc_transcript.py --list [PROJECT_SUBSTR]   # list recent sessions

Find sessions under ~/.claude/projects/<encoded-cwd>/<uuid>.jsonl
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"


def _flatten_content(content: object) -> list[dict]:
    """Claude message.content is always a list of typed parts here."""
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    if isinstance(content, list):
        return [p for p in content if isinstance(p, dict)]
    return []


def _summarize_tool_use(part: dict) -> str:
    name = part.get("name", "tool")
    inp = part.get("input", {}) or {}
    # Pick the most identifying argument for a compact one-liner.
    hint = ""
    for key in ("file_path", "path", "pattern", "command", "skill",
                "url", "query", "filePath", "description"):
        if key in inp and isinstance(inp[key], str):
            val = inp[key].strip().replace("\n", " ")
            hint = val[:80]
            break
    return f"[tool: {name}{' ' + hint if hint else ''}]"


def _strip_noise(text: str) -> str | None:
    """Drop IDE/system noise that is not real conversation."""
    t = text.strip()
    if not t:
        return None
    for tag in ("<ide_opened_file>", "<ide_selection>",
                "<system-reminder>", "<command-name>",
                "<local-command-stdout>"):
        if t.startswith(tag):
            return None
    return text


def convert(path: Path, max_text: int = 4000) -> str:
    out: list[str] = []
    title = path.stem
    out.append(f"# Claude Code session transcript: {title}\n")
    out.append(
        "_This is prior context from an earlier session. Continue the work "
        "from where it left off; do not redo steps already completed below. "
        "Tool calls are summarized and tool output is omitted, so re-read "
        "files before acting on them._\n"
    )

    with path.open() as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            rtype = obj.get("type")
            if rtype not in ("user", "assistant"):
                continue  # skip attachment/snapshot/mode/etc noise

            # Synthetic/injected context records (skill text, hook output,
            # tool-result echoes) are flagged isMeta or carry a
            # sourceToolUseID; they are not real conversation turns.
            if obj.get("isMeta") or obj.get("sourceToolUseID"):
                continue

            msg = obj.get("message", {})
            role = msg.get("role", rtype)
            parts = _flatten_content(msg.get("content"))

            chunks: list[str] = []
            for p in parts:
                ptype = p.get("type")
                if ptype == "text":
                    cleaned = _strip_noise(p.get("text", ""))
                    if cleaned:
                        if len(cleaned) > max_text:
                            cleaned = (cleaned[:max_text].rstrip()
                                       + "\n\n… [truncated]")
                        chunks.append(cleaned)
                elif ptype == "tool_use":
                    chunks.append(_summarize_tool_use(p))
                elif ptype == "tool_result":
                    # User-role records carry tool results; omit output,
                    # just note it happened so the thread stays coherent.
                    chunks.append("[tool result]")
                elif ptype == "thinking":
                    continue  # skip internal reasoning

            body = "\n\n".join(c for c in chunks if c).strip()
            if not body:
                continue

            label = "User" if role == "user" else "Assistant"
            out.append(f"## {label}\n\n{body}\n")

    return "\n".join(out)


def list_sessions(substr: str | None) -> None:
    if not CLAUDE_PROJECTS.is_dir():
        print(f"No Claude projects dir at {CLAUDE_PROJECTS}", file=sys.stderr)
        return
    rows: list[tuple[float, Path]] = []
    for proj in CLAUDE_PROJECTS.iterdir():
        if not proj.is_dir():
            continue
        if substr and substr not in proj.name:
            continue
        for f in proj.glob("*.jsonl"):
            rows.append((f.stat().st_mtime, f))
    rows.sort(reverse=True)
    for mtime, f in rows[:30]:
        kb = f.stat().st_size // 1024
        print(f"{kb:>7}K  {f}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("session", nargs="?", help="path to <uuid>.jsonl")
    ap.add_argument("-o", "--out", help="write Markdown to this file")
    ap.add_argument("--max-text", type=int, default=4000,
                    help="truncate each text block to N chars (default 4000)")
    ap.add_argument("--list", nargs="?", const="", metavar="SUBSTR",
                    help="list recent sessions (optionally filter by substr)")
    args = ap.parse_args()

    if args.list is not None:
        list_sessions(args.list or None)
        return 0

    if not args.session:
        ap.error("provide a session .jsonl path, or use --list")

    path = Path(args.session).expanduser()
    if not path.is_file():
        print(f"Not a file: {path}", file=sys.stderr)
        return 1

    md = convert(path, max_text=args.max_text)
    if args.out:
        Path(args.out).write_text(md)
        print(f"Wrote {len(md)} chars to {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
